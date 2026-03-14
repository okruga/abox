# ==========================================
# Apply gatewayapi manifests via Flux
# ==========================================
data "kubectl_file_documents" "gatewayapi" {
  content = join("---\n", [
    for f in sort(fileset("${path.module}/../gatewayapi", "*.yaml")) :
    file("${path.module}/../gatewayapi/${f}")
  ])
}

resource "kubectl_manifest" "gatewayapi" {
  depends_on = [helm_release.flux_instance]
  for_each   = data.kubectl_file_documents.gatewayapi.manifests

  yaml_body = each.value
}
