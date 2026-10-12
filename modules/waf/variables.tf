variable "name_prefix" {
  type = string
}

variable "enable_waf" {
  type    = bool
  default = false
}

variable "alb_arn" {
  type        = string
  default     = ""
  description = <<-EOT
    The ALB's ARN, required only when enable_waf = true. The ALB itself is created out-of-band
    by the in-cluster AWS Load Balancer Controller (via a Kubernetes Ingress), not by Terraform,
    so its ARN isn't known at initial `terraform apply` time. Enabling WAF is therefore a
    deliberate two-step, manually-triggered workflow: bring the cluster + Ingress up first, look
    up the resulting ALB's ARN (`aws elbv2 describe-load-balancers`), then re-apply with
    `-var enable_waf=true -var alb_arn=<arn>` — matching the "flip on right before a demo,
    don't pay for it year-round" intent from the deployment plan.
  EOT
}

variable "rate_limit_per_5min" {
  type    = number
  default = 2000
}

variable "tags" {
  type    = map(string)
  default = {}
}
