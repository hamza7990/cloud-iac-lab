variable "name" {
  description = "Prefix for resource names and the Name tag."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "How many availability zones to spread subnets over."
  type        = number
  default     = 2
}
