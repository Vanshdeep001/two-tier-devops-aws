# node-group.tf
# OPTIONAL worker nodes for the EKS cluster above. Also gated by enable_eks, so
# it creates nothing unless you explicitly opt in. EKS worker nodes are normal
# EC2 instances — you pay for them on top of the control plane.

# --- IAM role the worker nodes use ------------------------------------------
data "aws_iam_policy_document" "eks_node_assume" {
  count = var.enable_eks ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  count              = var.enable_eks ? 1 : 0
  name               = "${local.name_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume[0].json
}

# Worker nodes need these three AWS-managed policies to join the cluster,
# configure pod networking, and pull images from ECR.
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  count      = var.enable_eks ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cni" {
  count      = var.enable_eks ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  count      = var.enable_eks ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- The managed node group -------------------------------------------------
resource "aws_eks_node_group" "main" {
  count           = var.enable_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${local.name_prefix}-ng"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = aws_subnet.public[*].id
  instance_types  = [var.eks_node_instance_type]

  # Auto-scaling bounds. Kept tiny to limit cost.
  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_node_ecr,
  ]
}
