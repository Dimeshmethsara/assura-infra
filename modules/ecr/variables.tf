variable "name_prefix" {
  type = string
}

variable "repository_names" {
  type    = list(string)
  default = ["backend", "frontend"]
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
