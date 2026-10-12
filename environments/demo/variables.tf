variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "demo"
}

variable "vpc_cidr" {
  type    = string
  default = "10.60.0.0/16"
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_types" {
  type = list(string)
  # This AWS account has a Free Tier restriction that blocks launching any EC2 instance type
  # outside its free-tier-eligible list — confirmed directly (an InvalidParameterCombination
  # error, not a capacity one, is what t3.medium/t3a.medium/t2.medium actually hit). The eligible
  # list here (`aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true`)
  # also includes t3/t4g.micro and .small, but at 1-2GiB RAM those are too small to actually fit
  # this platform's real pod set (EKS system daemonsets + Jenkins + Argo CD + Kyverno + External
  # Secrets + kube-prometheus-stack + the app itself) — that would just trade a node-launch
  # failure for a pod-scheduling one. m7i-flex.large/c7i-flex.large are both free-tier-eligible
  # for this account AND large enough (8GiB/4GiB) to comfortably run the whole stack.
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

variable "rds_multi_az" {
  type    = bool
  default = true
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "enable_waf" {
  type    = bool
  default = false
}

variable "waf_alb_arn" {
  type    = string
  default = ""
}

variable "argocd_chart_version" {
  type    = string
  default = "7.7.11"
}

variable "gitops_root_app_path" {
  type        = string
  default     = "../../../assura-gitops/bootstrap/root-app.yaml"
  description = "Path to the ArgoCD App-of-Apps manifest that bootstraps every other in-cluster component."
}

variable "tags" {
  type = map(string)
  default = {
    Project = "assura"
  }
}
