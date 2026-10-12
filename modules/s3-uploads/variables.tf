variable "name_prefix" {
  type = string
}

variable "unique_suffix" {
  type        = string
  description = "S3 bucket names are globally unique across all of AWS — pass something like the AWS account ID to avoid collisions."
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
