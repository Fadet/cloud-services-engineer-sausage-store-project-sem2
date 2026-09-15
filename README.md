# Sausage Store

![image](https://user-images.githubusercontent.com/9394918/121517767-69db8a80-c9f8-11eb-835a-e98ca07fd995.png)


## Technologies used

* Frontend – TypeScript, Angular.
* Backend  – Java 16, Spring Boot, Spring Data.
* Database – H2.

## Installation guide
### Backend

Install Java 16 and maven and run:

```bash
cd backend
mvn package
cd target
java -jar sausage-store-0.0.1-SNAPSHOT.jar
```

### Frontend

Install NodeJS and npm on your computer and run:

```bash
cd frontend
npm install
npm run build
npm install -g http-server
sudo http-server ./dist/frontend/ -p 80 --proxy http://localhost:8080
```

Then open your browser and go to [http://localhost](http://localhost)

## Deployment (Kubernetes, GitHub Actions)

Пайплайн `.github/workflows/deploy.yaml` запускается на push в `main` (или вручную через *Run workflow*):
сборка и публикация образов в Docker Hub → `helm lint`/`package` и загрузка чарта в Nexus →
`helm upgrade --install` чарта из Nexus в кластер.

### Что нужно настроить в GitHub

Secrets:

| Secret | Назначение |
|---|---|
| `DOCKER_USER`, `DOCKER_PASSWORD` | Docker Hub; образы публикуются как `<DOCKER_USER>/sausage-{backend,frontend,backend-report}` |
| `NEXUS_HELM_REPO` | полный URL hosted helm-репозитория Nexus (Deployment policy: *Allow redeploy*) |
| `NEXUS_HELM_REPO_USER`, `NEXUS_HELM_REPO_PASSWORD` | учётные данные Nexus |
| `KUBE_CONFIG` | kubeconfig кластера (raw YAML или base64) |
| `VAULT_TOKEN` | токен Vault с доступом к `kv/sausage-store` |

Variables:

| Variable | Назначение |
|---|---|
| `SAUSAGE_STORE_NAMESPACE` | namespace в кластере |
| `VAULT_HOST` | адрес Vault (доступен и из кластера, и с раннеров GitHub) |
| `VAULT_PORT`, `VAULT_SCHEME`, `VAULT_KV_PATH` | необязательно; по умолчанию `8200`, `http`, `kv/sausage-store` |

### Секреты в Vault

Единственный источник паролей БД — Vault. Бэкенд читает их в рантайме через Spring Cloud Vault,
CI — при деплое, чтобы передать в чарт значения для PostgreSQL, MongoDB и backend-report.
В `values.yaml` и в git паролей нет (шаблоны требуют их через `required`).

```bash
vault kv put kv/sausage-store \
  spring.datasource.username=store \
  spring.datasource.password='<pg-password>' \
  spring.data.mongodb.uri='mongodb://reports:<mongo-app-password>@mongodb:27017/sausage-store' \
  mongodb.root.password='<mongo-root-password>'
```

Spring Cloud Vault по умолчанию рассчитывает на KV v2; если движок `kv` смонтирован как v1,
задайте `backend.vault.kvVersion: "1"` в `values.yaml` (или `--set`).

Нюанс: PostgreSQL применяет пароль только при первой инициализации тома. Если сменить его в Vault
после первого деплоя, нужно либо изменить пароль в самой БД (`ALTER USER store PASSWORD '...'`),
либо пересоздать PVC `postgresql-data-postgresql-0`.

### Локальная проверка чарта

```bash
CHART="$PWD/sausage-store-chart"
docker run --rm -v "$CHART:/apps:ro" alpine/helm:3.14.0 lint /apps
docker run --rm -v "$CHART:/apps:ro" alpine/helm:3.14.0 template sausage-store /apps \
  --set backend.vault.token=x \
  --set infra.postgresql.env.POSTGRES_PASSWORD=x \
  --set infra.mongodb.env.MONGO_INITDB_ROOT_PASSWORD=x \
  --set infra.mongodb.app.password=x \
  --set backend-report.secret.db=x
```

### Проверка после деплоя

```bash
NS=<namespace>
helm list -n "$NS"
kubectl -n "$NS" get pods,svc,ingress,pvc,hpa,vpa
kubectl -n "$NS" describe vpa sausage-store-backend-vpa      # ожидается RecommendationProvided
kubectl -n "$NS" describe hpa sausage-store-backend-report-hpa  # Min 1 / Max 5 / cpu 75%
kubectl -n "$NS" logs deploy/sausage-store-backend | grep -i flyway   # Successfully applied 4 migrations
curl -s https://front-stepanovsn.2sem.students-projects.ru/api/products | head -c 300
```

## Vault на Yandex Cloud (Terraform bootstrap)

Каталог `terraform/` поднимает VM в Yandex Cloud с Vault в Docker и заполняет `kv/sausage-store`
случайными паролями. Описание ресурсов, переменных, запуск и эксплуатация — в [terraform/README.md](terraform/README.md).
После `terraform apply`: `VAULT_HOST` (GitHub variable) = `terraform output -raw vault_public_ip`,
`VAULT_TOKEN` (GitHub secret) = `ssh ubuntu@<ip> 'sudo cat /opt/vault/sausage-store.token'`.

## Результат

<!-- После зелёного прогона пайплайна добавьте сюда скриншоты (например, в readme-content/):
     - https://front-stepanovsn.2sem.students-projects.ru — витрина с продуктами;
     - оформленный заказ;
     - вывод `kubectl -n <ns> get pods,pvc,svc,ingress,hpa,vpa`;
     - `helm list -n <ns>` со STATUS deployed;
     - `kubectl describe vpa sausage-store-backend-vpa` с RecommendationProvided. -->
