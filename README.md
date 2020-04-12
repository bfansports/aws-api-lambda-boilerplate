# Lambdas & API boilerplate project

This repository provides a framework for writing, packaging, and
deploying lambda functions to AWS.

Functions wrote here are and must be written in python 3.7 or earlier.

You can also deploy a swagger file to create/update an AWS API Gateway API.

# Setup your env

* Python 3.7
* Pip3
* aws-cli 1.9+

Install AWS CLI tool:
http://docs.aws.amazon.com/cli/latest/userguide/installing.html#install-with-pip

Configure credentials:
http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html

If you have AWSENV configured you should also be good to go.

Make sure to have your python 3 Virtual Env setup before working within this repository.

## Deployment Environment variables

The makefile will use some environment variables:

* ENV => (sandbox|prod)
* AWSENV_NAME => (hb-sandbox|hb-prod)
* AWS_BUCKET_CODE => The S3 Bucket where your Lambda Zips will be store
* AWS_BUCKET_ARTIFIFACT => The S3 Bucket where your CloudFormation template will be stored for deployment
* AWS_ACCOUNT => The AWS Account ID
* AWS_DEFAULT_REGION => The AWS Default Region

Make sure those environment variables are set on your local system or it will NOT work.

AWSENV can set this up automatically for you based on the AWS env you've loaded. See the `config` file in your `awsenv` env folder.

## Runtime Environments variables

For your Lambdas to get the proper environment variables at runtime,
at build time we will download a `.env` file from S3 and we will move it to
`lib/env.py`.

As a result you can include the `lib/env.py` in your Lambda `index.py` files:

```
from lib import env
```

Your `.env` must follow this naming convention: `${AWSENV_NAME}_creds`
and be located in the `${AWS_BUCKET_CODE}` bucket.

The format is as follow:

```
EXAMPLE_VAR1='my_bucket'
EXAMPLE_VAR2='my_secret_api_key'
```

# Makefile

Every actions are done using the `Makefile` located at the root of the project.

Run `make` to see the help.

# Lambdas

## Writing Functions

Function code goes in the `src/` directory. Each function must be in a
sub-directory named after the function. For example, if the Lambda
function name is `example`, the code goes in the `src/example`
directory.

*Note:* Make sure you put an `__init__.py` in your folder and any
 subfolders. Check existing functions.

### Entry Point

The entrypoint file for each Lambda should be in an `index.py` file,
inside of which should be a function named `handler`. See the AWS
Lambda documentation for more details on how to write the handler.

    # src/<function>/index.py
	def handler(event, context):
		...

### Custom Libraries

All your libraries must go in the `lib` folder.

### Error management

Errors must be handled in a proper way for ALL Lambdas.

Include the `lib/common.py` file in all your Lambdas and use the HBError class
to perform Error management. See the `src/example/index.py` file for example
on how to use this HBError class.

The goal is to log errors properly and use the errors to trigger proper HTTP
error codes if the Lambda is used by API Gateway.

### Third-party Libraries

For a third-party library, use the `requirements.txt` file as you
would any Python package.  See the Python pip documentation for more
details:
https://pip.readthedocs.org/en/stable/user_guide/#requirements-files

In this file you can list all your external dependencies. They will be downloaded
and installed automatically.

## Create and deploy your lambda

Once your function is written, you need to deploy it to AWS. To do so
you need to create a Cloudformation template in to the `templates/`
folder. This template will contain all AWS components related to
the lambda: Lamdba definition, Log group, CloudWatch alarms, IAM roles, ect ...

Check existing template to create yours.

Once ready, to deploy your lambda run this command :

	make deploy/<your-lambda-name>

This command is used to create our update your lambda using AWS CloudFormation.

## Running Functions Locally

Before building and deploying, you may want to test your Lambda code
first. In order to simulate the Lambda environment, a script is
provided that will execute your function as if it was in AWS Lambda.

	usage: make run/FUNCTION [VERBOSE=1] [EVENT=filename]

	Run a Lambda function locally.

	optional arguments:
	  VERBOSE=1       Sets verbose output for the function
	  EVENT=filename  Load an event from a file rather than stdin. This file contain the input you want to send to your function.

The `make run/%` script will take a JSON event from a standard input
(or a file if you specify), and execute the function you specify.

# API Gateway

Using the Makefile in the project you can also create an update an API Gateway API.

APIs definition files are located in the `swagger` folder. They define and document
the API as code, making it easy to:

   * Generate documentation
   * Generate SDKs for the mobile app
   * Keep track of changes

