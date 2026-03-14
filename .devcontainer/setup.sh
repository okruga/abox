#!/bin/bash
set -euo pipefail

# Install OpenTofu
curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh -s -- --install-method standalone

# Install K9s
curl -sS https://webi.sh/k9s | sh

# Add aliases to bashrc
cat >> ~/.bashrc <<'EOF'

# k8sdiy-env aliases
alias kk="EDITOR='code --wait' k9s"
alias tf=tofu
alias k=kubectl
EOF

# Initialize Tofu
cd bootstrap
tofu init

# Apply if token is available
if [[ -n "${TF_VAR_github_token:-}" ]]; then
  tofu apply -auto-approve
else
  echo "WARNING: GITHUB_TOKEN secret not set — skipping tofu apply"
  echo "Set it via Codespace secrets and rebuild, or run: tofu apply"
fi

cd ..

# Install GatewayClass + Gateway
kubectl apply -f gatewayapi/

# Install cloud-provider-kind (LoadBalancer support)
ARCH=$(dpkg --print-architecture)
wget -q "https://github.com/kubernetes-sigs/cloud-provider-kind/releases/download/v0.6.0/cloud-provider-kind_0.6.0_linux_${ARCH}.tar.gz" \
  -O /tmp/cloud-provider-kind.tar.gz
tar -xzf /tmp/cloud-provider-kind.tar.gz -C /usr/local/bin cloud-provider-kind
rm /tmp/cloud-provider-kind.tar.gz
nohup cloud-provider-kind > /tmp/cloud-provider-kind.log 2>&1 &

# Install production HelmRelease
kubectl apply -f release/

# Get LoadBalancer IP
echo "Waiting for LoadBalancer IP..."
for i in $(seq 1 30); do
  LB_IP=$(kubectl get svc -n envoy-gateway-system \
    -o jsonpath='{.items[?(@.metadata.name matches "envoy-envoy-gateway.*")].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [[ -n "$LB_IP" ]]; then
    echo "LoadBalancer IP: $LB_IP"
    break
  fi
  sleep 5
done

# Install preview ResourceSet manifests
kubectl apply -f preview/

# Create GitHub auth secret for ResourceSetInputProvider
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  kubectl create secret generic github-auth \
    --from-literal=username=git \
    --from-literal=password="${GITHUB_TOKEN}" \
    -n app-preview \
    --dry-run=client -o yaml | kubectl apply -f -
else
  echo "WARNING: GITHUB_TOKEN not set — skipping github-auth secret creation"
fi

echo "Setup complete."
