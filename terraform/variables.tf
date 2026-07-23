# variables.tf
# Declares every INPUT the configuration accepts. Variables make the code
# reusable — the same code can deploy dev/prod by passing different values.
# Values come from (highest priority first): -var flags, *.auto.tfvars,
# terraform.tfvars, environment variables (TF_VAR_name), then the default here.

variable "aws_region" {
  description = "AWS region to deploy into. us-east-1 is the cheapest/most complete."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix and tag resources."
  type        = string
  default     = "two-tier-demo"
}

variable "environment" {
  description = "Environment name (dev/stage/prod). Used in tags."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "IP range for the whole VPC (private network in AWS)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per availability zone)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "EC2 size. t2.micro/t3.micro are Free Tier eligible (750 hrs/mo)."
  type        = string
  default     = "t2.micro" # 1 vCPU, 1 GB RAM — Free Tier
}

variable "ssh_allowed_cidr" {
  description = "Who may SSH to the node. CHANGE this to YOUR IP/32 for safety."
  type        = string
  default     = "0.0.0.0/0" # WARNING: open to the world; override in tfvars.
}

variable "app_node_port_frontend" {
  description = "NodePort the frontend Service is exposed on (30000-32767)."
  type        = number
  default     = 30080
}

variable "app_node_port_backend" {
  description = "NodePort the backend Service is exposed on (30000-32767)."
  type        = number
  default     = 30050
}

# --- EKS toggle -------------------------------------------------------------
# EKS is NOT Free Tier: the control plane costs ~$0.10/hour (~$73/month).
# We keep the EKS files in the repo for learning, but default them OFF so a
# plain `terraform apply` stays on the free EC2 + k3s path.
variable "enable_eks" {
  description = "Set true to ALSO create a managed EKS cluster (COSTS MONEY)."
  type        = bool
  default     = false
}

variable "eks_node_instance_type" {
  description = "Instance type for EKS managed node group (only if enable_eks)."
  type        = string
  default     = "t3.small"
}
