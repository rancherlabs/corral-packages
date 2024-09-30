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
  token      = var.aws_session_token
  region     = var.aws_region
}

resource "random_id" "cluster_id" {
  byte_length = 6
}

resource "aws_key_pair" "corral_key" {
  key_name   = "corral-${var.corral_user_id}-${random_id.cluster_id.hex}"
  public_key = var.corral_public_key
}

resource "aws_instance" "node" {
  count                       = var.node_count
  ami                         = var.aws_ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.corral_key.key_name
  vpc_security_group_ids      = [var.aws_security_group]
  subnet_id                   = var.aws_subnet
  associate_public_ip_address = var.airgap_setup ? false : true

  ebs_block_device {
    device_name           = "/dev/sda1"
    volume_size           = var.aws_volume_size
    volume_type           = var.aws_volume_type
    encrypted             = var.aws_volume_encrypted
    iops                  = var.aws_volume_iops
    delete_on_termination = true
  }

  provisioner "remote-exec" {
    inline = var.airgap_setup ? [
      "sudo su <<EOF",
      "echo ${var.corral_public_key} ${self.key_name} > /root/.ssh/authorized_keys",
      "echo \"${var.corral_private_key}\" > /root/.ssh/id_rsa",
      "chmod 700 /root/.ssh/id_rsa",
      "EOF",
      ] : [
      "sudo su <<EOF",
      "echo ${var.corral_public_key} ${self.key_name} > /root/.ssh/authorized_keys",
      "EOF",
    ]
  }
  connection {
    type         = "ssh"
    host         = var.airgap_setup ? self.private_ip : self.public_ip
    user         = var.aws_ssh_user
    private_key  = var.corral_private_key
    timeout      = "4m"
    bastion_host = var.airgap_setup ? var.bastion_ip : null
    bastion_user = var.airgap_setup ? "root" : null
  }

  tags = {
    Name = "${var.corral_user_id}-${random_id.cluster_id.hex}-cp-${count.index}"
  }
}
