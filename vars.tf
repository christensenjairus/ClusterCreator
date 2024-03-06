variable "template_name" {
    default = "ubuntu-jammy-cloudinit"
}
variable "proxmox_host" {
    default = "10.0.0.100"
}
variable "proxmox_node_name" {
    default = "Citadel"
}
variable "template_vm_id" {
    default = 9000
}
variable "unifi_api_url" {
    default = "https://10.0.0.1/"
}