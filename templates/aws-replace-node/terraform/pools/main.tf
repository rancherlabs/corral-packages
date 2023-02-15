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
  byte_length = 6
}

resource "aws_key_pair" "corral_key" {
  key_name   = "corral-${var.corral_user_id}-${random_id.cluster_id.hex}"
  public_key = var.corral_public_key
}

resource "aws_instance" "replace" {
  count                  = var.replace_count
  ami                    = var.aws_ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.corral_key.key_name
  vpc_security_group_ids = [var.aws_security_group]
  subnet_id              = var.aws_subnet

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
    Name = "${var.corral_user_id}-${random_id.cluster_id.hex}-replace-${count.index}"
  }
}
