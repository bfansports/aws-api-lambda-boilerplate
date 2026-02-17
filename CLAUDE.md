# aws-api-lambda-boilerplate

## What This Is

Template repository for creating new Python Lambda API projects at bFAN Sports. Provides standardized project structure, Makefile-driven build/deploy workflows, CloudFormation templates, local testing framework, and API Gateway integration via Swagger. Used as a starting point for new serverless API microservices.

## Tech Stack

- **Runtime**: Python 3.7 (AWS Lambda) — **EOL, upgrade to 3.12 recommended** (see FINDINGS.md H-1)
- **Infrastructure**: AWS CloudFormation (native, not SAM)
- **API Spec**: Swagger/OpenAPI 2.0
- **Build Tool**: Make (Makefile-driven workflows)
- **Deployment**: AWS CLI + CloudFormation stack management
- **Testing**: Custom local Lambda emulator (`run.py`) — no unit test framework
- **Storage**: S3 (Lambda packages, CloudFormation artifacts, environment files)

## Quick Start

```bash
# Setup environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Set required environment variables (or use AWSENV)
export ENV=sandbox  # or prod
export AWSENV_NAME=hb-sandbox
export AWS_BUCKET_CODE=your-lambda-bucket
export AWS_BUCKET_ARTIFACT=your-cf-artifact-bucket
export AWS_ACCOUNT=123456789012
export AWS_DEFAULT_REGION=us-east-1
export ALIAS=dev  # Lambda alias — required for deploy and API targets

# Run lambda locally
make run/ExampleLambdaFunction EVENT=test/data/default.json

# Build and package lambda
make build/ExampleLambdaFunction

# Deploy to AWS
make deploy/ExampleLambdaFunction

# View all make targets
make
```

## Project Structure

```
aws-api-lambda-boilerplate/
├── src/                      # Lambda function code
│   └── ExampleLambdaFunction/
│       ├── __init__.py
│       └── index.py          # handler() entrypoint
├── lib/                      # Shared libraries for all lambdas
│   ├── __init__.py
│   ├── common.py             # HBError error handling class
│   └── env.py                # Runtime environment variables (generated at build)
├── templates/                # CloudFormation templates (one per lambda/API)
│   └── ExampleLambdaFunction.template  # JSON CF template
├── swagger/                  # API Gateway definitions (OpenAPI/Swagger 2.0)
│   └── api-1.0.yaml
├── test/                     # Test event fixtures + mock context
│   ├── data/default.json     # Sample Lambda event (empty object)
│   └── MockContext.py        # Lambda context simulator
├── scripts/                  # Build/deployment helper scripts
│   ├── lambda_autoalias.sh   # Create/update Lambda alias after deploy
│   └── lambda_set_perms.sh   # Grant API Gateway invoke permissions
├── build/                    # Build artifacts — pip dependencies installed here (gitignored)
├── dist/                     # Lambda ZIP packages (gitignored)
├── packaged-templates/       # CloudFormation templates with S3 refs (gitignored)
├── requirements.txt          # Python dependencies (unpinned — pin before production use)
├── run.py                    # Local lambda execution emulator
├── Makefile                  # All build/deploy commands
└── .github/workflows/        # GitHub Actions (S3 backup only)
```

## Dependencies

**AWS Resources:**
- S3 bucket for Lambda packages (`AWS_BUCKET_CODE`)
- S3 bucket for CloudFormation artifacts (`AWS_BUCKET_ARTIFACT`)
- IAM roles for Lambda execution (defined in CloudFormation templates)
- CloudWatch Logs (automatically created per Lambda)
- SNS topic `hb-notification-email` (for error alarms — hardcoded in template)
- API Gateway (optional, deployed via Swagger)

**Python Libraries (requirements.txt):**
- `boto3` — AWS SDK (NOTE: already included in Lambda runtime; bundling it bloats the ZIP)
- `requests` — HTTP client
- `requests-aws4auth` — AWS Signature V4 auth for requests
- `urllib3` — HTTP library (dependency of requests)
- `simplejson` — JSON encoder/decoder

**None of these are version-pinned.** Pin before production use.

**Environment Files:**
- `.env` file downloaded from S3 at build time
- Naming convention: `${AWSENV_NAME}_creds`
- Stored in `${AWS_BUCKET_CODE}` bucket
- Format: `KEY='value'` (shell-compatible, copied to `lib/env.py` as Python)
- **Security concern:** Secrets are baked into the deployment ZIP — see FINDINGS.md C-1

## API / Interface

**Creating a New Lambda Project from This Boilerplate:**
1. Clone this repo
2. Remove `.git` and `git init` fresh
3. Rename `src/ExampleLambdaFunction/` to your function name (PascalCase)
4. Rename and update `templates/ExampleLambdaFunction.template` — change ALL resource names
5. Update `swagger/` if creating API Gateway endpoints
6. **Scope IAM permissions** in the template — do NOT keep the wildcard `dynamodb:*` default
7. Update `requirements.txt` with only the dependencies you need (remove `boto3`)
8. Commit to new repo

**Lambda Handler Contract:**
```python
def handler(event, context):
    # event: dict with request data (API Gateway proxy, SNS, etc.)
    # context: AWS Lambda context object (request_id, function_name, etc.)
    # Return: dict (for API Gateway) or None
    pass
```

**Error Handling Pattern (HBError):**
```python
from lib.common import HBError

def handler(event, context):
    try:
        # Business logic
        result = do_work(event)
        return result
    except HBError as e:
        # Controlled error — maps to specific HTTP status via Swagger
        print(e)  # Logs formatted error to CloudWatch
        raise Exception(e.what)  # e.what matches Swagger error regex
    except Exception as e:
        # Uncontrolled error — maps to 500 via 'error.*' regex in Swagger
        print(HBError(str(type(e)) + " : " + str(e)))
        raise Exception('error: descriptive message here')
```

The Swagger file maps Lambda error messages to HTTP status codes using regex patterns in `x-amazon-apigateway-integration.responses`. For example:
- `'user_not_found'` -> 404
- `'error.*'` -> 500
- `default` -> 200

## Key Patterns

- **Function Isolation**: Each Lambda in its own `src/<FunctionName>/` directory
- **Shared Libraries**: Common code in `lib/` (included in all Lambda ZIPs)
- **CloudFormation-first**: All AWS resources defined as code in `templates/`
- **Environment Variable Injection**: `.env` from S3 -> `lib/env.py` at build time (see Security section)
- **Local Testing**: `run.py` simulates Lambda execution locally with `MockContext`
- **ZIP Packaging**: Dependencies + `lib/` + function code packaged as ZIP, uploaded to S3
- **Makefile Targets**: `make run/<name>`, `make build/<name>`, `make deploy/<name>`
- **Swagger-driven API**: API Gateway created/updated from OpenAPI YAML with variable substitution
- **Lambda Aliases**: Every deploy creates/updates an alias (`ALIAS` env var) for safe rollbacks
- **Error-to-HTTP Mapping**: HBError.what string -> Swagger regex -> HTTP status code

## Security Defaults (READ BEFORE CLONING)

The boilerplate ships with intentionally permissive defaults for ease of setup. **You MUST tighten these before production use:**

| Default | Risk | Fix |
|---------|------|-----|
| `dynamodb:*` on all tables | Full DynamoDB access account-wide | Scope to specific table ARNs and actions |
| `logs:*` on all log groups | Can delete any log group | Restrict to `CreateLogGroup`, `CreateLogStream`, `PutLogEvents` on own log group |
| `credentials: 'arn:aws:iam::*:user/*'` in Swagger | Any AWS account can invoke | Use dedicated API GW execution role with account ID |
| Secrets in `lib/env.py` | Plaintext in ZIP | Use Secrets Manager or SSM Parameter Store |
| X-Ray `PassThrough` | No tracing unless caller sends header | Set to `Active` |
| No log retention | Logs kept forever | Set `RetentionInDays` in CF template |
| No input validation | Unvalidated event data | Add schema validation in handler |

## Environment

**Build-time Environment Variables (required):**
| Variable | Purpose | Example |
|----------|---------|--------|
| `ENV` | Deployment environment | `sandbox`, `prod` |
| `AWSENV_NAME` | AWSENV profile name | `hb-sandbox`, `hb-prod` |
| `AWS_BUCKET_CODE` | S3 bucket for Lambda ZIPs | `my-lambda-code-bucket` |
| `AWS_BUCKET_ARTIFACT` | S3 bucket for CF templates | `my-cf-artifacts-bucket` |
| `AWS_ACCOUNT` | AWS account ID (12-digit) | `123456789012` |
| `AWS_DEFAULT_REGION` | AWS region | `us-east-1`, `eu-west-1` |
| `ALIAS` | Lambda alias name | `dev`, `staging`, `prod` |

**Runtime Environment Variables (in Lambda):**
- Sourced from `lib/env.py` (generated from `.env` file in S3 at build time)
- All variables defined in the env file become Python module-level variables

**AWS CLI Configuration:**
- Must have credentials configured (`aws configure` or AWSENV)
- IAM permissions needed: CloudFormation, Lambda, S3, IAM, CloudWatch, API Gateway

## Deployment

**Deployment Flow:**
```
make deploy/<FunctionName>
  ├── 1. _check-aws-env          # Verify AWSENV_NAME is set
  ├── 2. _check-alias             # Verify ALIAS is set
  ├── 3. _check-artifact-bucket   # Verify AWS_BUCKET_ARTIFACT is set
  ├── 4. .env target              # Download ${AWSENV_NAME}_creds from S3 -> lib/env.py
  ├── 5. dist/<name>.zip          # Build ZIP (pip install + lib/ + src/<name>/)
  ├── 6. cf package               # Upload template to S3, replace local refs with S3 URIs
  ├── 7. cf deploy                # Create/update CloudFormation stack
  └── 8. lambda_autoalias.sh      # Create or update Lambda alias
```

**API Gateway Deployment:**
```bash
# Create new API
make api VERS=1.0 CREATE=1 ALIAS=prod

# Update existing API and deploy to stage
make api VERS=1.0 UPDATE=<api-id> STAGE=prod ALIAS=prod

# Update without resetting Lambda permissions
make api VERS=1.0 UPDATE=<api-id> ALIAS=prod NOPERMS=1
```

The `api` target performs variable substitution in the Swagger file:
- `%AWS_ACCOUNT%` -> `${AWS_ACCOUNT}`
- `%AWS_REGION%` -> `${AWS_DEFAULT_REGION}`
- `%ALIAS%` -> `${ALIAS}`

**CloudFormation Stack Naming:**
The stack name defaults to the function directory name (e.g., `ExampleLambdaFunction`). Set explicitly in `make deploy` if a different convention is needed.

## Testing

**Local Execution (only testing method available):**
```bash
# Run with sample event
make run/ExampleLambdaFunction EVENT=test/data/default.json

# Run with verbose output
make run/ExampleLambdaFunction VERBOSE=1 EVENT=test/data/custom.json

# Run with stdin input (type JSON, then Ctrl-D)
make run/ExampleLambdaFunction
```

**No unit test framework is configured.** The `test/` directory contains only mock context and sample events. `test/README.md` says "Here you can put your unit tests files if you start implementing unit tests."

**No CI/CD pipeline for testing.** The only GitHub Action is an S3 backup on the `develop` branch (which does not match the `master` default branch).

## Gotchas

- **Python 3.7 EOL**: Runtime is end-of-life. Cannot create new Lambda functions with this runtime on AWS. Upgrade to 3.12.
- **`ALIAS` is required**: The `deploy` target requires `ALIAS` env var but this is not obvious from the README. Deploy will fail at `_check-alias` without it.
- **`lib/env.py` must exist**: Any import of `lib.common` fails if `lib/env.py` does not exist (generated at build time). Run `make .env` first, or the local runner will crash.
- **`run.py` is duplicated**: The file contains the same script twice (lines 1-77 repeated at 78-155). This is a bug.
- **`sed -i` breaks on macOS**: The Makefile `api` target uses `sed -i` without the BSD-required `''` argument. The API deployment will fail on macOS.
- **Wildcard IAM in template**: The boilerplate grants `dynamodb:*` on all tables. Scope this down immediately when creating a real project.
- **boto3 in requirements.txt**: Lambda runtime provides boto3. Including it in requirements bloats the ZIP by ~80MB. Remove it unless you need a specific version.
- **SNS topic hardcoded**: Error alarm references `hb-notification-email` SNS topic. Ensure this exists in your account or the stack will fail to create.
- **GitHub Actions branch mismatch**: Backup workflow triggers on `develop` but repo default branch is `master`.
- **No `.env` in git**: Both `.env` and `lib/env.py` are gitignored. This is correct (secrets), but means you cannot run locally without AWS access to download the env file.
- **`__init__.py` required everywhere**: Missing `__init__.py` in any `src/` subdirectory silently breaks Python imports.
- **Swagger variable substitution**: The `%VAR%` placeholders in Swagger YAML are replaced by `sed` at deploy time. Do not use `%` in other contexts in the YAML.
- **Lambda package size**: 50MB zipped limit. Keep dependencies minimal. Current `requirements.txt` with boto3 is dangerously close to this limit.
