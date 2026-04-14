#######################################################################

__maintainer__   = 'Anders H. Vestergaard'
__author__       = 'Anders H. Vestergaard'
__contributors__ = []
__email__        = 'anders.vestergaard@hjoerring.dk'
__version__      = '1.0.0'
__status__       = 'Production'

#######################################################################

import logging
import os
from pathlib import Path

from dotenv import load_dotenv

from utils.get_engine import get_engine
from utils.setup_logging import setup_logging

load_dotenv()

logger: logging.Logger = logging.getLogger(__name__)
SQL_DIR: Path = Path(__file__).parent / 'sql'

#######################################################################

def deploy_procedures() -> None:
    '''
    Description:
        Deploys all stored procedures in the sql/ directory to the
        database by executing each .sql file via a raw pyodbc connection.

    Flow:
        1. Collect all .sql files from sql/meta/ and sql/dw/ in
           dependency order (meta first, then dw).
        2. Establish a raw pyodbc connection with autocommit enabled.
        3. For each file, read the definition and execute via cursor.
        4. Log success or failure per file.

    Args:
        None.

    Returns:
        None.

    Raises:
        EnvironmentError: If required environment variables are missing.
        FileNotFoundError: If the sql/ directory does not exist.
        Exception: If any stored procedure fails to deploy.
    '''

    if not SQL_DIR.exists():
        raise FileNotFoundError(f'SQL directory not found: {SQL_DIR}')

    # meta must be deployed before dw
    sql_files: list[Path] = (
        sorted((SQL_DIR / 'meta').glob('*.sql')) +
        sorted((SQL_DIR / 'dw').glob('*.sql')))

    if not sql_files:
        logger.warning('No .sql files found in %s', SQL_DIR)
        return

    logger.info('Deploying %d stored procedures', len(sql_files))
    engine = get_engine()
    raw = engine.raw_connection()
    try:
        raw.connection.autocommit = True
        cursor = raw.cursor()
        success: int = 0
        failed: int = 0
        for path in sql_files:
            sql: str = path.read_text(encoding='utf-8')
            # Strip GO statements — pyodbc executes one batch at a time
            sql = sql.replace('\nGO\n', '').replace('\nGO', '').strip()
            try:
                cursor.execute(sql)
                logger.info('  OK  %s', path.relative_to(SQL_DIR))
                success += 1
            except Exception as e:
                logger.error('  FAIL %s — %s', path.relative_to(SQL_DIR), e)
                failed += 1
        cursor.close()
        logger.info('Done — %d succeeded, %d failed', success, failed)
    finally:
        raw.close()

if __name__ == '__main__':
    setup_logging()
    deploy_procedures()