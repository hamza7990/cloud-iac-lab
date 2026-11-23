# With localstack_endpoint = null this is a normal AWS provider.
# With an endpoint set, every call goes to LocalStack instead.
provider "aws" {
  region = var.region

  access_key                  = var.localstack_endpoint == null ? null : "test"
  secret_key                  = var.localstack_endpoint == null ? null : "test"
  skip_credentials_validation = var.localstack_endpoint != null
  skip_metadata_api_check     = var.localstack_endpoint != null
  skip_requesting_account_id  = var.localstack_endpoint != null
  s3_use_path_style           = var.localstack_endpoint != null

  dynamic "endpoints" {
    for_each = var.localstack_endpoint == null ? [] : [var.localstack_endpoint]

    content {
      s3         = endpoints.value
      dynamodb   = endpoints.value
      lambda     = endpoints.value
      iam        = endpoints.value
      cloudwatch = endpoints.value
      logs       = endpoints.value
      sts        = endpoints.value
      ec2        = endpoints.value
    }
  }

  default_tags {
    tags = {
      Project     = "cloud-iac-lab"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
