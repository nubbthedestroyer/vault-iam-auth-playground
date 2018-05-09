output "vault_instance_address" {
  value       = "${module.vault.vault_address}"
  description = "endpoint to connect to the vault instance through the created ELB"
}

output "vault_instance_connect_string" {
  value = "${module.vault.vault_connect_string}"
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
  value = "${module.vault.test_instance_connect_string}"
}
