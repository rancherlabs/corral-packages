output "first_node_ip" {
  value = aws_instance.node[0].public_ip
}

output "corral_node_pools" {
  value = {
    node = [for instance in aws_instance.node : {
      name = instance.tags.Name // unique name of node
      user = var.proxy_setup ? "root" : var.aws_ssh_user // ssh username
      address = var.airgap_setup || var.proxy_setup ? instance.private_ip : instance.public_ip // address of ssh host
      bastion_address = var.airgap_setup || var.proxy_setup ? var.registry_ip : ""
      bastion_internal_address = var.airgap_setup || var.proxy_setup ? var.registry_private_ip : ""
    }]
  }
}