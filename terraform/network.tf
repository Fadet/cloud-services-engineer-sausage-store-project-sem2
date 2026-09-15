resource "yandex_vpc_network" "vault" {
  name = "${var.vm_name}-net"
}

resource "yandex_vpc_subnet" "vault" {
  name           = "${var.vm_name}-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.vault.id
  v4_cidr_blocks = [var.subnet_cidr]
}

resource "yandex_vpc_address" "vault" {
  name = "${var.vm_name}-ip"

  external_ipv4_address {
    zone_id = var.zone
  }
}

resource "yandex_vpc_security_group" "vault" {
  name       = "${var.vm_name}-sg"
  network_id = yandex_vpc_network.vault.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = var.ssh_allowed_cidrs
  }

  ingress {
    protocol       = "TCP"
    port           = 8200
    v4_cidr_blocks = var.vault_allowed_cidrs
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
