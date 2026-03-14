# a-box

Local Kubernetes environment using KinD, Flux CD, and kgateway (agentgateway). Gitless GitOps via OCI artifacts.

## Stack

- **KinD** — local Kubernetes cluster (1 control-plane + 2 workers)
- **Flux CD 2.x** — GitOps operator (Flux Operator + FluxInstance)
- **kgateway v2.3.0** — Kubernetes Gateway API implementation
- **kagent** — AI agent framework
- **cloud-provider-kind** — LoadBalancer support for KinD

## Quickstart

```bash
make run
```

Installs OpenTofu and K9s, provisions the KinD cluster, bootstraps Flux, starts cloud-provider-kind.

## How it works

```
make run  →  scripts/setup.sh
  → tofu apply (bootstrap/)
      → KinD cluster
      → helm: flux-operator
      → helm: flux-instance        (wait=true)
      → kubernetes_manifest: RSIP  (depends_on flux-instance)
          polls oci://ghcr.io/den-vasyliev/a-box/releases
          filter: semver tags only  ^\d+\.\d+\.\d+$
      → kubernetes_manifest: ResourceSet  (depends_on RSIP)
          creates OCIRepository + Kustomization per tag
              → releases/ OCI artifact reconciled:
                  kgateway-crds.yaml  → kgateway-crds HelmRelease (Gateway API CRDs)
                  kgateway.yaml       → kgateway HelmRelease + GatewayClass + Gateway
                  kagent-crds.yaml    → kagent-crds HelmRelease
                  kagent.yaml         → kagent HelmRelease
```

## Releasing

Push a semver tag to trigger the CI workflow, which publishes a new OCI artifact. RSIP picks it up and Flux reconciles automatically.

```bash
git tag v0.2.0 && git push origin v0.2.0
```

## Directory Layout

| Path | Purpose |
|------|---------|
| `bootstrap/` | OpenTofu: KinD cluster + Flux bootstrap (operator, instance, RSIP, ResourceSet) |
| `releases/` | OCI artifact contents: Flux manifests for kgateway + kagent |
| `scripts/setup.sh` | Full setup script (called by `make run`) |
| `.github/workflows/flux-push.yaml` | CI: push `releases/` as OCI artifact on `v*` tags |

## Verify

```bash
# Flux resources
flux get all

# Gateway
kubectl get gateway,httproute -A
kubectl get gatewayclass agentgateway

# LoadBalancer IP
kubectl get svc -n agentgateway-system

# kagent
kubectl get agents -n kagent
```
