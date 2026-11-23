output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "bucket_name" {
  value = module.storage.bucket_name
}

output "function_name" {
  value = module.app.function_name
}

output "function_url" {
  value = module.app.function_url
}

output "table_name" {
  value = module.app.table_name
}
