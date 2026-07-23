# eks.tf
# OPTIONAL managed Kubernetes (EKS). This is here for LEARNING and to match a
# real enterprise repo — but it is DISABLED by default because it is NOT Free
# Tier: the EKS control plane costs ~$0.10/hour (~$73/month) whether or not you
# run workloads. Every resource below uses `count = var.enable_eks ? 1 : 0`, so
# a normal apply creates NONE of it. Set enable_eks = true only if you accept
# the cost. For Free Tier, stay on the EC2 + k3s path (ec2.tf).

# --- IAM role the EKS control plane assumes ---------------------------------
data "aws_iam_policy_document" "eks_assume" {
  count = var.enable_eks ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  count              = var.enable_eks ? 1 : 0
  name               = "${local.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume[0].json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.enable_eks ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- The EKS cluster (control plane) ----------------------------------------
resource "aws_eks_cluster" "main" {
  count    = var.enable_eks ? 1 : 0
  name     = "${local.name_prefix}-eks"
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = "1.30"

  vpc_config {
    # EKS spreads across the public subnets we already created.
    subnet_ids = aws_subnet.public[*].id
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}
