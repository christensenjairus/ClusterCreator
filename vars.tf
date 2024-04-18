variable "proxmox_host" {
    default = "10.0.0.100"
}
variable "proxmox_node_name" {
    default = "Citadel" # The name of the node to create the VM on
}
variable "template_vm_id" {
    description = "The vm template id to clone for cluster creation"
    type        = string
    default     = 9000
}
variable "unifi_api_url" {
    default = "https://10.0.0.1/"
}