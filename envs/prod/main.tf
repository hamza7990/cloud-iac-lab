# Same modules as dev, safer values: more memory, long log retention,
# long version history, no force destroy.
module "network" {
  source = "../../modules/network"

  name     = "cloud-iac-lab-prod"
  vpc_cidr = "10.20.0.0/16"
  az_count = 2
}

module "storage" {
  source = "../../modules/storage"

  bucket_name             = var.bucket_name
  noncurrent_version_days = 90
  force_destroy           = false
}

module "app" {
  source = "../../modules/app"

  name               = "cloud-iac-lab-prod"
  source_dir         = "${path.root}/../../lambda"
  memory_size        = 256
  timeout            = 15
  log_retention_days = 365
  log_level          = "INFO"
}
