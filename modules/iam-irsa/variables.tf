variable "name_prefix" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider" {
  type        = string
  description = "The OIDC provider's issuer hostname (no https://), e.g. module.eks.oidc_provider — used in the trust policy's condition keys."
}

variable "service_accounts" {
  type = map(object({
    namespace = string
    name      = string
  }))
  description = "One entry per workload identity needing AWS access. Keys expected by this module's policy attachments: backend, external-secrets, fluent-bit, jenkins-agent, aws-load-balancer-controller."
}

variable "s3_uploads_bucket_arn" {
  type = string
}

variable "kms_data_key_arn" {
  type = string
}

variable "kms_cosign_key_arn" {
  type = string
}

variable "github_gitops_pat_secret_arn" {
  type        = string
  description = "Secrets Manager ARN holding the GitHub PAT Jenkins uses to push image-tag updates to the assura-gitops repo (see environments/demo/main.tf's github_gitops_pat secret)."
}

variable "ecr_repository_arns" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
