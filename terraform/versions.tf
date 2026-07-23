# versions.tf
# Pins the Terraform CLI version and the provider versions. Pinning makes builds
# reproducible: everyone on the team (and CI) uses compatible versions instead
# of whatever happens to be installed.

terraform {
  # Require Terraform 1.5 or newer (but below 2.0).
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    # The AWS provider is the plugin that knows how to talk to the AWS API.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # any 5.x
    }
    # Used to generate an SSH key pair for the EC2 instance.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # Writes the generated private key to a local file.
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}
