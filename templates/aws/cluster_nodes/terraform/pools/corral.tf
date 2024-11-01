variable "corral_name" {} // name of the corral being created
variable "corral_user_id" {} // how the user is identified (usually github username)
variable "corral_public_key" {} // The corrals public key.  This should be installed on every node.
variable "corral_private_key" {} // The corrals private key.  This should be installed on every node to be able to have root access, as aws does not allow this by default.
variable "corral_ssh_key_type" {
    default = "rsa"
} // The corrals ssh key type (rsa, ed25519, etc.)

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {}
variable "aws_ami" {}
variable "aws_hostname_prefix" {}
variable "aws_route53_zone" {}
variable "aws_ssh_user" {}
variable "aws_security_group" {}
variable "aws_vpc" {}
variable "aws_volume_size" {}
variable "aws_volume_type" {}
variable "aws_subnet" {}
variable "instance_type" {}
variable "server_count" {}
variable "agent_count" {}
variable "airgap_setup" {}
variable "rke_setup" {}
variable "proxy_setup" {}