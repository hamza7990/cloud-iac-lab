variable "name" {
  description = "Prefix for resource names."
  type        = string
}

variable "source_dir" {
  description = "Folder with the Lambda code (handler.py)."
  type        = string
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "timeout" {
  type    = number
  default = 10
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "log_level" {
  description = "Passed to the function as LOG_LEVEL."
  type        = string
  default     = "INFO"
}
