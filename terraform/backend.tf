# backend.tf
# WHERE Terraform stores its "state file". State is Terraform's memory: a JSON
# record mapping your .tf resources to the real AWS resource IDs it created.
# Terraform reads state to know what already exists and what to change.
#
# By DEFAULT (with everything below commented out) state is stored LOCALLY in
# a file called `terraform.tfstate` in this folder. That is fine for learning
# solo, but has two problems for teams/CI:
#   1. The file lives on one laptop — teammates/CI can't see it.
#   2. Two people running apply at once can corrupt it (no locking).
#
# The PRODUCTION answer is a REMOTE backend: an S3 bucket for the state file
# plus a DynamoDB table for a lock. Uncomment and fill in real names to use it.
# NOTE: the S3 bucket + DynamoDB table must ALREADY EXIST before `init`
# (bootstrap them once by hand or with a separate tiny Terraform project).

# terraform {
#   backend "s3" {
#     bucket         = "my-unique-tfstate-bucket-name"   # must be globally unique
#     key            = "two-tier-demo/terraform.tfstate" # path within the bucket
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"                 # provides state locking
#     encrypt        = true                              # encrypt state at rest
#   }
# }
