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