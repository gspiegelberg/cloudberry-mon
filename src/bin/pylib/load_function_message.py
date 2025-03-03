"""
Simple example of a message class including some strict validation
on creation (producing) and digesting (consuming)
"""

from Message import Message, MessageException

class load_function_message(Message):
    def __init__(self, message = None):
        Message.__init___(self, message)
        if message is None:
            # Defaults
            self.set_override_freq()
            self.set_analyze()
            self.set_prime()

    """
    General purpose internal methods
    """
    def validate(self):
        # Required
        if self.message["cluster_id"] is None:
            return False
        if self.message["load_function_id"] is None:
            return False
        if self.message["override_freq"] is None:
            return False
        if self.message["analyze"] is None:
            return False
        if self.message["prime"] is None:
            return False
        return Message._validate(self)

    """
    Producer methods
    """
    def set_load_function_id(self, id):
        if Message._int_test(id):
            return Message._set(self, "load_function_id", id)
        return False

    def set_cluster_id(self, id):
        if Message._int_test(id):
            return Message._set(self, "cluster_id", id)
        return False

    def set_override_freq(self, b = False):
        if Message._bool_test(b):
            return Message._set(self, "override_freq", b)
        return False

    def set_analyze(self, b = False):
        if Message. _bool_test(b):
            return Message._set(self, "analyze", b)
        return False

    def set_prime(self, b = False):
        if Message. _bool_test(b):
            return Message._set(self, "prime", b)
        return False

    """
    Consumer methods
    """
    def get_load_function_id(self):
        return self.message["load_function_id"]

    def get_cluster_id(self):
        return self.message["cluster_id"]

    def get_override_freq(self):
        return self.message["override_freq"]

    def get_analyze(self):
        return self.message["analyze"]

    def get_prime(self):
        return self.message["prime"]
