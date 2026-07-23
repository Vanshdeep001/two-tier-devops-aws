# main.tf
# A home for shared data sources and "locals" (computed values used elsewhere).
# There is nothing special about the name main.tf — Terraform loads ALL *.tf
# files in this folder and treats them as one configuration.

# Look up the Availability Zones available in the chosen region at plan time.
# We spread subnets across AZs for a more realistic (highly-available) layout.
data "aws_availability_zones" "available" {
  state = "available"
}

# Find the latest Ubuntu 22.04 AMI owned by Canonical. Using a data source (not
# a hardcoded AMI id) means the config keeps working across regions and updates.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# locals = named values computed once and reused. Keeps names consistent.
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
