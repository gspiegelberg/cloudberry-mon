"""
Simple example of a message class including some strict validation
on creation (producing) and digesting (consuming)
"""

import platform
import getpass
import json
from datetime import datetime

class control_message:
    def __init__(self, message = None):
        if message is None:
            self.digesting = False
            msgid = platform.node() + ":" + getpass.getuser() + ":" + str(datetime.now().timestamp())
            # Defaults
            self.message = {
                "msgid": msgid,
                "control": None
            }
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

    def _set(self, var, val):
        if self.digesting:
            return False
        self.message[var] = val
        return True

    def validate(self):
        # Required
        if self.message["msgid"] is None:
            return False
        if self.message["control"] is None:
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
    def stop(self):
        return self._set("control", "stop")

    def as_str(self):
        if self.validate():
            return json.dumps(self.message)

    """
    Consumer methods
    """
    def is_stop(self):
        if self.validated:
            if "control" in self.message:
                if self.message["control"] == "stop":
                    return True
        return False

    def req_user(self):
        return self.caller["user"]

    def req_host(self):
        return self.caller["host"]

    def req_ts(self):
        return self.caller["ts"]

    def get(self, element):
        if not self.validated:
            raise control_message_Exception("not a valid message")
        if element not in self.message:
            raise control_message_Exception("element "+element+" not in message")
        return self.message[element]


class control_message_Exception(Exception):
    """Custom exception class"""
    pass




