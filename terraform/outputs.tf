# outputs.tf
# OUTPUTS are values Terraform prints after apply (and stores in state). They are
# how you get useful info back out — IP addresses, URLs, registry paths — and how
# other tools/CI read what Terraform created.

output "node_public_ip" {
  description = "Elastic IP of the k3s node. SSH and app access use this."
  value       = aws_eip.node.public_ip
}

output "ssh_command" {
  description = "Ready-to-paste SSH command."
  value       = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_eip.node.public_ip}"
}

output "frontend_url" {
  description = "Where the app is reachable (NodePort on the node's public IP)."
  value       = "http://${aws_eip.node.public_ip}:${var.app_node_port_frontend}"
}

output "ecr_frontend_repo_url" {
  description = "Push/pull URL for the frontend image."
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_repo_url" {
  description = "Push/pull URL for the backend image."
  value       = aws_ecr_repository.backend.repository_url
}

# Only meaningful when enable_eks = true. try() keeps output empty otherwise.
output "eks_cluster_name" {
  description = "EKS cluster name (empty unless enable_eks = true)."
  value       = try(aws_eks_cluster.main[0].name, "")
}
