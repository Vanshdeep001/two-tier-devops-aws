# Kubernetes — Application Manifests

These YAML files tell Kubernetes how to run the two-tier app: how many copies,
how to configure them, how to health-check them, and how to expose them. Every
object lives in the `two-tier` namespace.

---

## File-by-file: what each file does

| File | Kubernetes object | Role |
|------|-------------------|------|
| `namespace.yaml` | Namespace | Virtual folder that groups all app objects. |
| `configmap.yaml` | ConfigMap | Non-secret config (message, ports, backend URL). |
| `secret.yaml` | Secret | Placeholder for sensitive values (e.g. future DB string). |
| `backend-deployment.yaml` | Deployment | Runs 2 backend pods with probes + limits + rolling updates. |
| `backend-service.yaml` | Service (ClusterIP) | Stable internal DNS for the backend; not exposed publicly. |
| `frontend-deployment.yaml` | Deployment | Runs 2 frontend (Nginx) pods. |
| `frontend-service.yaml` | Service (NodePort) | Exposes the frontend on the node's IP at port 30080. |
| `ingress.yaml` | Ingress | Optional clean routing on port 80 via k3s's built-in Traefik. |

---

## Key concepts, explained

- **Deployment → ReplicaSet → Pods.** You edit the Deployment; it creates a
  ReplicaSet; the ReplicaSet keeps the right number of Pods alive. You almost
  never create Pods or ReplicaSets directly.
- **Liveness vs Readiness probe.**
  - *Liveness* (`/health`): if it fails, Kubernetes **restarts** the container.
  - *Readiness* (`/ready`): if it fails, the pod is **removed from the Service**
    (no traffic) but not restarted. Prevents sending traffic to a booting pod.
- **Requests vs Limits.**
  - *Request*: guaranteed reservation used to **schedule** the pod onto a node.
  - *Limit*: hard ceiling. Exceed the **memory** limit → the container is killed
    (OOMKilled). Exceed **CPU** → it's throttled, not killed.
- **Rolling update.** Changing the image triggers a gradual replacement:
  `maxUnavailable: 0` keeps full capacity, `maxSurge: 1` adds one new pod at a
  time. Zero downtime, and you can `kubectl rollout undo` to roll back.
- **imagePullPolicy: IfNotPresent.** Reuse a cached image if the tag exists.
  Safe because we use **unique Git-SHA tags** (never `:latest`), so a given tag
  always means the same image.
- **ClusterIP vs NodePort vs LoadBalancer.**
  - *ClusterIP* (backend): internal only — most secure default.
  - *NodePort* (frontend): opens a port on the node's public IP. **Free** — our
    choice for Free-Tier k3s.
  - *LoadBalancer*: provisions a real (paid) cloud load balancer. Use on EKS.

### Why avoid `:latest`?
`:latest` is a moving target — you can't tell which build is running, and pods
that restart may pull a *different* image than their siblings. Git-SHA tags make
every deploy specific, reproducible, and easy to roll back.

---

## Apply order + commands

The manifests are numbered logically; apply the whole folder at once:

```bash
# kubeconfig must point at the k3s node (copied from the EC2 instance).
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/            # applies everything else in the folder

# Watch the rollout:
kubectl -n two-tier get pods -w
# Expected: backend-xxxx and frontend-xxxx pods reach STATUS "Running", READY 1/1

kubectl -n two-tier get svc
# Expected: frontend-service shows 80:30080/TCP

# Reach the app (NodePort path):
curl http://<node-public-ip>:30080

# Roll back a bad deploy:
kubectl -n two-tier rollout undo deployment/backend
```

> Note: the deployment files ship with `REPLACE_WITH_*_IMAGE` placeholders. The
> CI pipeline substitutes the real ECR image + tag before applying. To apply by
> hand, replace those strings first (or use `kubectl set image`).

---

## Common mistakes
- **Selector/label mismatch** (`spec.selector` ≠ pod `labels`) → the Deployment
  manages zero pods, or the Service routes to nothing (`ENDPOINTS <none>`).
- **Probe path/port wrong** → pods restart-loop (liveness) or never become Ready
  (readiness). Check with `kubectl describe pod`.
- **Memory limit too low** → `OOMKilled`. Check `kubectl -n two-tier get pods`.
- **Using `:latest`** → non-reproducible deploys; hard to roll back.
- **Expecting NodePort traffic without opening the port** → the Security Group
  must allow 30080 (Terraform does this).

## Interview questions this folder can answer
- *Deployment vs ReplicaSet vs Pod?*
- *Difference between liveness and readiness probes — what does each failure do?*
- *requests vs limits, and what happens when you exceed each?*
- *How does a rolling update work and how do you roll back?*
- *ClusterIP vs NodePort vs LoadBalancer — when to use each on AWS?*
- *Why not use the `:latest` tag?*
