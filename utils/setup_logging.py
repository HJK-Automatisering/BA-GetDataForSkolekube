#######################################################################

import logging
import sys

#######################################################################

def setup_logging() -> None:
    '''
    Description:
        Initialises logging configuration for the application.

    Flow:
        1. Configures root logger at INFO level.
        2. Logs to stdout with timestamps, level and module name.

    Args:
        None.

    Returns:
        None.

    Raises:
        None.
    '''

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(name)s - %(message)s',
        datefmt='%d-%m-%Y %H:%M:%S',
        handlers=[logging.StreamHandler(sys.stdout)])