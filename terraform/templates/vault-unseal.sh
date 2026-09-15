#!/usr/bin/env bash
set -euo pipefail
INIT_FILE="${VAULT_DIR:-/opt/vault}/init.json"
[ -f "$INIT_FILE" ] || { echo "vault-unseal: $INIT_FILE not found, nothing to do"; exit 0; }

vault_cli() { docker exec vault vault "$@"; }

for _ in $(seq 1 60); do
  status=0; vault_cli status >/dev/null 2>&1 || status=$?
  case "$status" in
    0) echo "vault-unseal: already unsealed"; exit 0 ;;
    2) key="$(jq -r '.unseal_keys_b64[0]' "$INIT_FILE")"
       vault_cli operator unseal "$key" >/dev/null && { echo "vault-unseal: unsealed"; exit 0; } ;;
  esac
  sleep 5
done
echo "vault-unseal: vault did not become available" >&2
exit 1
