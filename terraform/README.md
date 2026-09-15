# Vault на Yandex Cloud

Terraform поднимает одну VM в Yandex Cloud и разворачивает на ней HashiCorp Vault в Docker.
Vault хранит секреты бэкенда (`kv/sausage-store`): их читают Spring Cloud Vault в рантайме
и GitHub Actions при деплое.

## Что создаётся

| Ресурс | Имя | Назначение |
|---|---|---|
| `yandex_vpc_network` | `<vm_name>-net` | сеть |
| `yandex_vpc_subnet` | `<vm_name>-subnet` | подсеть `subnet_cidr` в зоне `zone` |
| `yandex_vpc_security_group` | `<vm_name>-sg` | 22/tcp из `ssh_allowed_cidrs`, 8200/tcp из `vault_allowed_cidrs`, любой исходящий |
| `yandex_vpc_address` | `<vm_name>-ip` | статический публичный IP — значение `VAULT_HOST` не меняется при пересоздании VM |
| `yandex_compute_instance` | `<vm_name>` | Ubuntu 22.04, cloud-init из `templates/cloud-init.yaml.tftpl` |

На VM cloud-init:

1. ставит Docker из официального репозитория;
2. запускает контейнер `vault_image` через `/opt/vault/docker-compose.yml`
   (конфиг `/opt/vault/config/vault.hcl`, file-хранилище `/opt/vault/data`, HTTP на 8200);
3. выполняет `/opt/vault/bin/vault-bootstrap.sh`;
4. включает `vault-unseal.service` — после перезагрузки VM Vault распечатывается автоматически.

### vault-bootstrap.sh

Идемпотентный: повторный запуск ничего не перезаписывает.

| Шаг | Результат |
|---|---|
| `vault operator init` (1 ключ) | `/opt/vault/init.json` — ключ распечатывания и root-токен, `chmod 600` |
| unseal | через `vault-unseal.sh` |
| KV v2 | точка монтирования `vault_kv_mount` (по умолчанию `kv`) |
| политика `vault_secret_path` | только чтение `kv/data/sausage-store` и `kv/metadata/sausage-store` |
| токен | orphan, политики `default` + `sausage-store`, TTL `vault_token_ttl` → `/opt/vault/sausage-store.token` |
| секреты | `spring.datasource.username`, `spring.datasource.password`, `spring.data.mongodb.uri`, `mongodb.root.password` — пароли случайные, создаются только если секрета ещё нет |

`vault-bootstrap.sh show` — показать токен и текущие секреты.

## Требования

- Terraform ≥ 1.5, `yc` CLI с настроенным профилем (`yc init`);
- публичный SSH-ключ (`ssh_public_key_path`);
- зеркало провайдера при `terraform init` из России — `~/.terraformrc`:

```hcl
provider_installation {
  network_mirror {
    url     = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
```

## Запуск

```bash
cp terraform.tfvars.example terraform.tfvars      # файл в .gitignore
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

terraform init
terraform plan
terraform apply
terraform output next_steps
```

После `apply` подождите окончания cloud-init (2–4 минуты):

```bash
ssh ubuntu@$(terraform output -raw vault_public_ip) 'cloud-init status --wait; sudo tail -20 /var/log/vault-bootstrap.log'
```

## Переменные

| Переменная | По умолчанию | Описание |
|---|---|---|
| `yc_token` | `null` → `YC_TOKEN` | OAuth/IAM-токен Yandex Cloud |
| `cloud_id` | `null` → `YC_CLOUD_ID` | ID облака |
| `folder_id` | `null` → `YC_FOLDER_ID` | ID каталога |
| `zone` | `ru-central1-a` | зона доступности |
| `subnet_cidr` | `10.10.0.0/24` | CIDR подсети |
| `ssh_allowed_cidrs` | `["0.0.0.0/0"]` | откуда разрешён SSH; рекомендуется сузить до своего IP |
| `vault_allowed_cidrs` | `["0.0.0.0/0"]` | откуда разрешён Vault API; нужен кластеру и раннерам GitHub |
| `vm_name` | `sausage-store-vault` | имя VM и префикс сетевых ресурсов |
| `vm_platform_id` | `standard-v3` | платформа |
| `vm_cores` / `vm_core_fraction` | `2` / `20` | vCPU и гарантированная доля, % |
| `vm_memory_gb` / `vm_disk_gb` | `2` / `20` | память и диск, ГБ |
| `vm_image_family` | `ubuntu-2204-lts` | семейство образа |
| `vm_user` | `ubuntu` | пользователь SSH |
| `ssh_public_key_path` | `~/.ssh/id_ed25519.pub` | публичный ключ |
| `vault_image` | `hashicorp/vault:1.17` | образ Vault |
| `vault_kv_mount` | `kv` | точка монтирования KV v2 (бэкенд: `vault://kv/sausage-store`) |
| `vault_secret_path` | `sausage-store` | путь секрета; равен `spring.application.name` |
| `vault_token_ttl` | `87600h` | TTL токена для CI/бэкенда |
| `postgres_user` | `store` | пользователь PostgreSQL |
| `mongo_root_user` | `root` | root-пользователь MongoDB |
| `mongo_app_user` | `reports` | прикладной пользователь MongoDB |
| `mongo_app_database` | `sausage-store` | база MongoDB |

## Outputs

| Output | Значение |
|---|---|
| `vault_public_ip` | публичный IP → GitHub variable `VAULT_HOST` |
| `vault_addr` | `http://<ip>:8200` |
| `ssh_command` | команда для подключения |
| `next_steps` | что сделать после `apply` |

## Подключение к проекту

```bash
IP=$(terraform output -raw vault_public_ip)
ssh ubuntu@$IP 'sudo cat /opt/vault/sausage-store.token'      # → GitHub secret VAULT_TOKEN
ssh ubuntu@$IP 'sudo /opt/vault/bin/vault-bootstrap.sh show'  # сгенерированные пароли
```

В GitHub: variable `VAULT_HOST=$IP`, secret `VAULT_TOKEN=<токен>`.
Проверка снаружи:

```bash
curl -s -H "X-Vault-Token: $VAULT_TOKEN" http://$IP:8200/v1/kv/data/sausage-store | jq '.data.data | keys'
```

## Эксплуатация

- **Ключ и root-токен** — `/opt/vault/init.json` на VM (только root). Сохраните копию вне VM:
  без ключа данные Vault восстановить нельзя.
- **Перезагрузка VM** — `vault-unseal.service` распечатывает Vault сам; проверить:
  `systemctl status vault-unseal` / `docker exec vault vault status`.
- **Сменить пароль** — `docker exec -i -e VAULT_TOKEN=<root> vault vault kv patch -mount=kv sausage-store spring.datasource.password=...`,
  затем изменить его в самой базе (PostgreSQL применяет пароль только при первой инициализации тома).
- **Изменения в шаблонах** не пересоздают VM (`ignore_changes` на `user-data`), чтобы не потерять данные Vault.
  Новую версию скрипта копируйте на VM вручную или пересоздавайте VM осознанно: `terraform taint yandex_compute_instance.vault`.
- **`terraform destroy`** удаляет VM вместе с данными Vault; статический IP тоже освобождается.

## Безопасность

Конфигурация учебная: Vault работает по HTTP (бэкенд настроен на `spring.cloud.vault.scheme=http`),
порт 8200 открыт по умолчанию для всех и защищён только токеном. Для продакшена нужны TLS,
ограничение `vault_allowed_cidrs`, auto-unseal через KMS вместо ключа на диске и отдельное хранилище
(Raft/Consul) с резервными копиями.
