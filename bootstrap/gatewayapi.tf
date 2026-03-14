# ==========================================
# Bootstrap Flux config via OCI artifact
# ==========================================
resource "helm_release" "flux_config" {
  depends_on = [helm_release.flux_instance]

  name       = "flux-config"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/den-vasyliev"
  chart      = "flux-config"
  version    = "0.1.0"
}
