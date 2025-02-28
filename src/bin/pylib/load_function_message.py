"""
Simple example of a message class including some strict validation
on creation (producing) and digesting (consuming)
"""

import platform
import getpass
import json
from datetime import datetime

class load_function_message:
    def __init__(self, message = None):
        if message is None:
            self.digesting = False
            # Defaults
            msgid = platform.node() + ":" + getpass.getuser() + ":" + str(datetime.now().timestamp())
            self.message = {
                "msgid": msgid,
                "cluster_id": None,
                "load_function_id": None,
                "override_freq": False,
                "analyze": False,
                "prime": False
            }
            self.set_override_freq()
            self.set_prime()
        else:
            self.digesting = True
            self.validated = False
            self.message = json.loads(message)
            if self.validate():
                self.validated = True

    """
    General purpose internal methods
    """
    def _int_test(self, var):
        if isinstance(var, int):
            return True
        return False

    def _bool_test(self, var):
        if isinstance(var, boolean):
            return True
        return False

    def _set(self, var, val):
        if self.digesting:
            return False
        self.message[var] = val
        return True

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
        if self.digesting:
            msgparts = self.message["msgid"].split(":")
            self.caller = {
                "host": msgparts[0],
                "user": msgparts[1],
                "ts":   msgparts[2]
            }
        return True

    """
    Producer methods
    """
    def set_load_function_id(self, id):
        if self._int_test(id):
            return self._set("load_function_id", id)
        return False

    def set_cluster_id(self, id):
        if self._int_test(id):
            return self._set("cluster_id", id)
        return False

    def set_override_freq(self, b = False):
        return self._set("override_freq", b)

    def set_analyze(self, b = False):
        return self._set("analyze", b)

    def set_prime(self, b = False):
        return self._set("prime", b)

    def as_str(self):
        if self.validate():
            return json.dumps(self.message)

    """
    Consumer methods
    """
    def get(self, element):
        if not self.validated:
            raise load_function_message_Exception("not a valid message")
        if element not in self.message:
            raise load_function_message_Exception("element "+element+" not in message")
        return self.message[element]


class load_function_message_Exception(Exception):
    """Custom exception class"""
    pass




