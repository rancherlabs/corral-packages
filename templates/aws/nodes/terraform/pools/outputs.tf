output "first_node_ip" {
  value = aws_instance.node[0].public_ip
}

output "corral_node_pools" {
  value = {
    node = [for instance in aws_instance.node : {
      name = instance.tags.Name // unique name of node
      user = "root" // ssh username
      address = var.airgap_setup ? instance.private_ip : instance.public_ip // address of ssh host
      bastion_address = var.airgap_setup ? var.bastion_ip : ""
    }]
  }
}