terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70, < 5.80"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }

  # Settings come from a file: terraform init -backend-config=<file>
  # (see backend-localstack.hcl and backend-aws.hcl.example)
  backend "s3" {}
}
