"""
Simple example of a message class including some strict validation
on creation (producing) and digesting (consuming)
"""

from Message import Message, MessageException

class control_message(Message):
    def __init__(self, message = None):
        Message.__init___(self, message)
        if message is None:
            # Defaults
            Message._set(self, "control", None)

    def validate(self):
        # Required
        if self.message["control"] is None:
            return False
        return Message._validate(self)

    """
    Producer methods
    """
    def stop(self):
        return Message._set(self, "control", "stop")

    """
    Consumer methods
    """
    def is_stop(self):
        if "control" in self.message:
            if self.message["control"] == "stop":
                return True
        return False
