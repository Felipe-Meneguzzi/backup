#!/bin/bash

# ========================================
# Gerar senha determinística manualmente
# Uso: ./gerar-senha.sh vaultwarden-backup-20260814.sqlite3.enc
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_FILE="$SCRIPT_DIR/.backup-seed"
FILENAME="$1"

if [ -z "$FILENAME" ]; then
    echo "Uso: $0 <nome_arquivo>"
    exit 1
fi

if [ ! -f "$SEED_FILE" ]; then
    echo "[ERROR] Arquivo de seed não encontrado: $SEED_FILE"
    exit 1
fi

SEED=$(cat "$SEED_FILE" | tr -d '\n')
PASSWORD=$(echo -n "${FILENAME}${SEED}" | sha256sum | cut -c1-32)

echo "Arquivo: $FILENAME"
echo "Senha:   $PASSWORD"