# cloud-iac-lab

[![CI](https://github.com/hamza7990/cloud-iac-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/hamza7990/cloud-iac-lab/actions/workflows/ci.yml)

Terraform for a small AWS setup: a network, a versioned S3 bucket, and a
Python Lambda with a DynamoDB table. CI checks the code and then really
applies it, against LocalStack (a local AWS imitation), so no AWS account or
key is needed. After applying, a smoke test uses the deployed function and
`terraform destroy` removes everything.

## Architecture

```
envs/dev   envs/prod          (same modules, different variables)
      \       /
       v     v
 +-----------------------------------------------------------+
 | modules/network   VPC 10.x.0.0/16                         |
 |   public subnets  x2 (2 AZs) --> route table --> IGW      |
 |   private subnets x2 (2 AZs) --> route table (no internet)|
 |   security groups: web (443 in) --> app (8080 from web)   |
 +-----------------------------------------------------------+
 | modules/storage   S3 bucket                               |
 |   versioning, AES256, public access block, lifecycle      |
 +-----------------------------------------------------------+
 | modules/app                                               |
 |   Lambda URL (IAM auth) --> Lambda (lambda/handler.py)    |
 |        IAM role: PutItem/GetItem on ONE table, log writes |
 |        |--> DynamoDB table (PITR on, encrypted)           |
 |        '--> CloudWatch log group (retention set)          |
 +-----------------------------------------------------------+

 state:  S3 bucket + DynamoDB lock table   (created by bootstrap/)
```

## Repository map

| Path | What it is |
| --- | --- |
| `modules/network` | VPC, 2 public + 2 private subnets, internet gateway, route tables, 2 security groups |
| `modules/storage` | S3 bucket with versioning, encryption, public access block, lifecycle rule |
| `modules/app` | zips and deploys the Lambda, DynamoDB table, least-privilege IAM role, log group, function URL |
| `envs/dev`, `envs/prod` | compose the three modules with different values, own state key |
| `envs/*/backend-localstack.hcl` | S3 backend settings for LocalStack (used in CI) |
| `envs/*/backend-aws.hcl.example` | the same settings for real AWS |
| `bootstrap/` | creates the state bucket and lock table (uses local state) |
| `lambda/handler.py` | the function: `/health`, `POST /items`, `GET /items?id=` |
| `tests/` | pytest unit tests, DynamoDB mocked with moto |
| `scripts/smoke.sh` | checks the applied environment |
| `.tflint.hcl`, `.checkov.yaml` | linter settings; every skipped check has a reason |
| `docs/oidc.md` | how GitHub gets AWS access with no stored key |
| `.github/workflows/ci.yml` | the pipeline below |
| `.github/workflows/oidc-aws.yml` | OIDC example, manual only |

## Run it yourself

Needs Terraform 1.9+, Docker, and the AWS CLI.

```
docker run -d --name localstack -p 4566:4566 \
  -v /var/run/docker.sock:/var/run/docker.sock localstack/localstack:4.0.3

export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
export TF_VAR_localstack_endpoint=http://localhost:4566

terraform -chdir=bootstrap init && terraform -chdir=bootstrap apply -auto-approve
terraform -chdir=envs/dev init -backend-config=backend-localstack.hcl
terraform -chdir=envs/dev apply
bash scripts/smoke.sh
terraform -chdir=envs/dev destroy
```

Unit tests: `pip install -r requirements-dev.txt && pytest`.

## Remote state

State is kept in S3 and a DynamoDB table holds the lock. `bootstrap/` creates
both with local state (something has to exist first). Each environment then
runs `terraform init -backend-config=<file>`, so the backend block stays empty
in code and the bucket names live in a file. `backend-localstack.hcl` points the
backend at LocalStack; `backend-aws.hcl.example` is the real AWS version.
CI checks the state file lands in the bucket under `dev/`.

## What the pipeline does

`ci.yml` has three jobs:

1. `lambda`: ruff (lint and format check) and pytest.
2. `static`: `terraform fmt -check`, `terraform validate` for bootstrap, dev and
   prod, tflint, and checkov. Checkov skips only the checks listed in
   `.checkov.yaml`, each with the reason.
3. `localstack` (after the first two pass): starts LocalStack, applies
   `bootstrap`, runs `init` with the S3 backend, `plan` (the plan is written
   to the job summary), `apply`, a second plan that must be empty, the
   smoke test, and finally `destroy`. The smoke test checks bucket
   versioning, the 4 subnets, invokes the Lambda for `/health`, a POST and a GET,
   and reads the item straight from DynamoDB.

`oidc-aws.yml` only shows the OIDC pattern and runs by hand.

## Notes on LocalStack

LocalStack is not AWS. It accepts the API calls but does not enforce IAM
policies or really route network traffic, so the smoke test proves the
resources are created and the code works, not that the policy is tight.
The Lambda function URL is created but the test invokes the function through
the Lambda API, because URL signing is not worth emulating.

## What I would add next

- Run `terraform plan` on pull requests and comment it on the PR.
- A real AWS account for prod, using the OIDC role from `docs/oidc.md`.
- NAT gateway or VPC endpoints, VPC flow logs, and an API Gateway with a WAF.
- A KMS key for S3, DynamoDB and logs.
- CloudWatch alarms (errors, throttles) and an SNS topic.
- Terratest or `terraform test` for the modules.
