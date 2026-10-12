variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_instance_types" {
  type = list(string)
  # See environments/demo/variables.tf's override for why these two specifically — this
  # account's Free Tier restriction only allows launching free-tier-eligible instance types,
  # confirmed directly via a real InvalidParameterCombination error on t3.medium.
  default = ["m7i-flex.large", "c7i-flex.large"]
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
