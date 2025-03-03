"""
Superclass for all message types
"""

import platform
import getpass
import json
from datetime import datetime


class Message(object):
    def __init___(self, message = None):
        if message is None:
            # Creating a message to be sent
            self.digesting = False
            # Defaults
            self.message = {
                "msgid" : platform.node() + ":" + getpass.getuser() + ":" + str(datetime.now().timestamp())
            }
        else:
            # Digesting a received message
            self.digesting = True
            self.message = json.loads(message)
            if self._validate():
                self._validated = True

    """
    General purpose internal methods
    """
    def _int_test(var):
        if isinstance(var, int):
            return True
        return False

    def _bool_test(var):
        if isinstance(var, bool):
            return True
        return False

    def _set(self, var, val):
        if self.digesting:
            raise MessageException("cannot change message")
        self.message[var] = val
        return True

    def _validate(self):
        if self.message["msgid"] is None:
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
    def as_str(self):
        if self.validate():
            return json.dumps(self.message)

    """
    Consumer methods
    """
    def get(self, element):
        if not self.validated:
            raise MessageException("not a valid message")
        if element not in self.message:
            raise MessageException("element "+element+" not in message")
        return self.message[element]

    def req_user(self):
        return self.caller["user"]

    def req_host(self):
        return self.caller["host"]

    def req_ts(self):
        return self.caller["ts"]


class MessageException(Exception):
    pass