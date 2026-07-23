# GitHub Actions — CI/CD Pipeline

`deploy.yml` is the automated pipeline. Push to `main` → it tests, builds &
pushes images to ECR, and deploys to the k3s node. This README explains every
job, step, Action, and secret.

---

## Pipeline flow

```
push to main
    │
    ▼
┌─────────┐   needs   ┌───────────────┐   needs   ┌─────────┐
│  test   │ ────────▶ │ build-and-push│ ────────▶ │ deploy  │
│ FE + BE │           │  → ECR (SHA)  │           │ → k3s   │
└─────────┘           └───────────────┘           └─────────┘
```

`needs:` makes jobs run in order and **stops the pipeline** if an earlier job
fails (no broken image ever reaches the cluster).

---

## Job 1 — `test`
Runs the automated tests first so we fail fast.

| Step | Action used | What it does |
|------|-------------|--------------|
| Checkout code | `actions/checkout@v4` | Pulls your repo onto the runner. |
| Setup Node.js | `actions/setup-node@v4` | Installs Node 18. |
| Test backend | (shell) | `npm ci && npm test` in `backend/` (Jest). |
| Test frontend | (shell) | `npm ci && npm test` in `frontend/` (React tests). |

## Job 2 — `build-and-push`
Builds both Docker images and pushes them to ECR, tagged with the **Git SHA**
(`github.sha`) — never `:latest`, so every build is traceable and rollbackable.

| Step | Action used | What it does |
|------|-------------|--------------|
| Checkout code | `actions/checkout@v4` | Repo onto runner. |
| Configure AWS credentials | `aws-actions/configure-aws-credentials@v4` | Turns the stored AWS keys into an AWS session. |
| Login to ECR | `aws-actions/amazon-ecr-login@v2` | Docker-logs-in to your private registry; outputs its URL. |
| Compute image refs | (shell) | Builds the full `registry/repo:sha` strings and shares them as job **outputs**. |
| Build & push backend | (shell) | `docker build ./backend` then `docker push`. |
| Build & push frontend | (shell) | `docker build ./frontend` then `docker push`. |

## Job 3 — `deploy`
Ships the new images to the k3s node over SSH.

| Step | Action used | What it does |
|------|-------------|--------------|
| Checkout code | `actions/checkout@v4` | Needed to copy the k8s manifests. |
| Copy manifests to node | `appleboy/scp-action@v0.1.7` | SCPs `k8s/*` to the node. |
| Deploy to k3s | `appleboy/ssh-action@v1.0.3` | SSHes in, refreshes the ECR pull-secret, `sed`-replaces the image placeholders, `kubectl apply`s, stamps `APP_VERSION`, and **waits for `rollout status`** to verify success. |

The `rollout status ... --timeout` lines are the **verification**: if the new
pods don't become healthy, the command errors and the job goes red.

---

## Required GitHub Secrets

Add these under **Repo → Settings → Secrets and variables → Actions → New
repository secret**.

| Secret | What it is | Where it comes from |
|--------|-----------|---------------------|
| `AWS_ACCESS_KEY_ID` | AWS API key ID | IAM → Users → your CI user → *Security credentials* → *Create access key*. |
| `AWS_SECRET_ACCESS_KEY` | AWS API secret | Shown **once** when you create the access key above. |
| `AWS_REGION` | e.g. `us-east-1` | The region you deployed Terraform into. |
| `EC2_HOST` | Public IP/DNS of the k3s node | Terraform output `node_public_ip`. |
| `EC2_USER` | SSH username | `ubuntu` for the Ubuntu AMI. |
| `EC2_SSH_KEY` | The **private** SSH key (full `.pem` contents) | The `two-tier-demo-dev-key.pem` Terraform generated. Paste the whole file. |

> **Docker Hub alternative.** If you push to Docker Hub instead of ECR, you'd add
> `DOCKER_USERNAME` and `DOCKER_PASSWORD` (a Docker Hub *access token*, not your
> password) and swap the ECR-login step for `docker/login-action`.

### Least-privilege for the CI AWS user
Give the CI IAM user only what it needs: `AmazonEC2ContainerRegistryPowerUser`
(push/pull to ECR). It does **not** need admin. Terraform is run separately with
broader permissions (or locally), not by this deploy user.

---

## Why tag with the Git SHA (not `:latest`)?
- **Traceability:** the running image maps to an exact commit.
- **Rollbacks:** `kubectl rollout undo` (or redeploy an old SHA) just works.
- **Correctness:** `:latest` can point at different bytes over time; pods that
  restart might pull a *different* image than their siblings.

## Common mistakes
- **Missing/typo'd secret** → step fails with an auth error. Double-check names.
- **`EC2_SSH_KEY` pasted partially** → SSH handshake fails. Paste the entire
  file including the BEGIN/END lines.
- **Security Group doesn't allow the runner's IP on port 22** → SSH times out.
  (This repo opens 22 to `ssh_allowed_cidr`; widen it or use a self-hosted
  runner if GitHub's IPs are blocked.)
- **ECR token expiry** → we refresh the `ecr-cred` secret every deploy, so this
  is handled.

## Interview questions this file can answer
- *What triggers a workflow and how do you gate jobs?* `on:` + `needs:`.
- *How do you pass data between jobs?* Job `outputs` (we share the image refs).
- *How do you authenticate to AWS from Actions securely?* Stored secrets or, even
  better, OIDC federation (no long-lived keys).
- *How do you verify a deployment succeeded in CI?* `kubectl rollout status`
  with a timeout fails the job if pods don't become healthy.
