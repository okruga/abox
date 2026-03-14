# ==========================================
# Bootstrap Flux Operator
# ==========================================
resource "helm_release" "flux_operator" {
  depends_on = [kind_cluster.this]

  name             = "flux-operator"
  namespace        = "flux-system"
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart            = "flux-operator"
  create_namespace = true
}

# ==========================================
# Bootstrap Flux Instance
# ==========================================
resource "helm_release" "flux_instance" {
  depends_on = [helm_release.flux_operator]

  name       = "flux-instance"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  wait       = true

  set {
    name  = "distribution.version"
    value = "=2.x"
  }
}

# ==========================================
# Bootstrap Flux config via OCI artifact
# ==========================================
resource "helm_release" "flux_config" {
  depends_on = [helm_release.flux_instance]

  name       = "flux-config"
  namespace  = "flux-system"
  repository = var.oci_registry
  chart      = "flux-config"
  version    = "0.1.0"
}
