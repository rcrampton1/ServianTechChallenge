#------------------------------------------------
# System and General variables
#------------------------------------------------

variable "common_name" {
  description = "Common name for created items"
  default     = "servian"
}

variable "pr_number" {
  default = "null"
}

variable "bucket_sse_algorithm" {
  type        = string
  description = "Encryption algorithm to use on the S3 bucket. Currently only AES256 is supported"
  default     = "AES256"
}
