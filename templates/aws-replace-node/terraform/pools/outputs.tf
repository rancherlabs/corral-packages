output "corral_node_pools" {
  value = {
    replace = [for instance in aws_instance.replace : {
      name    = instance.tags.Name // unique name of node
      user    = "root"             // ssh username
      address = instance.public_ip // address of ssh host
    }]
  }
}
