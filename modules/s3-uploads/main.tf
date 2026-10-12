# Private bucket for receipts/product-images/asset-request attachments (see AssuraBackend's
# IFileStorageService/S3FileStorageService). Nothing here is served directly from S3 to the
# public internet — the backend generates short-lived pre-signed URLs on demand — so the bucket
# stays fully private with public access blocked at every level.

resource "aws_s3_bucket" "uploads" {
  bucket = "${var.name_prefix}-uploads-${var.unique_suffix}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bounds the version-history storage cost that comes with versioning being on — old versions of
# an uploaded receipt/photo don't need to live forever.
resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Access control is identity-based, not bucket-policy-based: the iam-irsa module attaches a
# policy directly to the backend's IRSA role scoped to this bucket's ARN (the standard pattern
# for same-account access — a bucket-policy allow-statement naming that role would additionally
# create a module dependency cycle, since iam-irsa also needs this bucket's ARN as an input).
# The one thing enforced here at the bucket level is transport security, which is a data-plane
# control independent of who's asking.
data "aws_iam_policy_document" "uploads" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.uploads.arn, "${aws_s3_bucket.uploads.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  policy = data.aws_iam_policy_document.uploads.json
}
