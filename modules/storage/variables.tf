variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "noncurrent_version_days" {
  description = "Days to keep old object versions before they are deleted."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow destroy even when the bucket still has objects."
  type        = bool
  default     = false
}
