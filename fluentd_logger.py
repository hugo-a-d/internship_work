import fluent.handler
import fluent.sender
import logging

def fluentd_logger(tag, host:str, port:int, log_level=logging.DEBUG):
    ''' Creates a logger using fleuntd. Requires the fluentd tag, host, portnumber.
    LogLevel is currently set to debug get all messages. It creates a custom '''
    fluent_logger = fluent.sender.FluentSender(tag, host=host, port=port)

    class FluentdHandler(logging.Handler):
        def emit(self, record):
            try:
                msg = self.format(record)
                fluent_logger.emit(tag, {'message': msg})
            except Exception:
                self.handleError(record)

    logging.basicConfig(level=log_level)
    root_logger = logging.getLogger()
    root_logger.addHandler(FluentdHandler)
    fluent_logger = root_logger

    return fluent_logger
