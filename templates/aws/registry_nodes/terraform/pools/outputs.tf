output "registry_fqdn" {
  value = var.proxy_setup ? null : aws_route53_record.aws_route53.fqdn
}

output "registry_ip" {
  value = aws_instance.registry.public_ip
}

output "registry_private_ip" {
  value = aws_instance.registry.private_ip
}



output "corral_node_pools" {
  value = {
    registry = [for node in [aws_instance.registry] : {
      name = node.tags.Name
      user = "root"
      address = node.public_ip
    }]
  }
}
