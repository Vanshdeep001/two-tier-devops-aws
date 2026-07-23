# provider.tf
# Configures the AWS provider — mainly WHICH region to deploy into. Credentials
# are NOT written here. The provider automatically picks them up from (in order):
#   1. Environment variables AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
#   2. Shared credentials file (~/.aws/credentials, set by `aws configure`)
#   3. An IAM role (when running on an EC2 instance or in CI with OIDC)
# Never hardcode secrets in .tf files — they'd end up in Git.

provider "aws" {
  region = var.aws_region

  # default_tags are applied to EVERY resource this provider creates. Great for
  # cost tracking and cleanup ("delete everything tagged Project=two-tier-demo").
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
