output "address" {
  value = "${aws_elb.vault.dns_name}"
}

output "vault_instance_ip" {
  value = "${aws_instance.vault-a.public_ip}"
}

// Can be used to add additional SG rules to Vault instances.
output "vault_security_group" {
  value = "${aws_security_group.vault.id}"
}

// Can be used to add additional SG rules to the Vault ELB.
output "elb_security_group" {
  value = "${aws_security_group.elb.id}"
}

output "test_instance_ip" {
  value = "${aws_instance.vault-test-instance.public_ip}"
}

output "test_instance_profile_arn" {
  value = "${aws_iam_instance_profile.test_instance_profile.arn}"
}


