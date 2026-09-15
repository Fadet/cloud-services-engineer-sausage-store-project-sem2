variable "yc_token" {
  type      = string
  default   = null
  sensitive = true
}

variable "cloud_id" {
  type    = string
  default = null
}

variable "folder_id" {
  type    = string
  default = null
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

variable "ssh_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "vault_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "vm_name" {
  type    = string
  default = "sausage-store-vault"
}

variable "vm_platform_id" {
  type    = string
  default = "standard-v3"
}

variable "vm_cores" {
  type    = number
  default = 2
}

variable "vm_core_fraction" {
  type    = number
  default = 20
}

variable "vm_memory_gb" {
  type    = number
  default = 2
}

variable "vm_disk_gb" {
  type    = number
  default = 20
}

variable "vm_image_family" {
  type    = string
  default = "ubuntu-2204-lts"
}

variable "vm_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "vault_image" {
  type    = string
  default = "hashicorp/vault:1.17"
}

variable "vault_kv_mount" {
  type    = string
  default = "kv"
}

variable "vault_secret_path" {
  type    = string
  default = "sausage-store"
}

variable "vault_token_ttl" {
  type    = string
  default = "87600h"
}

variable "postgres_user" {
  type    = string
  default = "store"
}

variable "mongo_root_user" {
  type    = string
  default = "root"
}

variable "mongo_app_user" {
  type    = string
  default = "reports"
}

variable "mongo_app_database" {
  type    = string
  default = "sausage-store"
}
