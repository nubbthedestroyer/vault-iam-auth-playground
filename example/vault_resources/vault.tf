provider "vault" {
  address = "http://vault-805037257.us-east-1.elb.amazonaws.com:80"
  token   = "ef51813a-2317-20d7-9b52-39ce6c2740c0"
}

resource "vault_auth_backend" "aws" {
  type = "aws"
}

resource "vault_aws_auth_backend_role" "example" {
  backend   = "${vault_auth_backend.aws.path}"
  role      = "aws-by-instanceprofile"
  auth_type = "iam"

  //  bound_ami_id                   = "ami-8c1be5f6"
  //  bound_account_id               = "123456789012"
  //  bound_vpc_id                   = "vpc-b61106d4"
  //  bound_subnet_id                = "vpc-133128f1"
  //  bound_iam_role_arn             = "arn:aws:iam::123456789012:role/MyRole"
  bound_iam_instance_profile_arn = "arn:aws:iam::724703905414:instance-profile/test-vault-profile"

  inferred_entity_type = "ec2_instance"
  inferred_aws_region  = "us-east-1"
  ttl                  = 60
  max_ttl              = 120

  policies = ["aws-by-instanceprofile"]
}

resource "vault_policy" "aws-by-instanceprofile" {
  name = "aws-by-instanceprofile"

  policy = <<EOF
# This policy allows all actions to the path "secret/aws-by-instanceprofile/*"
path "secret/aws-by-instanceprofile/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
}

resource "vault_generic_secret" "aws-by-instanceprofile" {
  data_json = <<EOF
{
  "diditwork": "yes"
}
EOF

  path = "secret/aws-by-instanceprofile/diditwork"
}
