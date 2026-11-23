variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "localstack_endpoint" {
  description = "LocalStack URL, or null to talk to real AWS."
  type        = string
  default     = null
}

variable "bucket_name" {
  description = "Bucket names are global, so this must be unique on real AWS."
  type        = string
  default     = "cloud-iac-lab-prod-assets"
}
