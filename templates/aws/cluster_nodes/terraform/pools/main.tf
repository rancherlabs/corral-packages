terraform {
  required_version = ">= 0.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "registry_ip" {
    type = string
    default = null
}

provider "random" {}
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region =  var.aws_region
}

resource "random_id" "cluster_id" {
  byte_length       = 6
}

resource "aws_key_pair" "corral_key" {
  key_name       = "corral-${var.corral_user_id}-${random_id.cluster_id.hex}"
  public_key = var.corral_public_key
}

resource "aws_instance" "server" {
  count = var.server_count
  ami = var.aws_ami
  instance_type     = var.instance_type
  key_name = aws_key_pair.corral_key.key_name
  vpc_security_group_ids = [var.aws_security_group]
  subnet_id = var.aws_subnet
  associate_public_ip_address = var.airgap_setup || var.proxy_setup ? false : true

  ebs_block_device {
     device_name           = "/dev/sda1"
     volume_size           = var.aws_volume_size
     volume_type           = var.aws_volume_type
     encrypted             = true
     delete_on_termination = true
   }

  provisioner "remote-exec" {
    inline = var.airgap_setup || var.rke_setup || var.proxy_setup ? [
      "sudo su <<EOF",
      "echo \"${var.corral_public_key} ${self.key_name}\" > /root/.ssh/authorized_keys",
      "echo \"${var.corral_private_key}\"",
      "echo \"${var.corral_private_key}\" > /root/.ssh/id_${var.corral_ssh_key_type}",
      "chmod 700 /root/.ssh/id_${var.corral_ssh_key_type}",
      "EOF",
    ]: [
      "sudo su <<EOF",
      "echo ${var.corral_public_key} ${self.key_name} > /root/.ssh/authorized_keys",
      "EOF",
    ]
  }
  connection {
      type        = "ssh"
      host        = var.airgap_setup || var.proxy_setup ? self.private_ip : self.public_ip
      user        = var.aws_ssh_user
      private_key = var.corral_private_key
      timeout     = "4m"
      bastion_host = var.airgap_setup || var.proxy_setup ? var.registry_ip : null
      bastion_user = var.airgap_setup || var.proxy_setup ? var.aws_ssh_user : null
   }

  tags = {
    Name  = "${var.corral_user_id}-${random_id.cluster_id.hex}-cp-${count.index}"
  }
}

resource "aws_instance" "agent" {
  count = var.agent_count
  ami = var.aws_ami
  instance_type     = var.instance_type
  key_name = aws_key_pair.corral_key.key_name
  vpc_security_group_ids = [var.aws_security_group]
  subnet_id = var.aws_subnet
  associate_public_ip_address = var.airgap_setup || var.proxy_setup ? false : true

  ebs_block_device {
     device_name           = "/dev/sda1"
     volume_size           = var.aws_volume_size
     volume_type           = var.aws_volume_type
     encrypted             = true
     delete_on_termination = true
   }

  provisioner "remote-exec" {
    inline = var.airgap_setup || var.proxy_setup ? [
      "sudo su <<EOF",
      "echo \"${var.corral_public_key} ${self.key_name}\" > /root/.ssh/authorized_keys",
      "echo \"${var.corral_private_key}\"",
      "echo \"${var.corral_private_key}\" > /root/.ssh/id_${var.corral_ssh_key_type}",
      "chmod 700 /root/.ssh/id_${var.corral_ssh_key_type}",
      "EOF",
    ]: [
      "sudo su <<EOF",
      "echo ${var.corral_public_key} ${self.key_name} > /root/.ssh/authorized_keys",
      "EOF",
    ]
  }
  connection {
      type        = "ssh"
      host        = var.airgap_setup || var.proxy_setup ? self.private_ip : self.public_ip
      user        = var.aws_ssh_user
      private_key = var.corral_private_key
      timeout     = "4m"
      bastion_host = var.airgap_setup || var.proxy_setup ? var.registry_ip : null
      bastion_user = var.airgap_setup || var.proxy_setup ? var.aws_ssh_user : null
   }

  tags = {
    Name  = "${var.corral_user_id}-${random_id.cluster_id.hex}-agent-${count.index}"
  }
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_80_server" {
  count = var.server_count
  target_group_arn = aws_lb_target_group.aws_tg_80.arn
  target_id        = aws_instance.server[count.index].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_443_server" {
  count = var.server_count
  target_group_arn = aws_lb_target_group.aws_tg_443.arn
  target_id        = aws_instance.server[count.index].id
  port             = 443
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_9345_server" {
  count = var.server_count
  target_group_arn = aws_lb_target_group.aws_tg_9345.arn
  target_id        = aws_instance.server[count.index].id
  port             = 9345
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_6443_server" {
  count = var.server_count
  target_group_arn = aws_lb_target_group.aws_tg_6443.arn
  target_id        = aws_instance.server[count.index].id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "aws_internal_tg_attachment_80_server" {
  count = var.airgap_setup || var.proxy_setup ? var.server_count : 0
  target_group_arn = aws_lb_target_group.aws_internal_tg_80[0].arn
  target_id        = aws_instance.server[count.index].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "aws_internal_tg_attachment_443_server" {
  count = var.airgap_setup || var.proxy_setup ? var.server_count : 0
  target_group_arn = aws_lb_target_group.aws_internal_tg_443[0].arn
  target_id        = aws_instance.server[count.index].id
  port             = 443
}

resource "aws_lb_target_group_attachment" "aws_internal_tg_attachment_6443_server" {
  count = var.airgap_setup || var.proxy_setup ? var.server_count : 0
  target_group_arn = aws_lb_target_group.aws_internal_tg_6443[0].arn
  target_id        = aws_instance.server[count.index].id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "aws_internal_tg_attachment_9345_server" {
  count = var.airgap_setup || var.proxy_setup ? var.server_count : 0
  target_group_arn = aws_lb_target_group.aws_internal_tg_9345[0].arn
  target_id        = aws_instance.server[count.index].id
  port             = 9345
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_80" {
  count = var.airgap_setup || var.proxy_setup ? var.agent_count : 0
  target_group_arn = aws_lb_target_group.aws_tg_80.arn
  target_id        = aws_instance.agent[count.index].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_443" {
  count = var.airgap_setup || var.proxy_setup ? var.agent_count : 0
  target_group_arn = aws_lb_target_group.aws_tg_443.arn
  target_id        = aws_instance.agent[count.index].id
  port             = 443
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_6443" {
  count = var.airgap_setup || var.proxy_setup ? var.agent_count : 0
  target_group_arn = aws_lb_target_group.aws_tg_6443.arn
  target_id        = aws_instance.agent[count.index].id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_9345" {
  count = var.airgap_setup || var.proxy_setup ? var.agent_count : 0
  target_group_arn = aws_lb_target_group.aws_tg_9345.arn
  target_id        = aws_instance.agent[count.index].id
  port             = 9345
}

resource "aws_lb_target_group_attachment" "aws_internal_tg_attachment_80" {
  count = var.airgap_setup || var.proxy_setup ? var.agent_count : 0
  target_group_arn = aws_lb_target_group.aws_internal_tg_80[0].arn
  target_id        = aws_instance.agent[count.index].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "aws_internal_tg_attachment_443" {
  count = var.airgap_setup || var.proxy_setup ? var.agent_count : 0
  target_group_arn = aws_lb_target_group.aws_internal_tg_443[0].arn
  target_id        = aws_instance.agent[count.index].id
  port             = 443
}

resource "aws_lb_target_group_attachment" "aws_internal_tg_attachment_6443" {
  count = var.airgap_setup || var.proxy_setup ? var.agent_count : 0
  target_group_arn = aws_lb_target_group.aws_internal_tg_6443[0].arn
  target_id        = aws_instance.agent[count.index].id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "aws_internal_tg_attachment_9345" {
  count = var.airgap_setup || var.proxy_setup ? var.agent_count : 0
  target_group_arn = aws_lb_target_group.aws_internal_tg_9345[0].arn
  target_id        = aws_instance.agent[count.index].id
  port             = 9345
}

resource "aws_lb" "aws_internal_nlb" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  internal           = true
  load_balancer_type = "network"
  subnets            = [var.aws_subnet]
  name               = "${var.aws_hostname_prefix}-internal-nlb"
}

resource "aws_lb" "aws_nlb" {
  internal           = false
  load_balancer_type = "network"
  subnets            = [var.aws_subnet]
  name               = "${var.aws_hostname_prefix}-nlb"
}

resource "aws_lb_target_group" "aws_tg_80" {
  port             = 80
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-tg-80"
  health_check {
        protocol = "HTTP"
        port = "traffic-port"
        path = "/ping"
        interval = 10
        timeout = 6
        healthy_threshold = 3
        unhealthy_threshold = 3
        matcher = "200-399"
  }
}

resource "aws_lb_target_group" "aws_tg_443" {
  port             = 443
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-tg-443"
  health_check {
        protocol = "HTTP"
        port = 80
        path = "/ping"
        interval = 10
        timeout = 6
        healthy_threshold = 3
        unhealthy_threshold = 3
        matcher = "200-399"
  }
}

resource "aws_lb_target_group" "aws_tg_6443" {
  port             = 6443
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-tg-6443"
  health_check {
        protocol = "HTTP"
        port = 80
        path = "/ping"
        interval = 10
        timeout = 6
        healthy_threshold = 3
        unhealthy_threshold = 3
        matcher = "200-399"
  }
}

resource "aws_lb_target_group" "aws_tg_9345" {
  port             = 9345
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-tg-9345"
  health_check {
        protocol = "HTTP"
        port = 80
        path = "/ping"
        interval = 10
        timeout = 6
        healthy_threshold = 3
        unhealthy_threshold = 3
        matcher = "200-399"
  }
}

resource "aws_lb_target_group" "aws_internal_tg_80" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  port             = 80
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-internal-tg-80"
  health_check {
        protocol = "HTTP"
        port = "traffic-port"
        path = "/ping"
        interval = 10
        timeout = 6
        healthy_threshold = 3
        unhealthy_threshold = 3
        matcher = "200-399"
  }
}

resource "aws_lb_target_group" "aws_internal_tg_443" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  port             = 443
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-internal-tg-443"
  health_check {
        protocol = "HTTP"
        port = 80
        path = "/ping"
        interval = 10
        timeout = 6
        healthy_threshold = 3
        unhealthy_threshold = 3
        matcher = "200-399"
  }
}

resource "aws_lb_target_group" "aws_internal_tg_6443" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  port             = 6443
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-internal-tg-6443"
  health_check {
        protocol = "HTTP"
        port = 80
        path = "/ping"
        interval = 10
        timeout = 6
        healthy_threshold = 3
        unhealthy_threshold = 3
        matcher = "200-399"
  }
}

resource "aws_lb_target_group" "aws_internal_tg_9345" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  port             = 9345
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-internal-tg-9345"
  health_check {
        protocol = "HTTP"
        port = 80
        path = "/ping"
        interval = 10
        timeout = 6
        healthy_threshold = 3
        unhealthy_threshold = 3
        matcher = "200-399"
  }
}

resource "aws_lb_listener" "aws_nlb_listener_80" {
  load_balancer_arn = aws_lb.aws_nlb.arn
  port              = "80"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_tg_80.arn
  }
}

resource "aws_lb_listener" "aws_nlb_listener_443" {
  load_balancer_arn = aws_lb.aws_nlb.arn
  port              = "443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_tg_443.arn
  }
}

resource "aws_lb_listener" "aws_nlb_listener_6443" {
  load_balancer_arn = aws_lb.aws_nlb.arn
  port              = "6443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_tg_6443.arn
  }
}

resource "aws_lb_listener" "aws_nlb_listener_9345" {
  load_balancer_arn = aws_lb.aws_nlb.arn
  port              = "9345"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_tg_9345.arn
  }
}

resource "aws_lb_listener" "aws_internal_nlb_listener_80" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  load_balancer_arn = aws_lb.aws_internal_nlb[0].arn
  port              = "80"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_internal_tg_80[0].arn
  }
}

resource "aws_lb_listener" "aws_internal_nlb_listener_443" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  load_balancer_arn = aws_lb.aws_internal_nlb[0].arn
  port              = "443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_internal_tg_443[0].arn
  }
}

resource "aws_lb_listener" "aws_internal_nlb_listener_6443" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  load_balancer_arn = aws_lb.aws_internal_nlb[0].arn
  port              = "6443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_internal_tg_6443[0].arn
  }
}

resource "aws_lb_listener" "aws_internal_nlb_listener_9345" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  load_balancer_arn = aws_lb.aws_internal_nlb[0].arn
  port              = "9345"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_internal_tg_9345[0].arn
  }
}

resource "aws_route53_record" "aws_route53" {
  zone_id            = data.aws_route53_zone.selected.zone_id
  name               = var.aws_hostname_prefix
  type               = "CNAME"
  ttl                = "300"
  records            = [aws_lb.aws_nlb.dns_name]
}

resource "aws_route53_record" "aws_route53_internal" {
  count = var.airgap_setup || var.proxy_setup ? 1 : 0
  zone_id            = data.aws_route53_zone.selected.zone_id
  name               = "${var.aws_hostname_prefix}-internal"
  type               = "CNAME"
  ttl                = "300"
  records            = [aws_lb.aws_internal_nlb[0].dns_name]
}

data "aws_route53_zone" "selected" {
  name               = var.aws_route53_zone
  private_zone       = false
}