# Secret + identity variable DECLARATIONS (safe to commit — no values here).
# Values are supplied at runtime via TF_VAR_* by `ccr`, decrypted from
# secrets.sops.yaml. This replaces the old gitignored secrets.tf-with-defaults.

# --- Non-secret identities (committed defaults are fine) ---
variable "vm_username" {
  type    = string
  default = "k8s"
}

variable "proxmox_username" {
  type    = string
  default = "terraform"
}

variable "unifi_username" {
  type    = string
  default = "terraform"
}

# --- Secrets (no defaults; sensitive; supplied via TF_VAR_* at runtime) ---
variable "vm_password" {
  type      = string
  sensitive = true
}

variable "vm_ssh_key" {
  type = list(string)
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "unifi_password" {
  type      = string
  sensitive = true
}

variable "minio_access_key" {
  type      = string
  sensitive = true
}

variable "minio_secret_key" {
  type      = string
  sensitive = true
}
