locals {
    proxmox_host   = "192.168.20.200"
    proxmox_node   = "pve"
    template_vm_id = 8000
#     unifi_api_url  = "https://10.0.0.1/"
    minio_endpoint = "http://192.168.20.191:9000"
    minio_region   = "default"
    minio_bucket   = "terraform-state"
}
