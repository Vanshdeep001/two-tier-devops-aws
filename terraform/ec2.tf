# ec2.tf
# The compute: a single EC2 instance (t3.micro = Free Tier) that runs k3s, a
# lightweight certified Kubernetes distribution. This is our Free-Tier-friendly
# "cluster" — real Kubernetes, one node, ~$0 if you stay within Free Tier hours.
#
# It also: generates an SSH key, gives the node the IAM profile (for ECR), and
# attaches a stable Elastic IP so the address doesn't change on reboot.

# --- SSH key pair -----------------------------------------------------------
# Generate a private key locally with the TLS provider...
resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ...register the PUBLIC half with AWS as an EC2 key pair (for SSH login)...
resource "aws_key_pair" "node" {
  key_name   = "${local.name_prefix}-key"
  public_key = tls_private_key.node.public_key_openssh
}

# ...and save the PRIVATE half to a file so you can `ssh -i` into the box.
# chmod 0600 because SSH refuses to use a world-readable key.
resource "local_file" "private_key" {
  content         = tls_private_key.node.private_key_pem
  filename        = "${path.module}/${local.name_prefix}-key.pem"
  file_permission = "0600"
}

# --- The instance -----------------------------------------------------------
resource "aws_instance" "node" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.node.id]
  key_name               = aws_key_pair.node.key_name
  iam_instance_profile   = aws_iam_instance_profile.node.name

  # user_data is a startup script AWS runs ONCE on first boot. We use it to
  # install k3s automatically. templatefile() injects variables into the script.
  user_data = templatefile("${path.module}/scripts/k3s-install.sh.tpl", {
    node_port_frontend = var.app_node_port_frontend
  })

  # Free Tier gives 30 GB of gp3 storage; 20 GB is plenty for this demo.
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${local.name_prefix}-k3s-node" }
}

# --- Elastic IP -------------------------------------------------------------
# A static public IP. Normal public IPs change when an instance stops/starts;
# an EIP stays constant, which is nicer for DNS and kubeconfig.
# COST NOTE: an EIP is free ONLY while attached to a RUNNING instance. If you
# stop the instance or leave the EIP unattached, AWS charges a small hourly fee.
resource "aws_eip" "node" {
  instance = aws_instance.node.id
  domain   = "vpc"
  tags     = { Name = "${local.name_prefix}-eip" }
}
