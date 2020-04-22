#!/usr/bin/env python

import time
import argparse
import importlib
import logging
import sys
import json
import traceback
from test import MockContext
from pprint import pprint

# Parse CLI arguments
parser = argparse.ArgumentParser(description='Run a Lambda function locally.')
parser.add_argument('--verbose', '-v', action='count', default=0,
                    help='Show more output (one -v for WARNING, two for INFO, three for DEBUG)')
parser.add_argument('name', metavar='NAME', type=str, nargs='?',
                    help='Name of the function to be run')
parser.add_argument('input', metavar='FILE', type=argparse.FileType('r'), nargs='?', default=sys.stdin,
                    help='File to get input from, or "-" for stdin')
args = parser.parse_args()

def get_payload(input, default=''):
    try:
        print("\nResults:")
        print("--------")
        print("Enter your JSON input or Ctrl-D for no input:")
        payload = json.dumps(json.load(input))
        payload = json.loads(payload)
        payload = json.dumps(payload)
    except Exception as e:
        print(e)
        payload = default

    return payload

# Set up context
response = ''
event = None
context = MockContext.MockContext(args.name, '$LATEST')
logging.basicConfig(
    datefmt="%Y-%m-%dT%H:%M:%S%Z",
    stream=sys.stderr,
    format=None,
    level=(logging.ERROR - args.verbose * 10)
)

try:
    # Run the function
    module = importlib.import_module('src.{name}.index'.format(name=args.name))
    event_json = get_payload(args.input, '{}')
    event = json.loads(event_json);
    start_time = time.time()
    response = module.handler(event, context)
    end_time = time.time() - start_time;

except Exception as exc:
    exc_type, exc_value, exc_traceback = sys.exc_info()
    response = {
        'errorMessage': str(exc_value),
        'stackTrace': traceback.extract_tb(exc_traceback),
        'errorType': exc_type.__name__
    }
    del exc_traceback

print("\nOutput:\n--------")
pprint(response)
# pprint(json.dumps(response, indent=4, separators=(',', ': ')))

if event is not None:
    print("\nInput:\n--------")
    pprint(event)

if 'end_time' in locals():
    print('\nLambda EXEC TIME')
    print("-> %s seconds" % end_time)

#!/usr/bin/env python

import time
import argparse
import importlib
import logging
import sys
import json
import traceback
from test import MockContext
from pprint import pprint

# Parse CLI arguments
parser = argparse.ArgumentParser(description='Run a Lambda function locally.')
parser.add_argument('--verbose', '-v', action='count', default=0,
                    help='Show more output (one -v for WARNING, two for INFO, three for DEBUG)')
parser.add_argument('name', metavar='NAME', type=str, nargs='?',
                    help='Name of the function to be run')
parser.add_argument('input', metavar='FILE', type=argparse.FileType('r'), nargs='?', default=sys.stdin,
                    help='File to get input from, or "-" for stdin')
args = parser.parse_args()

def get_payload(input, default=''):
    try:
        print("\nResults:")
        print("--------")
        print("Enter your JSON input or Ctrl-D for no input:")
        payload = json.dumps(json.load(input))
        payload = json.loads(payload)
        payload = json.dumps(payload)
    except Exception as e:
        print(e)
        payload = default

    return payload

# Set up context
response = ''
event = None
context = MockContext.MockContext(args.name, '$LATEST')
logging.basicConfig(
    datefmt="%Y-%m-%dT%H:%M:%S%Z",
    stream=sys.stderr,
    format=None,
    level=(logging.ERROR - args.verbose * 10)
)

try:
    # Run the function
    module = importlib.import_module('src.{name}.index'.format(name=args.name))
    event_json = get_payload(args.input, '{}')
    event = json.loads(event_json);
    start_time = time.time()
    response = module.handler(event, context)
    end_time = time.time() - start_time;

except Exception as exc:
    exc_type, exc_value, exc_traceback = sys.exc_info()
    response = {
        'errorMessage': str(exc_value),
        'stackTrace': traceback.extract_tb(exc_traceback),
        'errorType': exc_type.__name__
    }
    del exc_traceback

print("\nOutput:\n--------")
pprint(response)
# pprint(json.dumps(response, indent=4, separators=(',', ': ')))

if event is not None:
    print("\nInput:\n--------")
    pprint(event)

if 'end_time' in locals():
    print('\nLambda EXEC TIME')
    print("-> %s seconds" % end_time)

