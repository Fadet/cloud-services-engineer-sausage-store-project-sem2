ui = true

storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

default_lease_ttl = "8760h"
max_lease_ttl     = "87600h"

api_addr = "http://127.0.0.1:8200"
disable_mlock = true
