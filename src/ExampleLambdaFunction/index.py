import boto3
from lib import env
from lib import common
from lib.common import HBError

# Use AWS SDK to use AWS resources. Here DynamoDB service.
# You can use any AWS SDK here for using any AWS services.
# As long as your Lambda has the rights to do it.
dynamodb  = boto3.resource('dynamodb')

def handler(event, context):
  try:
    print("Hello world")

    # We raise an exception because we encountered a control error
    # Example: user_not_found or round_not_found
    # Those are not crashes or exception but error we want to return to the client
    raise HBError("user_not_found")

  # We catch a controlled exception
  except HBError as e:
    # We print the exception in the logs
    print(e)
    # We raise a new exception with the type of error we want.
    # This way we can map the error 'user_not_found' in our API and return the proper HTTP error code (e.g: 404)
    # The mapping is done in the Swagger file of the API
    raise Exception(e.what) # We exit the Lambda
    # This is an unwanted exception
  except Exception as e:
    # We print the unwanted exception in the Hello Birdie formatted way
    print(HBError(str(type(e)) + " : " + str(e)))
    # This will raise a generic Python exception.
    # The error output message start with 'error: '. It is useful to match error codes in the API.
    # We return to the Lambda execution environment
    raise Exception('error: My Lambda failed miserably.') # We exit the Lambda
