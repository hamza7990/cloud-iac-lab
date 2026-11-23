# Creates the bucket and lock table that hold the state of dev and prod.
# This folder itself uses local state: something has to exist first.
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70, < 5.80"
    }
  }
}

variable "localstack_endpoint" {
  type    = string
  default = null
}

variable "state_bucket" {
  type    = string
  default = "cloud-iac-lab-tfstate"
}

variable "lock_table" {
  type    = string
  default = "cloud-iac-lab-tflock"
}

provider "aws" {
  region = "us-east-1"

  access_key                  = var.localstack_endpoint == null ? null : "test"
  secret_key                  = var.localstack_endpoint == null ? null : "test"
  skip_credentials_validation = var.localstack_endpoint != null
  skip_metadata_api_check     = var.localstack_endpoint != null
  skip_requesting_account_id  = var.localstack_endpoint != null
  s3_use_path_style           = var.localstack_endpoint != null

  dynamic "endpoints" {
    for_each = var.localstack_endpoint == null ? [] : [var.localstack_endpoint]

    content {
      s3       = endpoints.value
      dynamodb = endpoints.value
    }
  }
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Terraform writes a lock row here while it runs, so two runs
# cannot change the same state at once.
resource "aws_dynamodb_table" "lock" {
  name         = var.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "lock_table" {
  value = aws_dynamodb_table.lock.name
}
