resource "proxmox_virtual_environment_pool" "operations_pool" {
  depends_on = [unifi_network.vlan]
  # had to add the Pool.Audit permission to the Terraform role in Proxmox for this to work
  for_each = {
    for key, value in var.clusters : key => value
    if key == terraform.workspace
  }
  comment = "Managed by Terraform"
  pool_id = upper(each.key) # pool id is the cluster name in all caps
}