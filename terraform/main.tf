data "yandex_compute_image" "ubuntu" {
  family = var.vm_image_family
}

locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    vm_user            = var.vm_user
    ssh_public_key     = local.ssh_public_key
    vault_image        = var.vault_image
    vault_kv_mount     = var.vault_kv_mount
    vault_secret_path  = var.vault_secret_path
    vault_token_ttl    = var.vault_token_ttl
    postgres_user      = var.postgres_user
    mongo_root_user    = var.mongo_root_user
    mongo_app_user     = var.mongo_app_user
    mongo_app_database = var.mongo_app_database
    vault_hcl          = file("${path.module}/templates/vault.hcl")
    docker_compose     = templatefile("${path.module}/templates/docker-compose.yml.tftpl", { vault_image = var.vault_image })
    bootstrap_sh       = file("${path.module}/templates/vault-bootstrap.sh")
    unseal_sh          = file("${path.module}/templates/vault-unseal.sh")
  })
}

resource "yandex_compute_instance" "vault" {
  name        = var.vm_name
  platform_id = var.vm_platform_id
  zone        = var.zone
  hostname    = var.vm_name

  resources {
    cores         = var.vm_cores
    memory        = var.vm_memory_gb
    core_fraction = var.vm_core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.vm_disk_gb
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.vault.id
    nat                = true
    nat_ip_address     = yandex_vpc_address.vault.external_ipv4_address[0].address
    security_group_ids = [yandex_vpc_security_group.vault.id]
  }

  metadata = {
    ssh-keys  = "${var.vm_user}:${local.ssh_public_key}"
    user-data = local.user_data
  }

  lifecycle {
    ignore_changes = [metadata["user-data"]]
  }
}
