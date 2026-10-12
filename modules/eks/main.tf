# Wraps terraform-aws-modules/eks/aws for the same reason as the vpc module: cluster/node-group/
# OIDC-provider plumbing is well-trodden ground. The choices that matter for this project —
# Spot capacity, node count, add-on selection — are explicit below.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.private_subnet_ids

  # Public API endpoint (with the same auth/RBAC as private) keeps this reachable from a laptop
  # without a bastion/VPN — a deliberate simplicity choice for a demo cluster, not a production one.
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  # Without this, the identity that ran `terraform apply` (root, in this account) has zero
  # Kubernetes-level RBAC inside the cluster, even though it created it — IAM-authorized control-
  # plane API calls (creating the cluster, node group, addons) all worked fine regardless, but the
  # first thing that talks to the actual Kubernetes API server (helm_release.argocd, below) was
  # rejected outright. Confirmed directly: "Kubernetes cluster unreachable: the server has asked
  # for the client to provide credentials." This creates an EKS access entry granting that
  # identity cluster-admin, which is additive — safe to apply after the cluster already exists.
  enable_cluster_creator_admin_permissions = true

  # aws-ebs-csi-driver is deliberately NOT listed here: it needs the IRSA role below, which in
  # turn needs this cluster's own OIDC provider — passing it through cluster_addons would create
  # a module-to-module cycle (eks -> ebs_csi_irsa -> eks). Defined as a standalone aws_eks_addon
  # resource instead, which can depend on both modules without either module depending on the
  # other.
  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  eks_managed_node_groups = {
    default = {
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      instance_types = var.node_instance_types
      # Spot, not On-Demand: real cost savings (typically 60-70% off) and real Spot-handling
      # experience for the resume, accepted here because the workload (a demo API + a static
      # frontend) tolerates a brief pod reschedule on interruption without any user-facing impact.
      capacity_type = "SPOT"

      labels = {
        "node-lifecycle" = "spot"
      }
    }
  }

  tags = var.tags
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.48"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn

  # Node group must exist before the driver's daemonset can schedule.
  depends_on = [module.eks]
}
