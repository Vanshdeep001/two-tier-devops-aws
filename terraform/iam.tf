# iam.tf
# IAM (Identity and Access Management) controls WHO can do WHAT in AWS.
# Here we give the EC2 node an IAM ROLE so it can pull Docker images from ECR
# WITHOUT us putting any AWS keys on the box. The node "assumes" the role and
# gets temporary credentials automatically. This is the secure, key-less way.

# Trust policy: says "the EC2 service is allowed to assume this role."
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# The role itself.
resource "aws_iam_role" "node" {
  name               = "${local.name_prefix}-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { Name = "${local.name_prefix}-node-role" }
}

# Attach the AWS-managed READ-ONLY ECR policy. Read-only = least privilege: the
# node can PULL images but cannot push or delete them.
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# An instance profile is the wrapper that actually lets an EC2 instance use a
# role. You attach the instance profile (not the role directly) to the EC2.
resource "aws_iam_instance_profile" "node" {
  name = "${local.name_prefix}-node-profile"
  role = aws_iam_role.node.name
}
