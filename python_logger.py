import logging

def setup_logger(log_file='streamlit.log', log_level=logging.DEBUG):
    ''' Creates a logger object with a log_file, log_level, a formatter for the logging messages
    and a file handler for the logging file.

    Log messages are formatted with the time, level,loggername, linenumber and the message added
    '''
    logger = logging.getLogger(__name__)
    logger.setLevel(log_level)

    formatter = logging.Formatter("%(asctime)s - %(levelname)s:%(name)s:%(lineno)d %(message)s", datefmt="%H:%M:%S")
    file_handler = logging.FileHandler(log_file)
    file_handler.setFormatter(formatter)

    logger.addHandler(file_handler)

    return logger
