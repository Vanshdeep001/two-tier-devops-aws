# security-group.tf
# A Security Group is a stateful virtual firewall attached to an instance. It
# controls which traffic is allowed IN (ingress) and OUT (egress). "Stateful"
# means if you allow a request in, the response is automatically allowed out.
#
# We open only the ports we actually need — the principle of least privilege.

resource "aws_security_group" "node" {
  name        = "${local.name_prefix}-node-sg"
  description = "Firewall for the k3s EC2 node"
  vpc_id      = aws_vpc.main.id

  # SSH so you can log in to debug. Restrict this to YOUR IP in tfvars!
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # HTTP for the ingress/load balancer path (port 80).
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes NodePort range access for the frontend NodePort Service.
  ingress {
    description = "Frontend NodePort"
    from_port   = var.app_node_port_frontend
    to_port     = var.app_node_port_frontend
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort for the backend (handy for direct debugging; optional).
  ingress {
    description = "Backend NodePort"
    from_port   = var.app_node_port_backend
    to_port     = var.app_node_port_backend
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: allow all outbound so the node can pull images, updates, etc.
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 = every protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-node-sg" }
}
