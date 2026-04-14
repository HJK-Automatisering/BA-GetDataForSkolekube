#######################################################################

import logging
import os
import warnings
from urllib.parse import quote_plus

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.exc import SAWarning, SQLAlchemyError

load_dotenv()
warnings.filterwarnings('ignore', category=SAWarning, message='.*Unrecognized server version.*')

logger: logging.Logger = logging.getLogger(__name__)
REQUIRED_VARS: list[str] = ['DB_DRIVER', 'DB_SERVER', 'DB_NAME', 'DB_USERNAME', 'DB_PASSWORD']

#######################################################################

def get_engine() -> Engine:
    '''
    Description:
        Creates and returns a SQLAlchemy engine for SQL Server.

    Flow:
        1. Validate that all required environment variables are present.
        2. Build an ODBC connection string from environment variables.
        3. Create and return a SQLAlchemy engine.

    Args:
        None.

    Returns:
        Engine: A SQLAlchemy engine connected to the configured SQL Server
            database.

    Raises:
        EnvironmentError: If any required environment variable is missing.
        SQLAlchemyError: If the engine cannot be created or connection fails.
    '''

    missing: list[str] = [var for var in REQUIRED_VARS if not os.getenv(var)]
    if missing:
        raise EnvironmentError(f'Missing required environment variables: {", ".join(missing)}')
    driver: str = os.getenv('DB_DRIVER')
    server: str = os.getenv('DB_SERVER')
    database: str = os.getenv('DB_NAME')
    username: str = os.getenv('DB_USERNAME')
    password: str = os.getenv('DB_PASSWORD')
    odbc_string: str = (
        f'DRIVER={{{driver}}};'
        f'SERVER={server};'
        f'DATABASE={database};'
        f'UID={username};'
        f'PWD={password};'
        'Trusted_Connection=no;'
        'TrustServerCertificate=yes;')
    connection_url: str = f'mssql+pyodbc:///?odbc_connect={quote_plus(odbc_string)}'
    try:
        engine: Engine = create_engine(connection_url, fast_executemany=True)
        logger.info('Database engine created for %s / %s', server, database)
        return engine
    except SQLAlchemyError as e:
        raise SQLAlchemyError(f'Failed to create database engine: {e}') from e