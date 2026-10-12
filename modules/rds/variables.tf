variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  type        = string
  description = "The EKS managed node group's security group ID — the only thing allowed to reach MySQL."
}

variable "kms_key_arn" {
  type = string
}

variable "database_name" {
  type    = string
  default = "fams_db"
}

variable "master_username" {
  type    = string
  default = "fams_admin"
}

variable "engine" {
  type        = string
  default     = "mariadb"
  description = <<-EOT
    Defaults to "mariadb", not "mysql": AssuraBackend's appsettings.json pins
    Database:ServerVersion to "10.11.15-mariadb" (the free-tier host it was originally built
    against), and its EF Core migrations were generated against that dialect. Verified directly
    against a real MySQL 8.0 container: several migrations fail outright on vanilla MySQL
    (ADD COLUMN IF NOT EXISTS syntax differences, a RETURNING clause MySQL doesn't support).
    RDS for MariaDB is close enough to the original host to apply cleanly without any migration
    rewrites. Only override to "mysql" after fixing the migrations' dialect-specific SQL.
  EOT
}

variable "engine_version" {
  type    = string
  default = "10.11"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage_gb" {
  type    = number
  default = 20
}

variable "max_allocated_storage_gb" {
  type    = number
  default = 100
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "backup_retention_days" {
  type        = number
  default     = 0
  description = <<-EOT
    Defaults to 0 (automated backups disabled), not because backups don't matter in general, but
    because this account's AWS Free Tier guardrails reject any nonzero retention period on this
    instance class — confirmed directly (RDS CreateDBInstance returned FreeTierRestrictionError
    at the previous default of 3). It's also a reasonable fit for what this database actually is:
    an ephemeral demo instance meant to be destroyed between sessions (see the destroy/snapshot
    workflow below), not a production system holding data that needs point-in-time recovery.
    Raise this if the account's Free Tier restriction is lifted and continuous backups matter.
  EOT
}

variable "apply_immediately" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
