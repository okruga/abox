# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**k8sdiy-env** sets up ephemeral PR preview environments on a local Kubernetes cluster using KinD, Flux CD (GitOps), and Envoy Gateway (Gateway API). Each PR to the target app repo gets its own routed environment at `/pr-{number}`.

## Common Commands

```bash
# Install tools (OpenTofu, K9s, Flux CLI)
make tools

# Full bootstrap (installs tools, provisions cluster, configures GitHub auth)
make init

# Set GitHub credentials interactively
make set-github-vars

# Apply infrastructure
make apply-tofu

# Initialize OpenTofu only
make tofu
```

**OpenTofu (Terraform) workflow:**
```bash
cd bootstrap/
tofu init
tofu plan
tofu apply
```

**Flux CD:**
```bash
flux get all                    # Check all Flux resources
flux reconcile source git flux-system   # Force reconcile
flux logs --follow              # Stream logs
```

**Gateway API / cluster:**
```bash
kubectl get gateway,httproute -A
kubectl get resourceset,resourcesetinputprovider -n app-preview
```

## Architecture

### Infrastructure Stack
- **KinD** (Kubernetes in Docker) — local cluster, 1 control-plane + 2 workers, IPVS kube-proxy
- **Flux CD 2.5.x** — GitOps operator, bootstrapped via Terraform using Flux Operator + FluxInstance CRDs
- **Envoy Gateway 1.3.2** — implements Kubernetes Gateway API for HTTP routing
- **cloud-provider-kind** — provides LoadBalancer support in KinD

### Directory Layout

| Directory | Purpose |
|-----------|---------|
| `bootstrap/` | OpenTofu/Terraform: provisions KinD cluster, installs Flux and Envoy Gateway |
| `gatewayapi/` | GatewayClass + Gateway manifest (Envoy, port 80) |
| `release/` | HelmRelease for production app (`kbot`, OCI chart from ghcr.io) |
| `preview/` | Flux ResourceSet manifests for dynamic PR environments |
| `scripts/` | Reference/educational shell scripts (not part of main flow) |

### Preview Environment Flow

```
GitHub PR opened on kbot-src repo
  → Flux ResourceSetInputProvider polls GitHub API (1-min interval)
    → ResourceSet generates per-PR resources:
        - GitRepository (source for that branch/SHA)
        - HelmRelease (deploys chart with commit-SHA image tag)
        - HTTPRoute (/pr-{id} path on the gateway)
      → Discord notification sent on state changes
```

**Key files:**
- `preview/01ResourceSetInputProvider.yaml` — watches `github.com/den-vasyliev/kbot-src` PRs
- `preview/02ResourceSet.yaml` — template that creates GitRepository + HelmRelease + HTTPRoute per PR
- `preview/03Notification.yaml` — Discord webhook alerts

### Routing
- **Production**: `Host: kbot.example.com` → `default` namespace
- **Preview**: `Host: kbot.example.com` + path `/pr-{number}` → `app-preview` namespace

### Required Secrets / Variables

| Variable | Where used | Notes |
|----------|-----------|-------|
| `github_token` | Terraform `variables.tf` | Set via `make set-github-vars` or `TF_VAR_github_token` env var |
| `github_org` | Terraform | Default: `den-vasyliev` |
| `github_repository` | Terraform | Default: `flux-preview` |

The GitHub token must be stored as a Kubernetes secret for Flux's `ResourceSetInputProvider` to query the GitHub API.

## CI/CD

`.github/workflows/terraform-pr-check.yml` runs on PRs touching Terraform files:
1. `tofu fmt` — format check
2. `tofu validate` — schema validation
3. `tofu plan` — plan generation
4. Checkov + TFSec security scans
5. git-secrets credential leak detection
