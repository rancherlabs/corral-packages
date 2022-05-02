terraform {
  required_version = ">= 0.13"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "random" {}
provider "digitalocean" {
  token = var.digitalocean_token
}

resource "random_id" "corral_id" {
  byte_length       = 6
}

resource "digitalocean_ssh_key" "corral_key" {
  name       = "${var.corral_name}-${var.corral_user_id}-${random_id.corral_id.hex}"
  public_key = var.corral_public_key
}

resource "digitalocean_droplet" "server" {
  count = var.server_count

  name = "${var.corral_user_id}-${random_id.corral_id.hex}-server-${count.index}"
  size = var.size
  image    = var.image
  region   = "sfo3"
  ssh_keys = [digitalocean_ssh_key.corral_key.id]
  tags = [var.corral_user_id, random_id.corral_id.hex]
}
resource "digitalocean_droplet" "agent" {
  count = var.agent_count

  name = "${var.corral_user_id}-${random_id.corral_id.hex}-agent-${count.index}"
  size = var.size
  image    = "ubuntu-20-04-x64"
  region   = "sfo3"
  ssh_keys = [digitalocean_ssh_key.corral_key.id]
  tags = [var.corral_user_id, random_id.corral_id.hex]
}


resource "digitalocean_record" "fqdn" {
  domain = var.digitalocean_domain
  name   = random_id.corral_id.hex
  type   = "A"
  value  = digitalocean_droplet.server[0].ipv4_address
}

resource "digitalocean_record" "wildcard" {
  domain = var.digitalocean_domain
  name   = "*.${random_id.corral_id.hex}"
  type   = "CNAME"
  value  = "${join(".", [digitalocean_record.fqdn.name, digitalocean_record.fqdn.domain])}."
}