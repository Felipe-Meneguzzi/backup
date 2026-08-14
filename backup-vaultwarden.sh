#!/bin/bash

# ========================================
# Backup Vaultwarden com senha determinística
# Pega seed de arquivo externo
# ========================================

set -e

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_FILE="$SCRIPT_DIR/.backup-seed"
DB_PATH="$HOME/homelab/vaultwarden/data/db.sqlite3"
BACKUP_DIR="$SCRIPT_DIR/backups"
LOG_FILE="$SCRIPT_DIR/backup.log"

# Verificar se seed existe
if [ ! -f "$SEED_FILE" ]; then
    echo "[ERROR] Arquivo de seed não encontrado: $SEED_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

# Ler seed
SEED=$(cat "$SEED_FILE" | tr -d '\n')

# Data
DATE=$(date +%Y%m%d)
BACKUP_FILE="vaultwarden-backup-${DATE}.sqlite3.gpg"

# Criar diretório de backups se não existir
mkdir -p "$BACKUP_DIR"

# Gerar senha determinística (32 chars)
PASSWORD=$(echo -n "${BACKUP_FILE}${SEED}" | sha256sum | cut -c1-32)

# Fazer backup
if [ ! -f "$DB_PATH" ]; then
    echo "[ERROR] Database não encontrado: $DB_PATH" | tee -a "$LOG_FILE"
    exit 1
fi

gpg --symmetric --cipher-algo AES256 --batch --passphrase "$PASSWORD" "$DB_PATH" -o "$BACKUP_DIR/$BACKUP_FILE"

# Log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] OK Backup criado: $BACKUP_FILE" | tee -a "$LOG_FILE"

# Limpeza: manter últimos 30 backups
BACKUPS=$(ls -1 "$BACKUP_DIR"/vaultwarden-backup-*.sqlite3.gpg 2>/dev/null | wc -l)
if [ "$BACKUPS" -gt 30 ]; then
    ls -1t "$BACKUP_DIR"/vaultwarden-backup-*.sqlite3.gpg | tail -n +31 | xargs rm -f
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backups antigos removidos (mantém últimos 30)" | tee -a "$LOG_FILE"
fi