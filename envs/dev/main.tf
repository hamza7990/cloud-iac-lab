# Small and cheap: two AZs, short log retention, objects can be force-deleted.
module "network" {
  source = "../../modules/network"

  name     = "cloud-iac-lab-dev"
  vpc_cidr = "10.10.0.0/16"
  az_count = 2
}

module "storage" {
  source = "../../modules/storage"

  bucket_name             = var.bucket_name
  noncurrent_version_days = 7
  force_destroy           = true
}

module "app" {
  source = "../../modules/app"

  name               = "cloud-iac-lab-dev"
  source_dir         = "${path.root}/../../lambda"
  memory_size        = 128
  log_retention_days = 7
  log_level          = "DEBUG"
}
