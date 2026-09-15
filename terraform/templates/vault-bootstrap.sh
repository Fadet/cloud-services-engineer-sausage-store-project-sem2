#!/usr/bin/env bash
set -euo pipefail
. "${BOOTSTRAP_ENV:-/etc/vault-bootstrap.env}"

VAULT_DIR="${VAULT_DIR:-/opt/vault}"
INIT_FILE="$VAULT_DIR/init.json"
TOKEN_FILE="$VAULT_DIR/$SECRET_PATH.token"
LOG="${BOOTSTRAP_LOG:-/var/log/vault-bootstrap.log}"
umask 077

log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
vault_cli() { docker exec -i -e VAULT_TOKEN="${ROOT_TOKEN:-}" vault vault "$@"; }
rand_pw() { openssl rand -base64 24 | tr -d '/+=' | cut -c1-24; }

wait_for_vault() {
  for _ in $(seq 1 60); do
    status=0; docker exec vault vault status >/dev/null 2>&1 || status=$?
    [ "$status" -ne 1 ] && return 0   # 0 — unsealed, 2 — sealed: API отвечает
    sleep 5
  done
  log "Vault API is not reachable"; exit 1
}

wait_for_vault

if [ ! -f "$INIT_FILE" ]; then
  if docker exec vault vault status -format=json 2>/dev/null | jq -e '.initialized == true' >/dev/null; then
    log "Vault already initialized but $INIT_FILE is missing — cannot continue automatically"; exit 1
  fi
  docker exec vault vault operator init -key-shares=1 -key-threshold=1 -format=json > "$INIT_FILE"
  chmod 600 "$INIT_FILE"
  log "Vault initialized; unseal key and root token stored in $INIT_FILE (root only)"
fi
ROOT_TOKEN="$(jq -r '.root_token' "$INIT_FILE")"

"$VAULT_DIR/bin/vault-unseal.sh" | tee -a "$LOG"

if ! vault_cli secrets list -format=json | jq -e --arg m "$KV_MOUNT/" 'has($m)' >/dev/null; then
  vault_cli secrets enable -path="$KV_MOUNT" -version=2 kv
  log "KV v2 enabled at $KV_MOUNT/"
fi

vault_cli policy write "$SECRET_PATH" - <<POLICY >/dev/null
path "$KV_MOUNT/data/$SECRET_PATH"     { capabilities = ["read"] }
path "$KV_MOUNT/metadata/$SECRET_PATH" { capabilities = ["read", "list"] }
POLICY
log "Policy '$SECRET_PATH' written"

if [ ! -f "$TOKEN_FILE" ]; then
  vault_cli token create -policy="$SECRET_PATH" -display-name="$SECRET_PATH" \
    -orphan -ttl="$TOKEN_TTL" -format=json | jq -r '.auth.client_token' > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  log "Token for policy '$SECRET_PATH' created -> $TOKEN_FILE (use as GitHub secret VAULT_TOKEN)"
fi

if ! vault_cli kv get -mount="$KV_MOUNT" "$SECRET_PATH" >/dev/null 2>&1; then
  PG_PASS="$(rand_pw)"; MONGO_ROOT_PASS="$(rand_pw)"; MONGO_APP_PASS="$(rand_pw)"
  vault_cli kv put -mount="$KV_MOUNT" "$SECRET_PATH" \
    "spring.datasource.username=$POSTGRES_USER" \
    "spring.datasource.password=$PG_PASS" \
    "spring.data.mongodb.uri=mongodb://$MONGO_APP_USER:$MONGO_APP_PASS@mongodb:27017/$MONGO_APP_DATABASE" \
    "mongodb.root.password=$MONGO_ROOT_PASS" >/dev/null
  log "Secrets written to $KV_MOUNT/$SECRET_PATH with generated passwords"
else
  log "Secrets at $KV_MOUNT/$SECRET_PATH already exist — left untouched"
fi

if [ "${1:-}" = "show" ]; then
  echo "VAULT_TOKEN (GitHub secret): $(cat "$TOKEN_FILE")"
  vault_cli kv get -mount="$KV_MOUNT" "$SECRET_PATH"
fi
log "Bootstrap finished"
