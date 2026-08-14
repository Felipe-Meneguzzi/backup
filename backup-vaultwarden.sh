#!/bin/bash

# ========================================
# Backup Vaultwarden com senha determinística
# Usa OpenSSL AES-256-CBC para encriptação
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
BACKUP_FILE="vaultwarden-backup-${DATE}.sqlite3.enc"

# Criar diretório de backups se não existir
mkdir -p "$BACKUP_DIR"

# Gerar senha determinística (32 chars)
PASSWORD=$(echo -n "${BACKUP_FILE}${SEED}" | sha256sum | cut -c1-32)

# Verificar se database existe
if [ ! -f "$DB_PATH" ]; then
    echo "[ERROR] Database não encontrado: $DB_PATH" | tee -a "$LOG_FILE"
    exit 1
fi

# Parar Vaultwarden antes do backup
echo "[*] Parando Vaultwarden..." | tee -a "$LOG_FILE"
docker compose -f $HOME/homelab/vaultwarden/docker-compose.yml stop

# Aguardar um pouco pra ter certeza
sleep 2

# Fazer backup
openssl enc -aes-256-cbc -pbkdf2 -salt -in "$DB_PATH" -out "$BACKUP_DIR/$BACKUP_FILE" -k "$PASSWORD" -P

# Subir Vaultwarden de novo
echo "[*] Subindo Vaultwarden..." | tee -a "$LOG_FILE"
docker compose -f $HOME/homelab/vaultwarden/docker-compose.yml up -d

# Log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] OK Backup criado: $BACKUP_FILE" | tee -a "$LOG_FILE"

# Limpeza: manter últimos 30 backups
BACKUPS=$(ls -1 "$BACKUP_DIR"/vaultwarden-backup-*.sqlite3.enc 2>/dev/null | wc -l)
if [ "$BACKUPS" -gt 30 ]; then
    ls -1t "$BACKUP_DIR"/vaultwarden-backup-*.sqlite3.enc | tail -n +31 | xargs rm -f
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backups antigos removidos (mantém últimos 30)" | tee -a "$LOG_FILE"
fi