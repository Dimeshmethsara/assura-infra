output "cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_secret_arn" {
  value       = module.rds.secret_arn
  description = "Secrets Manager ARN holding the DB credentials — External Secrets Operator reads this."
}

output "jwt_secret_arn" {
  value       = aws_secretsmanager_secret.jwt.arn
  description = "Secrets Manager ARN holding the JWT signing key — External Secrets Operator reads this."
}

output "github_gitops_pat_secret_name" {
  value       = aws_secretsmanager_secret.github_gitops_pat.name
  description = "Set this secret's real value manually after apply — see the resource's comment in main.tf."
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "s3_uploads_bucket_name" {
  value = module.s3_uploads.bucket_name
}

output "irsa_role_arns" {
  value = module.iam_irsa.role_arns
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "aws_region" {
  value = var.aws_region
}
