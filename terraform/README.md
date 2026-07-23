# Terraform — Infrastructure as Code

This folder provisions **all AWS infrastructure** with Terraform. The default
apply stays **Free-Tier-friendly**: one `t3.micro` EC2 instance running **k3s**
(real, lightweight Kubernetes), plus a VPC, ECR registries, and least-privilege
IAM. Managed **EKS** is included too but **disabled by default** because it
costs money.

---

## How Terraform works (the mental model)

1. You **describe** the desired infrastructure in `.tf` files (declarative — you
   say *what* you want, not *how*).
2. `terraform plan` compares your files to the **state file** (Terraform's record
   of what already exists) and shows the diff.
3. `terraform apply` calls the AWS API to make reality match your files, then
   updates the state file.
4. `terraform destroy` deletes everything in the state file.

**State** is the key concept: `terraform.tfstate` maps each resource block (e.g.
`aws_instance.node`) to a real AWS ID (e.g. `i-0abc123`). That's how Terraform
knows the instance already exists and shouldn't be recreated. See `backend.tf`
for local vs. remote (S3) state.

---

## File-by-file: what each file does

| File | Role |
|------|------|
| `versions.tf` | Pins Terraform + provider versions for reproducible builds. |
| `provider.tf` | Configures the AWS provider (region, default tags). No secrets. |
| `variables.tf` | Declares all inputs (region, instance type, ports, `enable_eks`). |
| `terraform.tfvars.example` | Template of values to override defaults. Copy to `terraform.tfvars`. |
| `backend.tf` | Explains + optionally configures remote state (S3 + DynamoDB lock). |
| `main.tf` | Shared data sources (AZs, latest Ubuntu AMI) and `locals`. |
| `vpc.tf` | Network: VPC, public subnets, internet gateway, route table. |
| `security-group.tf` | Firewall rules (SSH, HTTP, NodePorts). Least privilege. |
| `iam.tf` | IAM role + instance profile so EC2 can pull from ECR (no keys). |
| `ecr.tf` | Two private image registries (frontend/backend) + cleanup rules. |
| `ec2.tf` | The k3s node, SSH key generation, and a static Elastic IP. |
| `scripts/k3s-install.sh.tpl` | Boot script that installs k3s + AWS CLI on the node. |
| `eks.tf` | OPTIONAL managed EKS control plane (off unless `enable_eks=true`). |
| `node-group.tf` | OPTIONAL EKS worker nodes (off unless `enable_eks=true`). |
| `outputs.tf` | Prints IP, SSH command, app URL, ECR URLs after apply. |

---

## Why each AWS resource exists

| Resource | Why it exists |
|----------|---------------|
| **VPC** | Your own isolated private network; everything else lives inside it. |
| **Public subnets** (x2) | Slices of the VPC in different AZs; where the EC2 runs. |
| **Internet Gateway** | The door to the internet — needed to pull images & serve traffic. |
| **Route table** | Sends "to anywhere" traffic to the internet gateway. |
| **Security group** | Firewall; opens only SSH/HTTP/NodePorts. |
| **IAM role + instance profile** | Lets the node pull ECR images with temporary creds — no static keys. |
| **ECR repos** | Private Docker registry CI pushes to and the node pulls from. |
| **EC2 (t3.micro)** | The compute that runs the k3s Kubernetes cluster. Free Tier. |
| **Elastic IP** | Stable public address that survives reboots. |
| **EKS / node group** | Optional managed Kubernetes for learning; costs money. |

---

## Commands + expected output

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit ssh_allowed_cidr!

terraform init      # downloads providers, sets up backend
# Expected: "Terraform has been successfully initialized!"

terraform plan      # preview
# Expected: "Plan: N to add, 0 to change, 0 to destroy."

terraform apply     # type "yes" to confirm
# Expected: "Apply complete! Resources: N added..." then the outputs:
#   node_public_ip = "x.x.x.x"
#   frontend_url   = "http://x.x.x.x:30080"
#   ssh_command    = "ssh -i two-tier-demo-dev-key.pem ubuntu@x.x.x.x"

terraform output    # reprint outputs anytime

terraform destroy   # tear everything down (type "yes")
# Expected: "Destroy complete! Resources: N destroyed."
```

The node needs ~2–3 minutes after apply for the boot script to finish installing
k3s. SSH in and run `sudo k3s kubectl get nodes` — it should show `Ready`.

---

## State management (short version)
- **Local (default):** `terraform.tfstate` in this folder. Fine for one person.
- **Remote (production):** S3 bucket for the file + DynamoDB table for locking so
  two applies can't corrupt it. Uncomment the block in `backend.tf`.
- **Never edit the state file by hand**, and **never commit it** (it can contain
  secrets). It's git-ignored.

## Common mistakes
- **Leaving `ssh_allowed_cidr = 0.0.0.0/0`** → SSH open to the whole internet.
  Set it to `YOUR_IP/32`.
- **Committing `terraform.tfstate` or the `.pem` key** → secret leak. Both are
  git-ignored here.
- **Turning on `enable_eks` and forgetting it** → surprise ~$73/month bill.
- **Running `apply` in the wrong region** → resources scattered; check `aws_region`.
- **Hardcoding an AMI id** → breaks in other regions. We use a data source.

## Interview questions this folder can answer
- *What is Terraform state and why does it matter?* It maps config to real
  resources; without it Terraform can't tell create from update from delete.
- *Local vs remote state?* Remote (S3+DynamoDB) enables team collaboration and
  locking.
- *What's the difference between a provider and a resource?* A provider is the
  plugin that talks to an API (AWS); a resource is one thing it manages (a VPC).
- *Why an IAM role instead of access keys on the instance?* Roles give rotating
  temporary credentials — no long-lived secrets to leak.
- *`terraform plan` vs `apply`?* Plan previews the diff; apply executes it.
