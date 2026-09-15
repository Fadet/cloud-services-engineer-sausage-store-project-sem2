output "vault_public_ip" {
  value = yandex_vpc_address.vault.external_ipv4_address[0].address
}

output "vault_addr" {
  value = "http://${yandex_vpc_address.vault.external_ipv4_address[0].address}:8200"
}

output "ssh_command" {
  value = "ssh ${var.vm_user}@${yandex_vpc_address.vault.external_ipv4_address[0].address}"
}

output "next_steps" {
  value = <<-EOT
    1. Дождитесь окончания cloud-init (2-4 мин):  ssh ${var.vm_user}@${yandex_vpc_address.vault.external_ipv4_address[0].address} 'cloud-init status --wait; sudo tail -20 /var/log/vault-bootstrap.log'
    2. Токен для CI/бэкенда:                      ssh ${var.vm_user}@${yandex_vpc_address.vault.external_ipv4_address[0].address} 'sudo cat /opt/vault/${var.vault_secret_path}.token'
    3. В GitHub: variable VAULT_HOST=${yandex_vpc_address.vault.external_ipv4_address[0].address}, secret VAULT_TOKEN=<токен из п.2>
    4. Сгенерированные пароли:                    ssh ${var.vm_user}@${yandex_vpc_address.vault.external_ipv4_address[0].address} 'sudo /opt/vault/bin/vault-bootstrap.sh show'
  EOT
}
