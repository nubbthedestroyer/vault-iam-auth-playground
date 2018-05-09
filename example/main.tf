provider "aws" {
  profile = "default"
  region  = "us-east-1"
  version = "~> 1.9"
}

module "vault" {
  source  = "../"
  keyname = "mlucas2"
}
