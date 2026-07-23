# Two-Tier DevOps Project — React + Node.js on Kubernetes (AWS Free Tier)

A complete, production-*shaped* DevOps project you can clone, understand, and
deploy end to end. It uses **React** (frontend), **Node.js/Express** (backend),
**Docker**, **Kubernetes (k3s)**, **Terraform**, **GitHub Actions**, and **AWS**
— structured like an enterprise repo, and built to stay on the **AWS Free Tier**
wherever possible.

> Every folder has its own README explaining each file, common mistakes, and
> interview questions. Start here for the big picture, then dive into a folder.

---

## Table of contents
1. [What you'll build](#what-youll-build)
2. [Architecture diagram](#architecture-diagram)
3. [Networking diagram](#networking-diagram)
4. [Request flow](#request-flow)
5. [CI/CD pipeline diagram](#cicd-pipeline-diagram)
6. [Folder structure](#folder-structure)
7. [Which Kubernetes? kubeadm vs k3s vs EKS](#which-kubernetes-kubeadm-vs-k3s-vs-eks)
8. [Prerequisites](#prerequisites)
9. [Deploy from scratch — step by step](#deploy-from-scratch--step-by-step)
10. [Security (DevSecOps)](#security-devsecops)
11. [Cost & Free Tier limitations](#cost--free-tier-limitations)
12. [Common errors & debugging](#common-errors--debugging)
13. [Cleanup](#cleanup)
14. [Interview prep index](#interview-prep-index)

---

## What you'll build

A two-tier web app:
- **Tier 1 — Frontend:** React app, built to static files, served by **Nginx**,
  which also reverse-proxies `/api` to the backend (so there's no CORS and the
  backend stays private).
- **Tier 2 — Backend:** Node.js/Express REST API returning JSON. Stateless, with
  `/health` and `/ready` probes. No database yet, but structured to add MongoDB.

Both run as **containers** on a **single-node k3s Kubernetes cluster** on one
**EC2 t3.micro** (Free Tier), provisioned by **Terraform**, with images stored
in **ECR** and shipped by a **GitHub Actions** pipeline.

---

## Architecture diagram

```
                                 ┌─────────────────────────────────────────┐
   Developer                     │                 AWS Cloud                │
      │ git push main            │                                         │
      ▼                          │   ┌───────────────── VPC 10.0.0.0/16 ──┐ │
┌──────────────┐   build+push    │   │            Public Subnet           │ │
│GitHub Actions│──────────────────────▶  ┌────────────────────────────┐   │ │
│  CI/CD       │   images (SHA)  │   │   │   EC2 t3.micro (Ubuntu)    │   │ │
└──────┬───────┘                 │   │   │   ┌────── k3s cluster ────┐ │   │ │
       │ ssh deploy              │   │   │   │  ns: two-tier         │ │   │ │
       │                         │   │   │   │  ┌─────────┐ ┌──────┐ │ │   │ │
       ▼                         │   │   │   │  │frontend │ │backend│ │ │   │ │
┌──────────────┐   pull images   │   │   │   │  │ x2 pods │ │x2 pods│ │ │   │ │
│  Amazon ECR  │◀─────────────────────────  │  │(Nginx)  │→│Express│ │ │   │ │
│ 2 repos      │                 │   │   │   │  └────┬────┘ └──────┘ │ │   │ │
└──────────────┘                 │   │   │   │  NodePort 30080       │ │   │ │
                                 │   │   │   └───────────────────────┘ │   │ │
   End user  ───── HTTP :30080 ──────────────▶ Elastic IP ────────────┘   │ │
   (browser)                     │   │   └────────────────────────────────┘ │
                                 │   └─────── Internet Gateway ──────────────┘
                                 └─────────────────────────────────────────┘
```

---

## Networking diagram

```
Internet
   │
   ▼
Internet Gateway (igw)
   │                         route table: 0.0.0.0/0 → igw
   ▼
VPC 10.0.0.0/16
   └── Public Subnet 10.0.1.0/24  (AZ a)  ◀── EC2 node lives here
   └── Public Subnet 10.0.2.0/24  (AZ b)  (spare / for EKS HA)
          │
          ▼
   Security Group (stateful firewall)
     ingress: 22 (SSH, your IP)  |  80 (HTTP)  |  30080 (frontend NodePort)  |  30050 (backend NodePort)
     egress : all (pull images, updates)
          │
          ▼
   EC2 t3.micro  ── Elastic IP (stable public address)
     └── k3s (Traefik ingress built in)
           ├── frontend-service  NodePort  :30080 → pods :80
           └── backend-service   ClusterIP :5000  (internal only)
```

Inside the cluster, pods find each other by **Service DNS name**
(`backend-service.two-tier.svc`), not IP — Services are stable, pods are not.

---

## Request flow

```
User types http://<elastic-ip>:30080
        │
        ▼
NodePort 30080 on the EC2 node
        │  (kube-proxy load-balances)
        ▼
frontend-service ──▶ one of the frontend (Nginx) pods
        │
        ├── path "/"      → Nginx serves the static React files (index.html, JS)
        │
        └── path "/api/*" → Nginx reverse-proxies to  backend-service:5000
                                   │  (ClusterIP, internal)
                                   ▼
                            one of the backend (Express) pods
                                   │
                                   ▼
                            JSON response ──▶ back up the same chain ──▶ browser
```

Because Nginx proxies `/api`, the **browser only ever talks to one origin** — no
CORS, and the backend is never exposed to the internet.

---

## CI/CD pipeline diagram

```
 git push origin main
        │
        ▼
 ┌───────────────────────────── GitHub Actions ─────────────────────────────┐
 │                                                                            │
 │  [test]  ───▶  [build-and-push]  ───▶  [deploy]                            │
 │   FE+BE         docker build           scp k8s/ to node                    │
 │   npm test      tag = git SHA          ssh: refresh ECR pull-secret        │
 │                 push → ECR             sed image tags → kubectl apply      │
 │                                        kubectl rollout status (verify)     │
 └────────────────────────────────────────────────────────────────────────────┘
        │                     │                          │
        ▼                     ▼                          ▼
   fail fast if         Amazon ECR                 k3s on EC2
   a test fails       (immutable SHA tags)      rolling update, zero downtime
```

---

## Folder structure

```
Devops/
├── README.md                 ← you are here (big picture + full runbook)
├── .gitignore                ← keeps secrets/state/node_modules out of git
│
├── backend/                  ← Node.js + Express REST API  (has its own README)
│   ├── src/
│   │   ├── server.js         ← starts the HTTP server
│   │   ├── app.js            ← builds the Express app (middleware + routes)
│   │   ├── routes/           ← URL maps (health.js, api.js)
│   │   └── controllers/      ← the logic (healthController.js, messageController.js)
│   ├── tests/                ← Jest + Supertest tests
│   ├── Dockerfile            ← multi-stage, non-root production image
│   ├── .dockerignore
│   └── .env.example
│
├── frontend/                 ← React app served by Nginx  (has its own README)
│   ├── public/index.html
│   ├── src/                  ← App.js, api.js (axios), styles, tests
│   ├── nginx.conf            ← serve static + proxy /api
│   ├── Dockerfile            ← build React, then serve with Nginx
│   ├── .dockerignore
│   └── .env.example
│
├── terraform/                ← all AWS infrastructure  (has its own README)
│   ├── versions.tf provider.tf variables.tf backend.tf main.tf
│   ├── vpc.tf security-group.tf iam.tf ecr.tf ec2.tf
│   ├── eks.tf node-group.tf   ← optional managed EKS (off by default, costs $)
│   ├── outputs.tf
│   ├── scripts/k3s-install.sh.tpl
│   └── terraform.tfvars.example
│
├── k8s/                      ← Kubernetes manifests  (has its own README)
│   ├── namespace.yaml configmap.yaml secret.yaml
│   ├── backend-deployment.yaml  backend-service.yaml
│   ├── frontend-deployment.yaml frontend-service.yaml
│   └── ingress.yaml
│
└── .github/workflows/        ← CI/CD  (has its own README)
    └── deploy.yml
```

---

## Which Kubernetes? kubeadm vs k3s vs EKS

| Option | What it is | Cost on AWS | Setup effort | Best for |
|--------|-----------|-------------|--------------|----------|
| **kubeadm** | The "official" DIY way to build a cluster on EC2 by hand. | EC2 only (Free Tier possible, but needs ~2 GB RAM → often > t3.micro). | High (you wire up networking, etcd, etc.). | Understanding K8s internals deeply. |
| **k3s** ✅ | Lightweight, fully-certified K8s in a single binary. Bundles containerd + Traefik. Runs on a t3.micro. | **EC2 only — Free-Tier friendly.** | **Low** (one `curl | sh`). | **Learning + this project.** Real Kubernetes, minimal cost. |
| **EKS** | AWS-managed control plane. Production standard. | **~$73/month** control plane **+** worker EC2s. **Not Free Tier.** | Medium (managed, but more moving parts). | Real production / resume keyword. |

**Recommendation:** use **k3s on one EC2 t3.micro** (this repo's default). You get
genuine Kubernetes (Deployments, Services, probes, rolling updates, Ingress) at
essentially zero cost. The repo **also includes EKS Terraform** (`eks.tf`,
`node-group.tf`), disabled behind `enable_eks = false`, so you can flip it on
later to learn EKS when you're ready to pay for it.

- *Should Kubernetes run on EC2?* Yes — k3s does exactly that here.
- *kubeadm?* Great for learning internals but heavier than a t3.micro likes.
- *k3s?* Best learning/cost trade-off — **our pick**.
- *EKS?* Best for production, but exceeds Free Tier — included but off by default.

---

## Prerequisites

Install locally:
- **AWS account** + an IAM user with programmatic access.
- **AWS CLI** (`aws configure` with your keys).
- **Terraform** ≥ 1.5.
- **kubectl**.
- **Docker** (for local image builds/testing).
- **Node.js 18+** (for local app dev).
- **Git** + a **GitHub** repo (for CI/CD).

---

## Deploy from scratch — step by step

### 0) Clone & explore
```bash
git clone <your-repo-url> devops && cd devops
```

### 1) Run the app locally (optional sanity check)
```bash
# Backend
cd backend && npm install && npm start        # http://localhost:5000/health
# Frontend (new terminal)
cd frontend && npm install && npm start        # http://localhost:3000
```
Expected: the React page shows the greeting from the backend.

### 2) Provision infrastructure with Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
#   → edit ssh_allowed_cidr to YOUR_IP/32  (curl ifconfig.me)

terraform init      # Expected: "Terraform has been successfully initialized!"
terraform plan      # Expected: "Plan: N to add, 0 to change, 0 to destroy."
terraform apply     # type yes
```
Expected outputs:
```
node_public_ip = "x.x.x.x"
frontend_url   = "http://x.x.x.x:30080"
ssh_command    = "ssh -i two-tier-demo-dev-key.pem ubuntu@x.x.x.x"
ecr_backend_repo_url  = "<acct>.dkr.ecr.us-east-1.amazonaws.com/two-tier-demo-backend"
ecr_frontend_repo_url = "<acct>.dkr.ecr.us-east-1.amazonaws.com/two-tier-demo-frontend"
```
Wait ~2–3 min, then confirm k3s is up:
```bash
ssh -i two-tier-demo-dev-key.pem ubuntu@x.x.x.x 'sudo k3s kubectl get nodes'
# Expected: STATUS = Ready
```

### 3) Configure GitHub Secrets
In your repo: **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Your CI IAM user's keys. |
| `AWS_REGION` | e.g. `us-east-1`. |
| `EC2_HOST` | The `node_public_ip` from Terraform. |
| `EC2_USER` | `ubuntu`. |
| `EC2_SSH_KEY` | Full contents of `terraform/two-tier-demo-dev-key.pem`. |

(See `.github/workflows/README.md` for where each value comes from.)

### 4) Trigger the pipeline
```bash
git add . && git commit -m "deploy" && git push origin main
```
Watch **Actions** tab. Expected: `test` → `build-and-push` → `deploy` all green,
ending with `rollout status ... successfully rolled out`.

### 5) Verify
```bash
curl http://<node-public-ip>:30080/            # the React HTML
curl http://<node-public-ip>:30080/api/message # {"message":"..."}
curl http://<node-public-ip>:30080/api/info    # {"hostname":"backend-...","version":"<sha>"}
```
Open `http://<node-public-ip>:30080` in a browser. Refresh a few times — the
`Served by pod` value changes, proving load balancing across replicas.

---

## Security (DevSecOps)

- **No hardcoded secrets.** App config comes from env vars / ConfigMaps; secrets
  from GitHub Secrets and Kubernetes Secrets. `.gitignore` blocks `.env`,
  `*.tfstate`, and `*.pem`.
- **Least-privilege IAM.** The node gets **read-only** ECR access via an IAM
  **role** (temporary creds, no keys on the box). The CI user only needs ECR
  push/pull.
- **Tight Security Groups.** Only SSH (ideally your IP), HTTP, and the app
  NodePorts are open.
- **Non-root containers.** The backend runs as `USER node`.
- **Image scanning.** ECR `scan_on_push` flags known CVEs.
- **Private backend.** Backend is `ClusterIP` — never directly internet-facing.
- **Immutable image tags.** Git-SHA tags (not `:latest`) → traceable, rollbackable.

> Note on Kubernetes Secrets: by default they're only **base64-encoded**, not
> encrypted. For real workloads, enable encryption at rest and/or use AWS Secrets
> Manager or Sealed Secrets. `k8s/secret.yaml` explains this and ships a fake value.

---

## Cost & Free Tier limitations

**Designed to be ~$0/month** within the 12-month Free Tier, *if you stay inside
the limits and clean up*:

| Resource | Free Tier | Watch out for |
|----------|-----------|---------------|
| EC2 t3.micro/t2.micro | 750 hrs/month (1 instance 24/7) | A 2nd instance, or a bigger type, bills immediately. |
| EBS storage | 30 GB gp3 | We use 20 GB. Extra volumes/snapshots cost. |
| Elastic IP | Free **while attached to a running instance** | Stopping the instance or an unattached EIP is billed hourly. |
| ECR | 500 MB private storage (12 mo) | Old images add up — lifecycle policy keeps only 5. |
| Data transfer | 100 GB/mo out (varies) | Big egress costs money. |
| **EKS** | **Not free** (~$73/mo control plane) | `enable_eks` is **off** by default. |
| **LoadBalancer Service / ALB** | **Not free** | We use **NodePort** instead. |

**Golden rule:** run `terraform destroy` when you're done for the day/week. And
set an **AWS Budget alert** ($1–$5) so a surprise never grows.

---

## Common errors & debugging

| Symptom | Likely cause | Fix / command |
|---------|-------------|---------------|
| `terraform apply` auth error | AWS creds not set | `aws configure` or export `AWS_ACCESS_KEY_ID/SECRET`. |
| Node not `Ready` after apply | k3s still installing | Wait 2–3 min; `ssh ... 'sudo cat /var/log/cloud-init-output.log'`. |
| CI `deploy` SSH timeout | Port 22 blocked / wrong key | Widen `ssh_allowed_cidr`; ensure full `.pem` in `EC2_SSH_KEY`. |
| Pods `ImagePullBackOff` | ECR pull-secret missing/expired | Re-run deploy (refreshes `ecr-cred`); check `kubectl -n two-tier describe pod`. |
| Pods `CrashLoopBackOff` | App error or bad probe | `kubectl -n two-tier logs <pod>`; `kubectl describe pod`. |
| Pods `Pending` | Not enough CPU/RAM on t3.micro | Lower `replicas` or resource requests. |
| `curl :30080` refused | SG not open / wrong port | Check Security Group + `kubectl get svc`. |
| Service has `ENDPOINTS <none>` | Selector ≠ pod labels | Align `spec.selector` with pod `labels`. |
| Browser shows "can't reach backend" | CORS or wrong API URL | We proxy `/api` via Nginx — confirm `BACKEND_URL` ConfigMap. |

Handy debugging commands:
```bash
kubectl -n two-tier get pods -o wide
kubectl -n two-tier describe pod <pod>
kubectl -n two-tier logs <pod> -f
kubectl -n two-tier get svc,ep
kubectl -n two-tier rollout status deployment/backend
kubectl -n two-tier rollout undo deployment/backend   # roll back
```

---

## Cleanup

**Always tear down to avoid charges:**
```bash
cd terraform
terraform destroy      # type yes
# Expected: "Destroy complete! Resources: N destroyed."
```
This removes EC2, EIP, VPC, IAM, and ECR (thanks to `force_delete`). Also delete
any GitHub Secrets you no longer need, and rotate the CI AWS keys if this was a
throwaway.

---

## Interview prep index

Each folder README ends with targeted interview questions. Quick map:
- **Docker / images / non-root / multi-stage** → `backend/README.md`,
  `frontend/README.md`.
- **React build-time env vars, reverse proxy, CORS** → `frontend/README.md`.
- **Terraform state, providers vs resources, IAM roles** → `terraform/README.md`.
- **Probes, requests/limits, rolling updates, Service types** → `k8s/README.md`.
- **CI/CD gating, job outputs, SHA tags, deploy verification** →
  `.github/workflows/README.md`.

---

Built as a learning-grade but production-shaped reference. Clone it, break it,
fix it — that's the fastest way to actually learn DevOps.
