# ==========================================
# Step 1: Flux HelmRepository + HelmReleases
# (installs Gateway API CRDs + agentgateway)
# ==========================================
data "kubectl_file_documents" "helmreleases" {
  content = file("${path.module}/../gatewayapi/HelmReleases.yaml")
}

resource "kubectl_manifest" "helmreleases" {
  depends_on = [helm_release.flux_instance]
  for_each   = data.kubectl_file_documents.helmreleases.manifests

  yaml_body        = each.value
  wait             = true
  server_side_apply = true
}

# ==========================================
# Step 2: Wait for Flux to install Gateway API CRDs
# ==========================================
resource "null_resource" "wait_for_gateway_api_crds" {
  depends_on = [kubectl_manifest.helmreleases]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Gateway API CRDs..."
      until kubectl \
        --server="$SERVER" \
        --client-certificate=<(echo "$CLIENT_CERT") \
        --client-key=<(echo "$CLIENT_KEY") \
        --certificate-authority=<(echo "$CA_CERT") \
        get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; do
        echo "  not ready yet, retrying in 5s..."
        sleep 5
      done
      echo "Gateway API CRDs ready."
    EOT
    interpreter = ["/bin/bash", "-c"]
    environment = {
      SERVER      = kind_cluster.this.endpoint
      CLIENT_CERT = kind_cluster.this.client_certificate
      CLIENT_KEY  = kind_cluster.this.client_key
      CA_CERT     = kind_cluster.this.cluster_ca_certificate
    }
  }
}

# ==========================================
# Step 3: GatewayClass + Gateway
# ==========================================
data "kubectl_file_documents" "gateway" {
  content = file("${path.module}/../gatewayapi/Gateway.yaml")
}

resource "kubectl_manifest" "gateway" {
  depends_on = [null_resource.wait_for_gateway_api_crds]
  for_each   = data.kubectl_file_documents.gateway.manifests

  yaml_body         = each.value
  server_side_apply = true
}
