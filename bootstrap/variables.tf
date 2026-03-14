variable "cluster_name" {
  description = "Cluster Name"
  type        = string
  default     = "preview"
}

variable "oci_registry" {
  description = "OCI registry URL for Flux config helm chart"
  type        = string
  default     = "oci://ghcr.io/den-vasyliev/a-box"
}
