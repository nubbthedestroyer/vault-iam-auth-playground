provider "aws" {
  profile = "default"
  region  = "${var.region}"
  version = "~> 1.9"
}

module "vault" {
  source = "module/"

  download-url = "${var.vault_binary_download_url}"
  ami          = "${var.ami_id}"

  config = "${data.template_file.vault_config.rendered}"

  extra-install = ""
  subnets       = "${module.base_network.public_subnets}"
  vpc-id        = "${module.base_network.vpc_id}"

  key-name = "${var.keyname}"
}

module "base_network" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v1.23.0"

  name = "${var.name}"

  azs = "${var.azs}"

  cidr = "${var.cidr}"

  private_subnets = "${var.private_subnets}"

  public_subnets = "${var.public_subnets}"

  enable_nat_gateway = "${var.enable_nat_gateway}"

  enable_dns_hostnames = "${var.enable_dns_hostnames}"
}

data "template_file" "vault_config" {
  template = "${file("${path.cwd}/vault_config.hcl")}"
}
