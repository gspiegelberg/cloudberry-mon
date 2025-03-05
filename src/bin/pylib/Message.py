"""
Superclass for all message types
"""

import platform
import getpass
import json
from datetime import datetime
from hashlib import sha256


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
            self._validated = False
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
            raise MessageException( f"cannot change message" )
        self.message[var] = val
        return True

    def _hash(self):
        return sha256(json.dumps(self.message, sort_keys=True).encode('utf-8')).hexdigest()

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

            """ Need hash and removed from message to validate """
            hash = self.message["x-hash"]
            if hash == self._hash():
                """ Not a validated message, do not raise exception """
                return False
        return True

    """
    Producer methods
    """
    def as_str(self):
        if self._validate():
            self._set( "x-hash", self._hash() )
            return json.dumps(self.message)

    """
    Consumer methods
    """
    def get(self, element):
        if not self.validated:
            raise MessageException( f"not a valid message" )
        if element not in self.message:
            raise MessageException( f"element {element} not in message" )
        return self.message[element]

    def req_user(self):
        return self.caller["user"]

    def req_host(self):
        return self.caller["host"]

    def req_ts(self):
        return self.caller["ts"]


class MessageException(Exception):
    pass