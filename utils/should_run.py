#######################################################################

import logging
from datetime import date

from sqlalchemy import text
from sqlalchemy.engine import Engine

logger: logging.Logger = logging.getLogger(__name__)

#######################################################################

def should_run(engine: Engine) -> bool:
    '''
    Description:
        Determines whether the ETL pipeline should execute today.

    Flow:
        1. Query dim_date for today's date.
        2. Return True only if the day is not a weekend and not a vacation day.

    Args:
        engine (Engine): SQLAlchemy engine connected to Skolekube.

    Returns:
        bool: True if today is a school day, False otherwise.

    Raises:
        SQLAlchemyError: If the query cannot be executed.
    '''

    today: date = date.today()
    with engine.connect() as conn:
        result: int = conn.execute(text('''
            SELECT COUNT(*)
            FROM dw.dim_date
            WHERE full_date = :today
              AND is_weekend = 0
              AND is_vacation_day = 0
        '''), {'today': today}).scalar()
    is_school_day: bool = result == 1
    logger.info('Today (%s) is %sa school day', today, '' if is_school_day else 'not ')
    return is_school_day