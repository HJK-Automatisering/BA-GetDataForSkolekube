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
import time

import schedule
from dotenv import load_dotenv
from sqlalchemy.engine import Engine

from utils.get_engine import get_engine
from utils.load_stg import load_all_stg_tables
from utils.run_etl import run_etl
from utils.setup_logging import setup_logging
from utils.should_run import should_run

load_dotenv()
logger: logging.Logger = logging.getLogger(__name__)
RUN_AT: str = os.getenv('RUN_AT', '04:00')

#######################################################################

def main() -> None:
    '''
    Description:
        Runs the daily staging load and ETL execution.

    Flow:
        1. Establish database engine.
        2. Check whether today is a school day — exit early if not.
        3. Load all four source files into staging tables.
        4. Log summary of rows inserted per table.
        5. Execute master ETL stored procedure.

    Args:
        None.

    Returns:
        None.

    Raises:
        EnvironmentError: If required environment variables are missing.
        FileNotFoundError: If any source file does not exist.
        SQLAlchemyError: If any database operation fails.
    '''

    logger.info('Starting staging load')
    engine: Engine = get_engine()
    if not should_run(engine):
        logger.info('Not a school day — exiting')
        return
    results: dict[str, int] = load_all_stg_tables(engine)
    logger.info('Staging load complete')
    for table_name, rows in results.items():
        logger.info('  %-30s %8d rows', table_name, rows)
    run_etl(engine)

if __name__ == '__main__':
    setup_logging()
    run_now: bool = os.getenv('RUN_NOW', 'false').lower() == 'true'
    if run_now:
        logger.info('RUN_NOW=true — executing immediately')
        main()
    else:
        schedule.every().day.at(RUN_AT).do(main)
        logger.info('Scheduler started — waiting for %s', RUN_AT)
        while True:
            schedule.run_pending()
            time.sleep(60)