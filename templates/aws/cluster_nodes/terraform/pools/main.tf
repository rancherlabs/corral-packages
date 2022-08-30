terraform {
  required_version = ">= 0.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
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

  provisioner "remote-exec" {
    inline = [
      "sudo su <<EOF",
      "echo ${var.corral_public_key} ${self.key_name} > /root/.ssh/authorized_keys",
      "EOF",
    ]
  }
  connection {
      type        = "ssh"
      host        = self.public_ip
      user        = var.aws_ssh_user
      private_key = var.corral_private_key
      timeout     = "4m"
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
  
 provisioner "remote-exec" {
    inline = [
      "sudo su <<EOF",
      "echo ${var.corral_public_key} ${self.key_name} > /root/.ssh/authorized_keys",
      "EOF",
    ]
  }
  connection {
      type        = "ssh"
      host        = self.public_ip
      user        = var.aws_ssh_user
      private_key = var.corral_private_key
      timeout     = "4m"
   }
  tags = {
    Name  = "${var.corral_user_id}-${random_id.cluster_id.hex}-agent-${count.index}"
  }
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_6443" {
  target_group_arn = aws_lb_target_group.aws_tg_6443.arn
  target_id        = aws_instance.server[0].id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_9345" {
  target_group_arn = aws_lb_target_group.aws_tg_9345.arn
  target_id        = aws_instance.server[0].id
  port             = 9345
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_80" {
  target_group_arn = aws_lb_target_group.aws_tg_80.arn
  target_id        = aws_instance.server[0].id
  port             = 80
  depends_on       = [aws_instance.server[0]]
}

resource "aws_lb_target_group_attachment" "aws_tg_attachment_443" {
  target_group_arn = aws_lb_target_group.aws_tg_443.arn
  target_id        = aws_instance.server[0].id
  port             = 443
  depends_on       = [aws_instance.server[0]]
}

resource "aws_lb" "aws_nlb" {
  internal           = false
  load_balancer_type = "network"
  subnets            = [var.aws_subnet]
  name               = "${var.aws_hostname_prefix}-nlb"
}

resource "aws_lb_target_group" "aws_tg_6443" {
  port             = 6443
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-tg-6443"
}

resource "aws_lb_target_group" "aws_tg_9345" {
  port             = 9345
  protocol         = "TCP"
  vpc_id           = var.aws_vpc
  name             = "${var.aws_hostname_prefix}-tg-9345"
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

resource "aws_route53_record" "aws_route53" {
  zone_id            = data.aws_route53_zone.selected.zone_id
  name               = var.aws_hostname_prefix
  type               = "CNAME"
  ttl                = "300"
  records            = [aws_lb.aws_nlb.dns_name]
}

data "aws_route53_zone" "selected" {
  name               = var.aws_route53_zone
  private_zone       = false
}