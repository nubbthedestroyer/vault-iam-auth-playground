output "vault_address" {
  value       = "http://${module.vault.address}:80"
  description = "endpoint to connect to the vault instance through the created ELB"
}

output "vault_connect_string" {
  value = "ssh -i $${path_to_keypair} ubuntu@${module.vault.vault_instance_ip}"
}

//output "vault_security_group" {
//    value = "${module.vault.vault_security_group}"
//}

//output "elb_security_group" {
//    value = "${module.vault.elb_security_group}"
//}

output "test_instance_profile_arn" {
    value = "${module.vault.test_instance_profile_arn}"
}

output "test_instance_connect_string" {
  value = "ssh -i $${path_to_keypair} ubuntu@${module.vault.test_instance_ip}"
}