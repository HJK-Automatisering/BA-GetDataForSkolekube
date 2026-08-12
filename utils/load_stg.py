#######################################################################

import logging
import os
from datetime import datetime
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import text
from sqlalchemy.engine import Engine

from constants import MULTITYPE_FILES, STG_DROP_COLS, STG_FILES, STG_RENAME

load_dotenv()

logger: logging.Logger = logging.getLogger(__name__)

#######################################################################

def _get_file_path(filename: str) -> Path:
    '''
    Description:
        Resolves the full path for a source file using FILE_PATH from
        environment.

    Flow:
        1. Read FILE_PATH from environment.
        2. Construct and validate the full file path.

    Args:
        filename (str): Source filename, e.g. 'elev_basis.csv'.

    Returns:
        Path: Full path to the file.

    Raises:
        EnvironmentError: If FILE_PATH is not set.
        FileNotFoundError: If the file does not exist at the resolved path.
    '''

    file_path: str = os.getenv('FILE_PATH', '')
    if not file_path:
        raise EnvironmentError('Missing required environment variable: FILE_PATH')
    full_path: Path = Path(file_path) / filename
    if not full_path.exists():
        raise FileNotFoundError(f'Source file not found: {full_path}')
    return full_path

def _parse_multitype_file(path: Path) -> pd.DataFrame:
    '''
    Description:
        Parses a multi-section Tabulex file into a single wide DataFrame.
        Returns an empty DataFrame if the file contains no valid sections.

    Flow:
        1. Read all lines and decode as windows-1252.
        2. Skip line 1 (metadata) and line type 3 (sum lines).
        3. For each section: read header line (linjetype 2), collect data
           lines until next header or end of file.
        4. Strip empty trailing columns from header.
        5. Extend header with _extra_N names if data has more columns.
        6. Parse each section into a DataFrame with row_type prepended.
        7. Concatenate all sections into one wide DataFrame.
        8. Return empty DataFrame if no valid sections found.

    Args:
        path (Path): Full path to the source file.

    Returns:
        pd.DataFrame: Combined DataFrame with all rows and a row_type column,
            or an empty DataFrame if the file contains no valid sections.

    Raises:
        None.
    '''

    lines: list[str] = path.read_text(encoding='windows-1252').splitlines()
    sections: list[tuple[list[str], list[list[str]]]] = []
    current_header: list[str] | None = None
    current_rows: list[list[str]] = []
    for line in lines[1:]:
        if not line.strip():
            continue
        first: str = line.split(';')[0]
        if first == '2':
            if current_header is not None and current_rows:
                sections.append((current_header, current_rows))
            current_header = line.split(';')[1:]
            current_rows = []
        elif first == '3':
            continue
        else:
            current_rows.append(line.split(';'))
    if current_header is not None and current_rows:
        sections.append((current_header, current_rows))
    if not sections:
        logger.warning('No valid sections found in file: %s — returning empty DataFrame', path)
        return pd.DataFrame()
    dfs: list[pd.DataFrame] = []
    for header, rows in sections:
        # Strip empty trailing header columns
        cleaned_header: list[str] = []
        for col in reversed(header):
            if col.strip() or cleaned_header:
                cleaned_header.insert(0, col)
        # Find max meaningful data width (strip trailing empty values)
        max_data_width: int = 0
        for row in rows:
            for j in range(len(row) - 1, -1, -1):
                if row[j].strip():
                    max_data_width = max(max_data_width, j + 1)
                    break
        # Extend header with _extra_N if data has more columns than header
        # +1 accounts for row_type which is prepended to header
        while len(cleaned_header) + 1 < max_data_width:
            cleaned_header.append(f'_extra_{len(cleaned_header)}')
        col_count: int = len(cleaned_header) + 1
        padded_rows: list[list[str | None]] = [
            row[:col_count] + [None] * max(0, col_count - len(row))
            for row in rows]
        df: pd.DataFrame = pd.DataFrame(padded_rows, columns=['row_type'] + cleaned_header)
        df = df.replace('', None)
        dfs.append(df)
    return pd.concat(dfs, ignore_index=True)

def _load_file_to_stg(filename: str, table_name: str, engine: Engine, load_date: datetime) -> int:
    '''
    Description:
        Reads a source file and bulk-inserts into a staging table.

    Flow:
        1. Resolve file path from FILE_PATH environment variable.
        2. Parse file — multi-section or plain CSV depending on file type.
        3. Return 0 immediately if parsed DataFrame is empty.
        4. Rename columns to stg target names and drop unmapped columns.
        5. Drop duplicate column names — keeps first occurrence.
        6. Drop columns not present in the stg table definition.
        7. Apply table-specific row filters.
        8. Add stg_load_date column.
        9. Truncate existing rows and bulk-insert via SQLAlchemy.

    Args:
        filename (str): Source filename, e.g. 'elev_basis.csv'.
        table_name (str): Target staging table, e.g. 'stg.student_basis'.
        engine (Engine): SQLAlchemy engine.
        load_date (datetime): Timestamp to set on stg_load_date for all rows.

    Returns:
        int: Number of rows inserted.

    Raises:
        EnvironmentError: If FILE_PATH is not set.
        FileNotFoundError: If the source file does not exist.
        SQLAlchemyError: If delete or insert fails.
    '''

    schema, table = table_name.split('.')
    rename_map: dict[str, str] = STG_RENAME[table_name]
    drop_cols: set[str] = STG_DROP_COLS.get(table_name, set())
    path: Path = _get_file_path(filename)
    logger.info('Loading %s -> %s', filename, table_name)
    if filename in MULTITYPE_FILES:
        df: pd.DataFrame = _parse_multitype_file(path)
    else:
        df = pd.read_csv(
            path,
            sep=';',
            encoding='windows-1252',
            dtype=str,
            keep_default_na=False,
            na_values=[''])
    if df.empty:
        logger.warning('No data in %s — skipping insert', filename)
        return 0
    df = df.rename(columns=rename_map)
    df = df.loc[:, ~df.columns.duplicated(keep='first')]
    df = df[[col for col in dict.fromkeys(rename_map.values()) if col in df.columns]]
    df = df.drop(columns=[col for col in drop_cols if col in df.columns])
    if table_name == 'stg.student_basis' and 'school_type_code' in df.columns:
        df = df[df['school_type_code'].notna()]
    df['stg_load_date'] = load_date
    with engine.begin() as conn:
        conn.execute(text(f'DELETE FROM [{schema}].[{table}]'))
        df.to_sql(
            name=table,
            schema=schema,
            con=conn,
            if_exists='append',
            index=False,
            chunksize=500)
    logger.info('Inserted %d rows into %s', len(df), table_name)
    return len(df)

def load_all_stg_tables(engine: Engine) -> dict[str, int]:
    '''
    Description:
        Reads all four source files and loads them into staging tables.

    Flow:
        1. Set a shared load_date timestamp for all tables in this run.
        2. For each source file, read, parse, truncate and insert.
        3. Return a summary of rows inserted per table.

    Args:
        engine (Engine): SQLAlchemy engine.

    Returns:
        dict[str, int]: Mapping of table name to number of rows inserted,
            e.g. {'stg.student_basis': 7286, ...}.

    Raises:
        EnvironmentError: If FILE_PATH is not set.
        FileNotFoundError: If any source file does not exist.
        SQLAlchemyError: If any database operation fails.
    '''

    load_date: datetime = datetime.now()
    results: dict[str, int] = {}
    for filename, table_name in STG_FILES.items():
        results[table_name] = _load_file_to_stg(filename, table_name, engine, load_date)
    return results