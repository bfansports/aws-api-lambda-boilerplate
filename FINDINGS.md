# AI Audit Findings — aws-api-lambda-boilerplate

**Date:** 2026-02-17
**Auditor:** DevOps Agent (Claude Opus 4.6)
**Scope:** Boilerplate security defaults, outdated patterns, dependency management, SAM/CF templates, auth patterns
**Repo:** bfansports/aws-api-lambda-boilerplate @ `master`

---

## Critical

### C-1: Credentials stored as plaintext Python file in S3

**File:** `Makefile` (line 101), `README.md` (lines 42-61)

The build process downloads a `.env` credentials file from S3 (`s3://${AWS_BUCKET_CODE}/${AWSENV_NAME}_creds`) and copies it directly to `lib/env.py`. This file is then packaged inside the Lambda ZIP and deployed as executable Python code.

**Problems:**
- Secrets are baked into the deployment artifact as a Python source file
- Anyone with access to the Lambda package (S3 bucket, Lambda console) can read all secrets
- No encryption at rest beyond S3 default (bucket encryption status unknown)
- No rotation mechanism — redeployment required to change any secret
- The file format (`KEY='value'`) is executed as Python, meaning arbitrary code in the env file would execute

**Recommendation:** Migrate to AWS Secrets Manager or SSM Parameter Store (SecureString). Fetch secrets at Lambda cold-start, cache in memory. Remove the `lib/env.py` pattern entirely.

### C-2: Wildcard IAM permissions in boilerplate CloudFormation template

**File:** `templates/ExampleLambdaFunction.template` (lines 43-80)

The example IAM policy grants:
- `dynamodb:*` on `arn:aws:dynamodb:*:<account>:table/*` — full DynamoDB access to ALL tables in ALL regions
- `logs:*` on `arn:aws:logs:*:<account>:*` — full CloudWatch Logs access to ALL log groups

**Problems:**
- Violates least-privilege principle
- A compromised Lambda could read/write/delete any DynamoDB table in the account
- A compromised Lambda could delete any CloudWatch log group (covering tracks)
- Since this is a boilerplate, every project cloned from it inherits these over-permissive defaults

**Recommendation:** Scope permissions to specific tables and actions. Use CloudFormation parameters for table names. Restrict logs to `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` on the function's own log group.

### C-3: API Gateway credentials use wildcard IAM principal

**File:** `swagger/api-1.0.yaml` (lines 90, 142, 202, 265)

All API Gateway integrations specify:
```yaml
credentials: 'arn:aws:iam::*:user/*'
```

This grants ANY IAM user in ANY account permission to invoke the Lambda through API Gateway. The double-colon (`iam::*`) indicates a missing account ID, and `*:user/*` is a wildcard across all accounts.

**Problems:**
- Any AWS account's IAM users could potentially invoke these APIs
- Combined with `x-amazon-apigateway-auth: type: aws_iam`, this creates a false sense of security — IAM auth is enabled but the credential scope is open

**Recommendation:** Use a dedicated API Gateway execution role: `arn:aws:iam::<account_id>:role/<api-gw-execution-role>`. Create this role in the CloudFormation template with only `lambda:InvokeFunction` permission on the specific function ARN.

---

## High

### H-1: Python 3.7 runtime — end of life

**Files:** `templates/ExampleLambdaFunction.template` (line 103), `README.md` (line 6), `CLAUDE.md` (line 9)

Python 3.7 reached end of life on 2023-06-27. AWS Lambda deprecated Python 3.7 runtime in late 2023. Functions using this runtime:
- Cannot be created (only updated) on AWS Lambda
- Receive no security patches
- Miss performance improvements in Python 3.9-3.12
- Cannot use modern language features (walrus operator, match/case, etc.)

**Recommendation:** Update to Python 3.12 (current LTS on Lambda). Test compatibility — main risks are `urllib3` v2 breaking changes and `requests` compatibility.

### H-2: GitHub Actions workflow uses hardcoded access keys

**File:** `.github/workflows/github-backup.yml` (lines 13-14)

The S3 backup workflow uses `AWS_ACCESS_KEY` and `AWS_SECRET_KEY` stored as GitHub secrets with a third-party action (`peter-evans/s3-backup@v1`).

**Problems:**
- Long-lived IAM access keys (no rotation enforcement)
- Third-party action (`peter-evans/s3-backup@v1`) — supply chain risk, pinned to `v1` tag (mutable)
- The action is deprecated/unmaintained
- Uses `actions/checkout@v2` — outdated (current is v4), missing security hardening
- Triggers only on `develop` branch but repo default is `master`

**Recommendation:** Switch to OIDC federation (`aws-actions/configure-aws-credentials` with role assumption). Pin actions to commit SHAs. Update `actions/checkout` to `v4`. Fix trigger branch to `master`.

### H-3: No input validation in Lambda handler pattern

**File:** `src/ExampleLambdaFunction/index.py`

The example handler demonstrates no input validation. The `event` dict is used without any schema validation, type checking, or sanitization. Since this is a boilerplate, developers copy this pattern.

**Recommendation:** Add an example of input validation in the handler (at minimum, key existence checks). Consider adding `jsonschema` or a lightweight validator to `requirements.txt` as an optional pattern.

### H-4: Dependencies unpinned — no version constraints

**File:** `requirements.txt`

```
boto3
requests
requests-aws4auth
urllib3
simplejson
```

No version pins. `pip install` will grab latest versions, which may:
- Introduce breaking changes between builds
- Pull in vulnerable versions
- Make builds non-reproducible

**Note:** `boto3` should not be in `requirements.txt` at all — Lambda provides it in the runtime. Including it bloats the ZIP package unnecessarily (boto3 + botocore = ~80MB uncompressed).

**Recommendation:** Pin all dependencies with exact versions (`requests==2.31.0`). Remove `boto3` (use Lambda runtime's version). Use `pip-compile` or similar for reproducible locks. Add a `urllib3<2` constraint if staying on Python 3.7/requests compatibility.

---

## Medium

### M-1: Duplicate code in run.py

**File:** `run.py`

The entire script (lines 1-77) is duplicated verbatim (lines 78-155). The file contains two complete copies of the same local runner. This suggests a copy-paste accident that was committed.

**Recommendation:** Remove the duplicate (lines 78-155).

### M-2: CloudFormation template uses legacy JSON format without Transform

**File:** `templates/ExampleLambdaFunction.template`

- Uses `AWSTemplateFormatVersion: 2010-09-09` without SAM Transform
- No `Description` field
- No `Transform: AWS::Serverless-2016-10-31` (SAM)
- File extension is `.template` instead of `.json` or `.yaml` — not recognized by IDE CloudFormation plugins
- Empty `Metadata` and `Parameters` sections add noise

**Recommendation:** Either adopt SAM (`AWS::Serverless::Function` simplifies Lambda + API Gateway) or at minimum switch to YAML for readability, add a `Description`, and use `.json`/`.yaml` extension.

### M-3: X-Ray tracing set to PassThrough

**File:** `templates/ExampleLambdaFunction.template` (lines 98-100)

```json
"TracingConfig": { "Mode": "PassThrough" }
```

PassThrough means X-Ray tracing is effectively disabled unless the caller sends a trace header. For API-backed Lambdas, this means no distributed tracing by default.

**Recommendation:** Change to `"Active"` for all API-facing Lambdas. Add the `AWSXRayDaemonWriteAccess` managed policy to the execution role.

### M-4: CloudWatch Log Group has no retention policy

**File:** `templates/ExampleLambdaFunction.template` (lines 111-117)

The `AWS::Logs::LogGroup` resource has no `RetentionInDays` property. Logs are retained indefinitely by default, which:
- Accumulates cost over time
- May violate data retention policies
- Stores potentially sensitive data forever

**Recommendation:** Set `RetentionInDays: 30` (or 90 for production) as the boilerplate default.

### M-5: No CORS configuration in API Gateway

**File:** `swagger/api-1.0.yaml`

No CORS headers are configured in any response. If the API is called from web clients (admin panel webviews), requests will fail.

**Recommendation:** Add OPTIONS methods and appropriate `Access-Control-*` headers for endpoints that may be called from browsers.

### M-6: Swagger uses deprecated 2.0 spec

**File:** `swagger/api-1.0.yaml` (line 1)

```yaml
swagger: '2.0'
```

OpenAPI 2.0 (Swagger) is outdated. While API Gateway supports it, OpenAPI 3.0+ offers better schema support, `oneOf`/`anyOf`, and is the current standard.

**Recommendation:** Migrate to OpenAPI 3.0 format when next updating the API spec. API Gateway supports both.

### M-7: Lambda handler uses module-level boto3 resource

**File:** `src/ExampleLambdaFunction/index.py` (line 9)

```python
dynamodb = boto3.resource('dynamodb')
```

Module-level SDK clients are created during cold start. While this is actually a recommended Lambda pattern for connection reuse, the example creates a DynamoDB resource even though the handler does not use it. New developers may not understand why it is module-level.

**Recommendation:** Add a comment explaining the cold-start optimization pattern. Remove unused resources from the example or use them in the handler.

### M-8: Error alarm hardcodes SNS topic name

**File:** `templates/ExampleLambdaFunction.template` (line 135)

```json
":hb-notification-email"
```

The SNS topic ARN is hardcoded to `hb-notification-email`. This:
- Fails if the topic does not exist in the deployment account/region
- Cannot be overridden per environment
- Uses the legacy "hb" (Hello Birdie) naming

**Recommendation:** Make this a CloudFormation parameter with a default value. Allow per-environment override.

---

## Low

### L-1: Legacy "Hello Birdie" / "HB" branding throughout

**Files:** `lib/common.py` (line 8), `Makefile` (line 13), `templates/ExampleLambdaFunction.template` (line 135)

The codebase uses the former company name "Hello Birdie" (HB) in class names (`HBError`), Makefile help text, and SNS topic names. The company is now bFAN Sports.

**Recommendation:** Rename `HBError` to `BFANError` or a generic name. Update help text and references. This is cosmetic but causes confusion for new team members.

### L-2: No .editorconfig or code formatting standard

The codebase mixes 2-space and 4-space indentation (Python handler uses 2-space, which violates PEP 8). No `.editorconfig`, no `pyproject.toml`, no linting configuration.

**Recommendation:** Add `.editorconfig` and consider `ruff` or `black` for Python formatting. Since this is a boilerplate, these standards propagate to all derived projects.

### L-3: `sed -i` in Makefile is not portable

**File:** `Makefile` (lines 43-47)

`sed -i` behaves differently on macOS (BSD sed requires `sed -i ''`) vs Linux (GNU sed). The current usage will fail on macOS with an error about missing backup extension.

**Recommendation:** Use `sed -i '' "s/..." file` for macOS compatibility, or use a temp file pattern: `sed 's/.../' file > file.tmp && mv file.tmp file`.

### L-4: Makefile help references "HELLO BIRDIE"

**File:** `Makefile` (line 13)

```makefile
echo "HELLO BIRDIE LAMBDA/API MAKEFILE FUNCTIONS"
```

**Recommendation:** Update to "bFAN Sports" or generic project name.

### L-5: No `.python-version` or runtime specification

No `pyproject.toml`, `setup.cfg`, `.python-version`, or `runtime.txt` to enforce the Python version locally. Developers may use any Python version.

**Recommendation:** Add `.python-version` file with `3.12` (after H-1 upgrade).

### L-6: `lib/env.py` import in `lib/common.py` will fail without build

**File:** `lib/common.py` (line 4)

```python
from lib import env
```

`lib/env.py` is generated at build time from S3. Running any code that imports `lib.common` before build will fail with `ModuleNotFoundError`. This breaks local development and IDE autocompletion.

**Recommendation:** Make the env import optional with a try/except, or remove it from `common.py` (it is not used there).

---

## Agent Skill Improvements

### S-1: CLAUDE.md needs deployment-specific patterns

The existing CLAUDE.md covers structure well but lacks:
- Security defaults and their rationale
- Common pitfalls when creating new Lambdas from the boilerplate
- Environment variable injection flow explanation
- IAM permission scoping guidance

**Action:** Updated in this PR.

### S-2: Missing `<!-- Ask: -->` gaps should be answered

The existing CLAUDE.md has several `<!-- Ask: ... -->` placeholders about Python version, AWSENV status, testing, and CI/CD. The audit provides partial answers (Python 3.7 confirmed in code, no unit tests confirmed, GitHub Actions backup only).

**Action:** Answered where possible in updated CLAUDE.md.

---

## Positive Observations

1. **CloudFormation-first approach** — All infrastructure is defined as code. No ClickOps.
2. **Error monitoring pattern** — CloudWatch metric filters + alarms are included by default. Every Lambda gets error alerting out of the box.
3. **Structured error handling** — The `HBError` pattern with API Gateway mapping provides a clean error-to-HTTP-status pipeline.
4. **Local testing capability** — `run.py` + `MockContext` allows rapid local iteration without deploying.
5. **Clean project structure** — Clear separation of concerns: `src/`, `lib/`, `templates/`, `swagger/`, `test/`, `scripts/`.
6. **Makefile automation** — Single entry point for all workflows. Environment variable checks prevent partial deployments.
7. **Alias-based deployment** — Lambda aliases enable safe rollbacks and canary deployments.
8. **API Gateway integration patterns** — The Swagger file demonstrates GET, POST, path params, query params, and VTL response mapping — a comprehensive reference.
