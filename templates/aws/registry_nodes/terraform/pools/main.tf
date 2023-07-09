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
  region     = var.aws_region
}

resource "random_id" "cluster_id" {
  byte_length       = 6
}

resource "aws_key_pair" "corral_key" {
  key_name       = "corral-${var.corral_user_id}-${random_id.cluster_id.hex}"
  public_key = var.corral_public_key
}

data "cloudinit_config" "docker_service_config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = var.install_docker ? format("%s%s", file("${path.module}/cloud-init/install-docker.yaml"), file("${path.module}/cloud-init/setup-docker-service.yaml")) : file("${path.module}/cloud-init/setup-docker-service.yaml")

  }
}

resource "aws_instance" "registry" {
  ami = var.aws_ami
  instance_type     = var.instance_type
  key_name = aws_key_pair.corral_key.key_name
  vpc_security_group_ids = [var.aws_security_group]
  subnet_id = var.aws_subnet
  user_data = data.cloudinit_config.docker_service_config.rendered

  ebs_block_device {
    device_name           = "/dev/sda1"
    volume_size           = "200"
    volume_type           = "gp3"
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
      host        = self.public_ip
      user        = var.aws_ssh_user
      private_key = var.corral_private_key
      timeout     = "4m"
   }

  tags = {
    Name  = "${var.corral_user_id}-${random_id.cluster_id.hex}-${var.proxy_setup ? "proxy-bastion" : "registry"}"
  }
}

resource "aws_route53_record" "aws_route53" {
  zone_id            = data.aws_route53_zone.selected.zone_id
  name               = "${aws_instance.registry.tags.Name}"
  type               = "A"
  ttl                = "300"
  records            = [var.airgap_setup ? aws_instance.registry.private_ip : aws_instance.registry.public_ip]
}

data "aws_route53_zone" "selected" {
  name               = var.aws_route53_zone
  private_zone       = false
}
