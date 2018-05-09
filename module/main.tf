# pull in the install script for vault server
data "template_file" "install" {
    template = "${file("${path.module}/scripts/install.sh.tpl")}"

    vars {
        download_url  = "${var.download-url}"
        config        = "${var.config}"
        extra-install = "${var.extra-install}"
    }
}

# Client only install for the test instance
data "template_file" "install_client_only" {
    template = "${file("${path.module}/scripts/install-client-only.sh.tpl")}"

    vars {
        download_url  = "${var.download-url}"
        extra-install = "${var.extra-install}"
    }
}

# holding onto this to re-enable later with SSM based auto-unseal
// We launch Vault into an ASG so that it can properly bring them up for us.
//resource "aws_autoscaling_group" "vault" {
//    name = "vault - ${aws_launch_configuration.vault.name}"
//    launch_configuration = "${aws_launch_configuration.vault.name}"
//    availability_zones = ["${split(",", var.availability-zones)}"]
//    min_size = "${var.nodes}"
//    max_size = "${var.nodes}"
//    desired_capacity = "${var.nodes}"
//    health_check_grace_period = 15
//    health_check_type = "EC2"
//    vpc_zone_identifier = ["${var.subnets}"]
//    load_balancers = ["${aws_elb.vault.id}"]
//
//    tag {
//        key = "Name"
//        value = "vault"
//        propagate_at_launch = true
//    }
//}
//
//resource "aws_launch_configuration" "vault" {
//    image_id = "${var.ami}"
//    instance_type = "${var.instance_type}"
//    key_name = "${var.key-name}"
//    security_groups = ["${aws_security_group.vault.id}"]
//    user_data = "${data.template_file.install.rendered}"
//    iam_instance_profile = "${aws_iam_instance_profile.asg_instance_profile.id}"
//}

# Single Vault instance
resource "aws_instance" "vault-a" {
    ami                    = "${var.ami}"
    instance_type           = "${var.instance_type}"
    subnet_id               = "${var.subnets[0]}"
    key_name               = "${var.key-name}"
    vpc_security_group_ids = ["${aws_security_group.vault.id}"]
    user_data               = "${data.template_file.install.rendered}"
    iam_instance_profile = "${aws_iam_instance_profile.asg_instance_profile.id}"

    tags {
      Name = "vault-a"
    }
}

# Test instance for testing instanceprofile based authentication
resource "aws_instance" "vault-test-instance" {
    ami                    = "${var.ami}"
    instance_type           = "${var.instance_type}"
    subnet_id               = "${var.subnets[0]}"
    key_name               = "${var.key-name}"
    vpc_security_group_ids = ["${aws_security_group.vault.id}"]
    user_data               = "${data.template_file.install_client_only.rendered}"
    iam_instance_profile = "${aws_iam_instance_profile.test_instance_profile.id}"

    tags {
      Name = "vault-test-instance"
    }
}

# Security group for Vault allows SSH and HTTP access (via "tcp" in case TLS is used)
resource "aws_security_group" "vault" {
    name = "vault"
    description = "Vault servers"
    vpc_id = "${var.vpc-id}"
}

resource "aws_security_group_rule" "vault-ssh" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

# This rule allows Vault HTTP API access to individual nodes, since each will
# need to be addressed individually for unsealing.
resource "aws_security_group_rule" "vault-http-api" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 8200
    to_port = 8200
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault-egress" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}

# Launch the ELB that is serving Vault. This has proper health checks
# to only serve healthy, unsealed Vaults.
resource "aws_elb" "vault" {
    name = "vault"
    connection_draining = true
    connection_draining_timeout = 400
    internal = false
    subnets = ["${var.subnets}"]
    security_groups = ["${aws_security_group.elb.id}"]
    instances = ["${aws_instance.vault-a.id}"]

    listener {
        instance_port = 8200
        instance_protocol = "tcp"
        lb_port = 80
        lb_protocol = "tcp"
    }

    listener {
        instance_port = 8200
        instance_protocol = "tcp"
        lb_port = 443
        lb_protocol = "tcp"
    }

    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 3
        timeout = 5
        target = "${var.elb-health-check}"
        interval = 15
    }
}

resource "aws_security_group" "elb" {
    name = "vault-elb"
    description = "Vault ELB"
    vpc_id = "${var.vpc-id}"
}

resource "aws_security_group_rule" "vault-elb-http" {
    security_group_id = "${aws_security_group.elb.id}"
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault-elb-https" {
    security_group_id = "${aws_security_group.elb.id}"
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault-elb-egress" {
    security_group_id = "${aws_security_group.elb.id}"
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}

# IAM role to use for the instanceprofile
resource "aws_iam_role" "iam_instance_role" {
  name = "vault-ir"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# policy for the instanceprofile
# TODO: need to limit this policy
resource "aws_iam_role_policy" "iam_instance_rolepolicy" {
  name = "vault-ir-policy"
  role = "${aws_iam_role.iam_instance_role.id}"

  policy = <<EOF
{
    "Statement": [
        {
            "Action": [
                "*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

# iam role for the test instance
resource "aws_iam_role" "testing_iam_instance_role" {
  name = "testing-vault-ir"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# policy for the test instance
# TODO: test instance policy should be limited as well
resource "aws_iam_role_policy" "testing_iam_instance_rolepolicy" {
  name = "testing-vault-ir-policy"
  role = "${aws_iam_role.testing_iam_instance_role.id}"

  policy = <<EOF
{
    "Statement": [
        {
            "Action": [
                "*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

# create the actual instance profiles.  These get attached in the "aws_instance" blocks
resource "aws_iam_instance_profile" "asg_instance_profile" {
  name = "vault-profile"
  role = "${aws_iam_role.iam_instance_role.name}"
}

resource "aws_iam_instance_profile" "test_instance_profile" {
  name = "test-vault-profile"
  role = "${aws_iam_role.testing_iam_instance_role.name}"
}