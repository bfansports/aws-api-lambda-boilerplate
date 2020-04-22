import boto3
import sys
import traceback
from lib import env

# Hello Birdie ERROR Class. To use to throw a formatted error.
# This will be interpreted filtered by CloudWatch
class HBError(Exception):
    def __init__(self, what):
        self.what = what

    def __str__(self):

        exc_type, exc_obj, exc_tb = sys.exc_info()
        tb = traceback.extract_tb(exc_tb)

        msg = "[ERROR] " + self.what
        for filename, lineno, name, line in tb:
            # Search for newline char
            msg += ('\nFile \"%s\", line %d, in %s in \'%s\'' %
                (filename, lineno, name, line))
        return (msg)

