#!/usr/bin/env bash
# Spins up the full demo environment from scratch: VPC/EKS/RDS/etc. via Terraform, then waits
# for ArgoCD to sync every platform component before printing the app's URL. Budget ~30-45 min
# end to end — EKS control-plane provisioning alone typically takes 10-15 min.
set -euo pipefail

cd "$(dirname "$0")/../environments/demo"

if [ ! -f backend.hcl ]; then
  echo "backend.hcl not found — copy backend.hcl.example and fill in the state bucket/table" >&2
  echo "from environments/global's outputs first." >&2
  exit 1
fi

terraform init -backend-config=backend.hcl -input=false
terraform apply -input=false -auto-approve

CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw aws_region)

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

echo "Waiting for ArgoCD root Application to become Synced/Healthy..."
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/root-app --timeout=600s
kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/root-app --timeout=600s

echo
echo "Demo environment is up."
echo "ALB DNS name:"
kubectl -n assura-app get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
echo
