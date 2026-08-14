#!/bin/bash

# ========================================
# Recuperar Vaultwarden de backup
# Uso: ./recuperar-vaultwarden.sh vaultwarden-backup-20260814.sqlite3.gpg
# ========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_FILE="$SCRIPT_DIR/.backup-seed"
BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "Uso: $0 <arquivo_backup.gpg>"
    echo ""
    echo "Exemplo:"
    echo "  $0 backups/vaultwarden-backup-20260814.sqlite3.gpg"
    exit 1
fi

# Verificar arquivo
if [ ! -f "$BACKUP_FILE" ]; then
    echo "[ERROR] Arquivo não encontrado: $BACKUP_FILE"
    exit 1
fi

# Verificar seed
if [ ! -f "$SEED_FILE" ]; then
    echo "[ERROR] Arquivo de seed não encontrado: $SEED_FILE"
    exit 1
fi

# Ler seed
SEED=$(cat "$SEED_FILE" | tr -d '\n')

# Extrair nome do arquivo (pra gerar mesma senha)
FILENAME=$(basename "$BACKUP_FILE")

# Gerar senha determinística
PASSWORD=$(echo -n "${FILENAME}${SEED}" | sha256sum | cut -c1-32)

# Desencriptar
echo "[*] Desencriptando $FILENAME..."
gpg --decrypt --batch --passphrase "$PASSWORD" "$BACKUP_FILE" > db.sqlite3

if [ $? -eq 0 ]; then
    echo "[OK] Database recuperado em: db.sqlite3"
    echo ""
    echo "Para restaurar no servidor:"
    echo "  1. docker compose -f ~/homelab/vaultwarden/docker-compose.yml down"
    echo "  2. cp db.sqlite3 ~/homelab/vaultwarden/data/db.sqlite3"
    echo "  3. docker compose -f ~/homelab/vaultwarden/docker-compose.yml up -d"
else
    echo "[ERROR] Falha ao desencriptar (senha incorreta?)"
    exit 1
fi