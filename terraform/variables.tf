# Per-environment infrastructure targets. Values are supplied at runtime via
# TF_VAR_* by `ccr` (decrypted from secrets.sops.yaml for the active environment),
# so there is no more comment-toggling here. Run `ccr env <name>` to switch.
variable "proxmox_host" {
  type        = string
  description = "Proxmox API host/IP for the active environment"
}
variable "proxmox_node" {
  type        = string
  description = "Default Proxmox node name for the active environment"
}
variable "unifi_api_url" {
  type        = string
  description = "Unifi controller API URL for the active environment"
}

# Toggle the optional Unifi provider. When false, no unifi_network resources are
# created and the (lazy) provider never authenticates — no need to edit provider
# blocks. Defaults to true to match existing state; set false (or export
# TF_VAR_enable_unifi=false) to disable. The S3/MinIO backend is always on.
variable "enable_unifi" {
  type    = bool
  default = true
}

locals {
  # Per-environment values (fed from the variables above).
  proxmox_host  = var.proxmox_host
  proxmox_node  = var.proxmox_node
  unifi_api_url = var.unifi_api_url

  # Global, non-secret values (same across environments).
  # template_vm_id = 9000 # Debian 12 (Bookworm)
  template_vm_id = 9001 # Ubuntu 24.04 LTS
  #template_vm_id = 9002 # Ubuntu 25.04
  minio_endpoint = "http://10.0.70.5"
  minio_region   = "us"
  minio_bucket   = "terraform-state"
}
