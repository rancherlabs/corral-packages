output "fqdn" {
  value = aws_route53_record.aws_route53.fqdn
}

output "internal_fqdn" {
  value = var.airgap_setup ? aws_route53_record.aws_route53_internal[0].fqdn : null
}

output "kube_api_host" {
  value = var.airgap_setup || var.proxy_setup ? aws_instance.server[0].private_ip : aws_instance.server[0].public_ip
}

output "airgap_setup" {
  value = var.airgap_setup
}

output "proxy_setup" {
  value = var.proxy_setup
}

output "corral_node_pools" {
  value = {
    bastion = [for instance in [aws_instance.server[0]] : {
      name = instance.tags.Name // unique name of node
      user = "root" // ssh username
      ssh_user = var.aws_ssh_user
      address = var.airgap_setup || var.proxy_setup ? instance.private_ip : instance.public_ip // address of ssh host
      internal_address = instance.private_ip
      bastion_address = var.airgap_setup || var.proxy_setup ? var.registry_ip : ""
    }]
    server = [for instance in slice(aws_instance.server, 1, var.server_count) : {
      name = instance.tags.Name // unique name of node
      user = "root" // ssh username
      ssh_user = var.aws_ssh_user
      address = var.airgap_setup || var.proxy_setup ? instance.private_ip : instance.public_ip // address of ssh host
      internal_address = instance.private_ip
      bastion_address = var.airgap_setup || var.proxy_setup ? var.registry_ip : ""
    }]
    agent = [for instance in aws_instance.agent : {
      name = instance.tags.Name // unique name of node
      user = "root" // ssh username
      ssh_user = var.aws_ssh_user
      address = var.airgap_setup || var.proxy_setup ? instance.private_ip : instance.public_ip // address of ssh host
      internal_address= instance.private_ip
      bastion_address = var.airgap_setup || var.proxy_setup ? var.registry_ip : ""
    }]
  }
}