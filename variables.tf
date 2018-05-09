variable "name" {
  description = "General name for this stack"
  default     = "vault"
}

variable "region" {
  default = "us-east-1"
}

variable "ami_id" {
  description = "AMI to build Vault on.  This should be a trusted AMI.  The user data in this module expects the public Ubuntu 14.04 image."
  default     = "ami-38708b45"
}

variable "vault_binary_download_url" {
  description = "Location of Vault binary to obtain and install"
  default     = "https://releases.hashicorp.com/vault/0.10.1/vault_0.10.1_linux_amd64.zip"
}

variable "keyname" {
  description = "Name of the key pair to use to connect to the instance after it's created"
}

variable "azs" {
  description = "list of AZs to deploy to"

  default = [
    "us-east-1a",
    "us-east-1b",
  ]

  type = "list"
}

variable "cidr" {
  description = "CIDR block for the VPC that will be created for this module."
  default     = "172.18.0.0/16"
}

variable "private_subnets" {
  description = "List of private subnet CIDRs for the stack"

  default = [
    "172.18.0.0/21",
    "172.18.8.0/21",
  ]

  type = "list"
}

variable "public_subnets" {
  description = "List of public subnet CIDRs for the stack"

  default = [
    "172.18.168.0/22",
    "172.18.172.0/22",
  ]

  type = "list"
}

variable "enable_nat_gateway" {
  default = true
}

variable "enable_dns_hostnames" {
  default = true
}
