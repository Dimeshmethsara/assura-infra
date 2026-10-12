variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type        = string
  description = "Used only for the kubernetes.io subnet discovery tags — the EKS module creates the actual cluster."
}

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.60.0.0/16"
}

variable "tags" {
  type    = map(string)
  default = {}
}
