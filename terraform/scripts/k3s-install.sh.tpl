#!/bin/bash
# k3s-install.sh.tpl
# Runs ONCE on first boot of the EC2 instance (via user_data). It installs k3s
# (lightweight Kubernetes) and prepares the node so our CI can deploy to it.
# Terraform fills in ${node_port_frontend} before this is uploaded.

set -euxo pipefail   # stop on error, print each command (goes to the boot log)

# Add a 2 GB swap file FIRST. A t3.micro has only 1 GB RAM, and k3s needs
# breathing room — without swap the API server thrashes and times out. Swap
# fixes that. We add it to /etc/fstab so it survives reboots.
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Install a couple of tools we'll want.
apt-get update -y
apt-get install -y curl unzip

# Install the AWS CLI v2 so the node can log in to ECR and pull private images.
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# Install k3s. --write-kubeconfig-mode 644 makes the kubeconfig readable so we
# can copy it out. k3s bundles containerd, a scheduler, and Traefik ingress.
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

# Wait for the Kubernetes API to be ready before continuing.
until k3s kubectl get nodes >/dev/null 2>&1; do
  echo "waiting for k3s to be ready..."
  sleep 5
done

# Make `kubectl` available to the default ubuntu user for manual debugging.
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

echo "k3s install complete. Frontend NodePort will be ${node_port_frontend}."
