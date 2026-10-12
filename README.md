# assura-infra

Terraform for the Assura FAMS AWS deployment. See the deployment plan for full architecture
rationale — this README covers only what's needed to actually run it.

## Layout

- `environments/global/` — the Terraform state backend (S3 + DynamoDB). Applied once, essentially never destroyed.
- `environments/demo/` — the actual environment: VPC, EKS, RDS, ECR, S3, KMS, IAM/IRSA, ArgoCD bootstrap. Designed to be spun up before a demo and torn down after (see `scripts/`).
- `modules/` — `vpc` and `eks` wrap the community `terraform-aws-modules` registry modules (well-trodden infra plumbing, no reason to hand-roll it); `rds`, `ecr`, `s3-uploads`, `kms`, `iam-irsa`, `waf` are hand-written because their security posture is specific to this application.

## First-time setup

1. **State backend** (once per AWS account):
   ```bash
   cd environments/global
   cp terraform.tfvars.example terraform.tfvars   # set a globally-unique state_bucket_name
   terraform init
   terraform apply
   ```
2. **Demo environment**:
   ```bash
   cd environments/demo
   cp backend.hcl.example backend.hcl   # fill in from environments/global's outputs
   terraform init -backend-config=backend.hcl
   terraform plan   # review before applying — this creates real, billed AWS resources
   terraform apply
   ```
   Or use `scripts/demo-up.sh` / `scripts/demo-down.sh`, which wrap the same commands plus the post-apply ArgoCD wait/kubectl config.

## Placeholder values you must fill in after the first `apply`

Terraform creates the IAM roles, ECR repos, and Secrets Manager secrets, but their exact
ARNs/URLs (which include your AWS account ID) are only known after `apply` — and they're
referenced from **`assura-gitops`**, a separate repo Terraform doesn't write to (see that repo's
own architecture note on why). After your first `apply`, run `terraform output` here and use it
to replace every `CHANGE_ME` / `<AWS_ACCOUNT_ID>` placeholder in `assura-gitops`:

| Placeholder | Terraform output that fills it in |
|---|---|
| `<AWS_ACCOUNT_ID>` (in every IRSA `role-arn` annotation) | `terraform output irsa_role_arns` |
| ECR repo URL (`CHANGE_ME.dkr.ecr...`) | `terraform output ecr_repository_urls` |
| RDS/JWT Secrets Manager ARNs | `terraform output rds_secret_arn`, `terraform output jwt_secret_arn` |
| S3 uploads bucket name | `terraform output s3_uploads_bucket_name` |

This is a one-time step per AWS account, not something that changes per deploy — these values
are account/environment constants, not secrets themselves (the ARNs are just addresses; the
actual secret *values* stay in Secrets Manager and are never written to either git repo).

## GitHub credentials Terraform can't create for you

Terraform creates the *container* for one credential it cannot generate the value of — a GitHub
PAT Jenkins uses to push image-tag updates to `assura-gitops` (`git push` never works
anonymously, even against a public repo). After your first `apply`:

1. Create a fine-grained GitHub PAT (Settings → Developer settings → Fine-grained tokens),
   scoped to **Contents: Read and write** on just the `assura-gitops` repository.
2. `aws secretsmanager put-secret-value --secret-id $(terraform output -raw github_gitops_pat_secret_name) --secret-string '{"token":"<paste PAT here>"}'`

The `jenkins-agent` IRSA role can read only this one secret in Secrets Manager beyond what its
ECR/KMS permissions already cover (see `modules/iam-irsa`) — see `AssuraBackend/Jenkinsfile`'s
"Update GitOps manifest" stage for exactly how it's fetched and used (never logged, never stored
in Jenkins's own credential store).

Separately — not something Terraform or this repo touches — Jenkins also needs its own
**read** credential to check out `AssuraBackend`/`assura-frontend` as pipeline jobs in the first
place. That's ordinary Jenkins multibranch-pipeline setup (Jenkins UI or a GitHub App), a one-time
manual step outside this repo's scope.

## Cost

See the deployment plan's cost table — full environment is roughly $200–260/month while running.
`scripts/demo-down.sh` destroys everything except ECR images, the S3 bucket, Terraform state, and
an RDS final snapshot (all near-zero cost at rest).
