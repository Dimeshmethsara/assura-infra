# One IAM role per workload identity, each trust-scoped to exactly one Kubernetes ServiceAccount
# via the cluster's OIDC provider (IRSA), and each permissions-scoped to only the AWS actions
# that specific workload needs. No node-wide IAM role grants any of this — every credential a pod
# gets is requested by that pod's own ServiceAccount token, not inherited from the EC2 instance.

data "aws_iam_policy_document" "assume_role" {
  for_each = var.service_accounts

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each           = var.service_accounts
  name               = "${var.name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume_role[each.key].json
  tags               = var.tags
}

# --- backend: S3 (uploads bucket only) + KMS decrypt/encrypt (data key only) ---
data "aws_iam_policy_document" "backend" {
  statement {
    sid       = "S3Uploads"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.s3_uploads_bucket_arn}/*"]
  }

  statement {
    sid       = "KmsDataKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_data_key_arn]
  }
}

resource "aws_iam_role_policy" "backend" {
  count  = contains(keys(var.service_accounts), "backend") ? 1 : 0
  name   = "s3-and-kms"
  role   = aws_iam_role.this["backend"].id
  policy = data.aws_iam_policy_document.backend.json
}

# --- external-secrets: read-only, scoped to this project's secrets by ARN prefix ---
data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid       = "ReadProjectSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:*:*:secret:${var.name_prefix}/*"]
  }

  statement {
    sid       = "DecryptWithDataKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_data_key_arn]
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  count  = contains(keys(var.service_accounts), "external-secrets") ? 1 : 0
  name   = "read-secrets"
  role   = aws_iam_role.this["external-secrets"].id
  policy = data.aws_iam_policy_document.external_secrets.json
}

# --- fluent-bit: write-only log shipping to this project's log groups ---
data "aws_iam_policy_document" "fluent_bit" {
  statement {
    sid    = "WriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/${var.name_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "fluent_bit" {
  count  = contains(keys(var.service_accounts), "fluent-bit") ? 1 : 0
  name   = "write-logs"
  role   = aws_iam_role.this["fluent-bit"].id
  policy = data.aws_iam_policy_document.fluent_bit.json
}

# --- jenkins-agent: push/pull to this project's ECR repos + sign with the cosign key only ---
data "aws_iam_policy_document" "jenkins_agent" {
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken does not support resource-level scoping
  }

  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = var.ecr_repository_arns
  }

  statement {
    sid       = "ReadGitOpsPushCredential"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.github_gitops_pat_secret_arn]
  }

  statement {
    sid       = "SignWithCosignKeyOnly"
    effect    = "Allow"
    actions   = ["kms:Sign", "kms:GetPublicKey"]
    resources = [var.kms_cosign_key_arn]
  }
}

resource "aws_iam_role_policy" "jenkins_agent" {
  count  = contains(keys(var.service_accounts), "jenkins-agent") ? 1 : 0
  name   = "ecr-cosign-sign-and-gitops-pat"
  role   = aws_iam_role.this["jenkins-agent"].id
  policy = data.aws_iam_policy_document.jenkins_agent.json
}

# --- aws-load-balancer-controller: the AWS-published policy (large, standard, not hand-rolled) ---
data "http" "alb_controller_policy" {
  count = contains(keys(var.service_accounts), "aws-load-balancer-controller") ? 1 : 0
  url   = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json"
}

resource "aws_iam_role_policy" "alb_controller" {
  count  = contains(keys(var.service_accounts), "aws-load-balancer-controller") ? 1 : 0
  name   = "alb-controller"
  role   = aws_iam_role.this["aws-load-balancer-controller"].id
  policy = data.http.alb_controller_policy[0].response_body
}
