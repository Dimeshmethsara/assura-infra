#!/usr/bin/env bash
# Tears down the demo environment. RDS always leaves a final snapshot (see modules/rds) before
# being destroyed, so the next demo-up.sh + a `snapshot_identifier` var restores it in minutes
# instead of starting from an empty database. What survives destroy at near-zero cost: ECR
# images, the S3 uploads bucket, the Terraform state backend, and the RDS final snapshot.
set -euo pipefail

cd "$(dirname "$0")/../environments/demo"

if [ ! -f backend.hcl ]; then
  echo "backend.hcl not found — nothing to destroy from this machine without it." >&2
  exit 1
fi

terraform init -backend-config=backend.hcl -input=false
terraform destroy -input=false -auto-approve

echo
echo "Demo environment destroyed. RDS final snapshot (if any) is listed via:"
echo "  aws rds describe-db-snapshots --query \"DBSnapshots[?contains(DBSnapshotIdentifier, 'assura')].DBSnapshotIdentifier\""
