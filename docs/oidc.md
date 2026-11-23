# GitHub OIDC to AWS

The workflow `.github/workflows/oidc-aws.yml` is an example. It is manual
only and is never run by CI, because it needs a real AWS account.

## Why

Long-lived access keys stored as secrets can leak and never expire. With OIDC
the workflow stores nothing. Each run gets a signed token from GitHub, AWS
checks the token against a trust policy and returns credentials that last
about an hour.

## One-time setup in AWS

1. Add GitHub as an identity provider: URL `https://token.actions.githubusercontent.com`,
   audience `sts.amazonaws.com`.
2. Create an IAM role with the trust policy below. The `sub` condition is the
   important line: only this repository (and here only the `main` branch) can
   assume the role.
3. Attach the permissions the pipeline needs to that role, as little as possible.
4. Create `backend-aws.hcl` from `backend-aws.hcl.example` in the environment
   folder, then run the workflow and paste the role ARN.

## Trust policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:hamza7990/cloud-iac-lab:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

## What the workflow does

`permissions: id-token: write` lets the job request the token.
`aws-actions/configure-aws-credentials` exchanges it for temporary
credentials. After that every `aws` and `terraform` command in the job works
as the role, and the credentials disappear when the job ends.
