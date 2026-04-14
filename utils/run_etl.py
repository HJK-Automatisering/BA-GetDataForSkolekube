#######################################################################

import logging

from sqlalchemy.engine import Engine
from sqlalchemy.exc import SQLAlchemyError

logger: logging.Logger = logging.getLogger(__name__)

#######################################################################

def run_etl(engine: Engine) -> None:
    '''
    Description:
        Executes the master ETL stored procedure in the data warehouse.

    Flow:
        1. Acquire a raw pyodbc connection with autocommit enabled —
           usp_master manages its own transactions internally.
        2. Execute dw.usp_master via cursor.
        3. Log success or raise on failure.

    Args:
        engine (Engine): SQLAlchemy engine connected to Skolekube.

    Returns:
        None.

    Raises:
        SQLAlchemyError: If the stored procedure fails or cannot be executed.
    '''

    logger.info('Executing dw.usp_master')
    raw = engine.raw_connection()
    try:
        raw.connection.autocommit = True
        cursor = raw.cursor()
        cursor.execute('EXEC dw.usp_master')
        cursor.close()
        logger.info('dw.usp_master completed successfully')
    except Exception as e:
        raise SQLAlchemyError(f'ETL procedure failed: {e}') from e
    finally:
        raw.close()