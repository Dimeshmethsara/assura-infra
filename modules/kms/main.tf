# Two CMKs only, not one per resource: KMS charges ~$1/key/month, and every resource in this
# stack (RDS, S3, Secrets Manager) shares the same confidentiality boundary, so one shared
# symmetric key covers all of them. The cosign signing key is necessarily separate — asymmetric
# key usage (SIGN_VERIFY) cannot share a key with symmetric ENCRYPT_DECRYPT usage.

resource "aws_kms_key" "data" {
  description             = "Shared CMK for ${var.name_prefix} data at rest: RDS, S3 uploads, Secrets Manager"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.name_prefix}-data"
  target_key_id = aws_kms_key.data.key_id
}

resource "aws_kms_key" "cosign" {
  description              = "Asymmetric signing key for cosign image signing (${var.name_prefix})"
  deletion_window_in_days  = 7
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  tags                     = var.tags
}

resource "aws_kms_alias" "cosign" {
  name          = "alias/${var.name_prefix}-cosign"
  target_key_id = aws_kms_key.cosign.key_id
}
