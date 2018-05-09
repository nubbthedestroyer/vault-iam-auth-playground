ui = true

storage "dynamodb" {
  ha_enabled = "true"
  region = "us-east-1"
  table = "Vault-Backend"
  advertise_addr = "http://127.0.0.1:8200"
  cluster_addr = "http://127.0.0.1:8201"
  recovery_mode = 1
  tls_disable = 1
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

