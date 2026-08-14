# Backup Vaultwarden com Senha Determinística

## Visão Geral

Sistema de backup automático para Vaultwarden que gera senhas **determinísticas** a partir do nome do arquivo + uma seed secreta. Permite recuperar o banco de dados de qualquer lugar usando apenas o nome do arquivo e a seed.

## Como Funciona

1. **Determinístico:** Mesma senha toda vez para o mesmo arquivo
2. **Seguro:** Usa SHA256 + seed forte + OpenSSL AES-256-CBC
3. **Portável:** Recuperar sem o servidor original
4. **Automatizado:** Cron executa diariamente

### Fluxo

```
Nome arquivo: vaultwarden-backup-20260814.sqlite3.enc
Seed: sua_seed_super_secreta_2026

SHA256(nome + seed) → 32 primeiros chars
↓
Senha: a3f2b1c9d8e7f6g5h4i3j2k1l0m9n8o

OpenSSL AES-256-CBC encripta database com essa senha
```

## Instalação

### 1. Criar arquivo de seed

```bash
nano ~/homelab/backup/.backup-seed
```

Coloca uma seed forte (20+ caracteres, mix tudo):

```
sua_seed_super_secreta_e_forte_aqui_2026
```

**Protege o arquivo:**

```bash
chmod 600 ~/homelab/backup/.backup-seed
```

### 2. Criar scripts de backup

```bash
nano ~/homelab/backup/backup-vaultwarden.sh
nano ~/homelab/backup/recuperar-vaultwarden.sh
nano ~/homelab/backup/gerar-senha.sh
```

Copia os scripts (ver seção Scripts).

Faz executáveis:

```bash
chmod +x ~/homelab/backup/*.sh
```

### 3. Configurar cron

```bash
crontab -e
```

Adiciona:

```bash
# Backup Vaultwarden todo dia às 3 AM
0 3 * * * ~/homelab/backup/backup-vaultwarden.sh
```

## Scripts

### backup-vaultwarden.sh

```bash
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

# Fazer backup
if [ ! -f "$DB_PATH" ]; then
    echo "[ERROR] Database não encontrado: $DB_PATH" | tee -a "$LOG_FILE"
    exit 1
fi

openssl enc -aes-256-cbc -pbkdf2 -salt -in "$DB_PATH" -out "$BACKUP_DIR/$BACKUP_FILE" -k "$PASSWORD" -P

# Log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] OK Backup criado: $BACKUP_FILE" | tee -a "$LOG_FILE"

# Limpeza: manter últimos 30 backups
BACKUPS=$(ls -1 "$BACKUP_DIR"/vaultwarden-backup-*.sqlite3.enc 2>/dev/null | wc -l)
if [ "$BACKUPS" -gt 30 ]; then
    ls -1t "$BACKUP_DIR"/vaultwarden-backup-*.sqlite3.enc | tail -n +31 | xargs rm -f
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backups antigos removidos (mantém últimos 30)" | tee -a "$LOG_FILE"
fi
```

### recuperar-vaultwarden.sh

```bash
#!/bin/bash

# ========================================
# Recuperar Vaultwarden de backup
# Usa OpenSSL AES-256-CBC para desencriptação
# Uso: ./recuperar-vaultwarden.sh vaultwarden-backup-20260814.sqlite3.enc
# ========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_FILE="$SCRIPT_DIR/.backup-seed"
BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "Uso: $0 <arquivo_backup.enc>"
    echo ""
    echo "Exemplo:"
    echo "  $0 backups/vaultwarden-backup-20260814.sqlite3.enc"
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
openssl enc -aes-256-cbc -pbkdf2 -d -in "$BACKUP_FILE" -out db.sqlite3 -k "$PASSWORD"

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
```

### gerar-senha.sh

```bash
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
```

## Estrutura de Diretórios

```
~/homelab/backup/
├── README.md
├── .backup-seed (NÃO COMMITAR)
├── .gitignore
├── backup-vaultwarden.sh
├── recuperar-vaultwarden.sh
├── gerar-senha.sh
├── backup.log
└── backups/
    ├── vaultwarden-backup-20260814.sqlite3.enc
    ├── vaultwarden-backup-20260815.sqlite3.enc
    └── ...
```

## Uso

### Backup automático (cron)

Já configurado, executa todo dia às 3 AM.

Verifica logs:

```bash
tail -f ~/homelab/backup/backup.log
```

### Backup manual

```bash
~/homelab/backup/backup-vaultwarden.sh
```

### Recuperar backup

```bash
cd ~/homelab/backup
./recuperar-vaultwarden.sh backups/vaultwarden-backup-20260814.sqlite3.enc
```

### Gerar senha manualmente

```bash
~/homelab/backup/gerar-senha.sh vaultwarden-backup-20260814.sqlite3.enc
```

## Encriptação

### OpenSSL AES-256-CBC com PBKDF2

- **Algoritmo:** AES-256-CBC (padrão militar)
- **Derivação de chave:** PBKDF2 (mais seguro que MD5)
- **Salt:** Gerado automaticamente
- **Extensão:** `.enc` (encrypted)

### Verificar integridade do backup

```bash
ls -lh ~/homelab/backup/backups/
file ~/homelab/backup/backups/vaultwarden-backup-20260814.sqlite3.enc
```

## Segurança

### O que guardar

- Arquivo `.backup-seed` (guardado seguro, NÃO no GitHub)
- Arquivos `.enc` (encriptados, podem ir pra nuvem)
- Scripts (público no GitHub)

### O que NÃO guardar

- `.backup-seed` no GitHub
- Database original (`db.sqlite3`)

### .gitignore

```bash
.backup-seed
backup.log
backups/
db.sqlite3
*.enc
```

## Recuperação de Emergência

Se perder o servidor inteiro:

1. Pega o arquivo `.enc` do backup (Google Drive, GitHub, etc)
2. Copia `gerar-senha.sh` e `.backup-seed` localmente
3. Roda: `./gerar-senha.sh vaultwarden-backup-20260814.sqlite3.enc`
4. Copia a senha gerada
5. Desencripta: `openssl enc -aes-256-cbc -pbkdf2 -d -in vaultwarden-backup-20260814.sqlite3.enc -out db.sqlite3 -k "senha_aqui"`
6. Restaura num novo Vaultwarden

## Cron Configuration

```bash
crontab -e
```

Adiciona:

```bash
0 3 * * * /home/menegas/homelab/backup/backup-vaultwarden.sh
```

## Troubleshooting

### Erro: "Arquivo de seed não encontrado"

```bash
ls -la ~/homelab/backup/.backup-seed

# Se não existe:
nano ~/homelab/backup/.backup-seed
chmod 600 ~/homelab/backup/.backup-seed
```

### Erro: "Database não encontrado"

Verifica path no script — deve ser `$HOME/homelab/vaultwarden/data/db.sqlite3`

### Erro ao desencriptar

Senha incorreta. Regera usando `gerar-senha.sh`:

```bash
./gerar-senha.sh vaultwarden-backup-20260814.sqlite3.enc
```

## Notas

- Seed é determinística: sempre gera mesma senha pro mesmo arquivo
- OpenSSL usa AES-256-CBC + PBKDF2: padrão forte
- Mantém últimos 30 backups automaticamente
- Log registra todo backup realizado
- Extensão `.enc` identifica arquivos encriptados