variable "corral_name" {}        // name of the corral being created
variable "corral_user_id" {}     // how the user is identified (usually github username)
variable "corral_public_key" {}  // The corrals public key.  This should be installed on every node.
variable "corral_private_key" {} // The corrals private key.  This should be installed on every node to be able to have root access, as aws does not allow this by default.

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_session_token" {
  type    = string
  default = ""
}
variable "aws_region" {}
variable "aws_ami" {}
variable "aws_ssh_user" {}
variable "aws_security_group" {}
variable "aws_vpc" {}
variable "aws_subnet" {}
variable "instance_type" {}
variable "replace_count" {}
variable "kubeconfig" {}
variable "node_token" {}
