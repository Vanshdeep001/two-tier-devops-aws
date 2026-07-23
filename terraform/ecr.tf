# ecr.tf
# ECR (Elastic Container Registry) is AWS's private Docker image registry — like
# a private Docker Hub inside your account. CI pushes images here; the k3s node
# pulls from here. We create one repository per service.
#
# Cost note: ECR storage is charged per GB/month with a small Free Tier (500 MB
# for private repos, first 12 months). Keep only a few tags to stay in budget.

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}-frontend"
  image_tag_mutability = "MUTABLE" # allow re-tagging (e.g. moving :latest)

  # Scan images for known vulnerabilities on push — a basic DevSecOps control.
  image_scanning_configuration {
    scan_on_push = true
  }

  # force_delete lets `terraform destroy` remove the repo even if it still has
  # images. Convenient for a demo; be careful with this in real production.
  force_delete = true

  tags = { Name = "${var.project_name}-frontend" }
}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = { Name = "${var.project_name}-backend" }
}

# Lifecycle policy: automatically delete old, untagged images so storage stays
# small (and free). Keeps only the 5 most recent images per repo.
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 2 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 2
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 2 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 2
      }
      action = { type = "expire" }
    }]
  })
}
