output "fqdn" {
  value = aws_route53_record.aws_route53.fqdn
}

output "kube_api_host" {
  value = aws_instance.server[0].public_ip
}

output "corral_node_pools" {
  value = {
    bastion = [for instance in [aws_instance.server[0]] : {
      name = instance.tags.Name // unique name of node
      user = "root" // ssh username
      address = instance.public_ip // address of ssh host
    }]
    server = [for instance in slice(aws_instance.server, 1, var.server_count) : {
      name = instance.tags.Name // unique name of node
      user = "root" // ssh username
      address = instance.public_ip // address of ssh host
    }]
    agent = [for instance in aws_instance.agent : {
      name = instance.tags.Name // unique name of node
      user = "root" // ssh username
      address = instance.public_ip // address of ssh host
    }]
  }
}