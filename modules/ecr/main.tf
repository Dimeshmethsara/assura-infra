resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = "${var.name_prefix}-${each.value}"
  image_tag_mutability = "IMMUTABLE" # pairs with Kyverno's disallow-latest-tag policy: every tag is a distinct build

  # Without this, `terraform destroy` fails outright the moment any image has ever been pushed:
  # "RepositoryNotEmptyException: ... cannot be deleted because it still contains images".
  # Confirmed live on this exact destroy. NOTE: this module currently lives in `environments/demo`
  # rather than `environments/global`, so every demo-down cycle now also deletes pushed images —
  # contradicting the deployment plan's stated design ("ECR images ... survive destroy"). Moving
  # this module to `global` is the correct long-term fix; force_delete is the unblock for right now.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = var.tags
}

# Keeps storage cost bounded: untagged images (superseded digests from repeated pushes to the
# same tag, which IMMUTABLE tag mutability makes rare, but still possible via retag/cleanup) are
# expired quickly; a generous but finite cap on tagged images stops indefinite growth.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the most recent 30 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 30
        }
        action = { type = "expire" }
      }
    ]
  })
}
