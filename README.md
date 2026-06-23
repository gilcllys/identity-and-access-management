# identity-and-access-management

Keycloak 26.6 rodando em uma instância **AWS EC2** (Ubuntu 26.04 LTS), com PostgreSQL 16 via Docker Compose e Nginx como proxy reverso SSL no host.

Atua como provedor de identidade (IdP) central para os projetos pessoais — atualmente integrado ao [Financial-System](https://github.com/gilcllys/Financial-System).

## Arquitetura

```
Internet
   │
   ▼
EC2 Host (Ubuntu 26.04)
   │
   ├── Nginx (host)
   │     ├── :80  → redirect HTTPS
   │     ├── :443 → proxy → Keycloak :8080  (IAM)
   │     └── :4200 → proxy → Financial System (Angular :3000 / Django :8000)
   │
   └── Docker Compose
         ├── keycloak  (quay.io/keycloak/keycloak:26.6 — imagem pré-compilada)
         │     └── porta interna: 127.0.0.1:8080
         └── postgres  (postgres:16)
               └── volume persistente: postgres_data
```

### Detalhes de implementação

| Componente | Detalhe |
|---|---|
| Keycloak | 26.6.3, modo `start --optimized` (Quarkus pré-compilado em 2 stages) |
| Banco | PostgreSQL 16, acesso interno via rede Docker, sem porta exposta ao host |
| SSL | Certificados em `certs/fullchain.pem` e `certs/privkey.pem` (TLSv1.2 / TLSv1.3) |
| Proxy | Nginx no host com `proxy_headers=xforwarded` e buffers de 256k para o Keycloak |
| CI/CD | GitHub Actions — push em `main` faz deploy via SSH + gera `.env` a partir de secrets/variables |

## Estrutura do repositório

```
identity-and-access-management/
├── Dockerfile              # Build multi-stage: builder (kc.sh build) + runtime
├── docker-compose.yaml     # Serviços: keycloak + postgres
├── nginx/
│   └── host-proxy.conf     # Config do Nginx do host EC2 (proxy reverso)
├── scripts/
│   └── setup-ec2-nginx.sh  # Script de setup inicial do Nginx no EC2
├── certs/                  # Certificados SSL (gitignored)
│   ├── fullchain.pem
│   └── privkey.pem
├── .env                    # Variáveis de ambiente (gitignored — gerado pelo CI)
├── .env.example            # Template com todas as variáveis necessárias
└── .github/
    └── workflows/
        └── deploy.yml      # Pipeline de deploy automático para o EC2
```

## Variáveis de ambiente

Copie `.env.example` para `.env` e preencha os valores:

```bash
cp .env.example .env
```

| Variável | Descrição |
|---|---|
| `KC_DB` | Tipo do banco — use `postgres` |
| `KC_DB_URL` | JDBC URL do PostgreSQL (`jdbc:postgresql://postgres:5432/keycloak`) |
| `KC_DB_USERNAME` | Usuário do banco |
| `KC_DB_PASSWORD` | Senha do banco (usada pelo Keycloak via `env_file`) |
| `POSTGRES_PASSWORD` | Senha do container postgres — **deve ser igual a `KC_DB_PASSWORD`**. Variável separada para evitar que o docker-compose expanda `$` em valores durante a substituição YAML |
| `KC_BOOTSTRAP_ADMIN_USERNAME` | Usuário admin inicial do Keycloak |
| `KC_BOOTSTRAP_ADMIN_PASSWORD` | Senha admin inicial |
| `KC_HTTP_ENABLED` | `true` — HTTP habilitado internamente (HTTPS termina no Nginx) |
| `KC_HOSTNAME_STRICT` | `false` — permite acesso pelo IP/hostname do EC2 |
| `KC_PROXY_HEADERS` | `xforwarded` — Keycloak lê os headers `X-Forwarded-*` do Nginx |
| `KC_HOSTNAME` | URL pública completa (ex: `https://ec2-xx-xx.compute-1.amazonaws.com`) |

> **⚠️ Atenção com `$` nas senhas:** senhas contendo `$` (ex: `K9mP7$abc`) são expandidas pelo docker-compose ao ler variáveis YAML. Use `POSTGRES_PASSWORD` com uma senha sem `$`, ou escape com `$$`.

## Setup inicial do EC2

Execute uma única vez após provisionar a instância:

```bash
# 1. Clone o repositório
git clone https://github.com/gilcllys/identity-and-access-management.git
cd identity-and-access-management

# 2. Adicione os certificados SSL
mkdir -p certs
# Copie fullchain.pem e privkey.pem para ./certs/

# 3. Configure o Nginx do host
bash scripts/setup-ec2-nginx.sh

# 4. Crie o .env (ou deixe o CI gerar automaticamente no próximo deploy)
cp .env.example .env
# Edite .env com os valores reais

# 5. Suba os containers
docker compose up -d --build
```

## CI/CD — Deploy automático

Todo push na branch `main` dispara o pipeline `.github/workflows/deploy.yml`:

1. Conecta no EC2 via SSH (usando o secret `EC2_SSH_KEY`)
2. **Gera o `.env`** a partir dos GitHub Secrets e Variables (o arquivo não é commitado)
3. Faz `git pull origin main`
4. Executa `docker compose up -d --build`
5. Recarrega o Nginx (`nginx -t && systemctl reload nginx`)

### Secrets necessários (Settings → Secrets and variables → Actions → Secrets)

| Secret | Descrição |
|---|---|
| `EC2_SSH_KEY` | Chave privada SSH para acesso ao EC2 |
| `KC_DB_PASSWORD` | Senha do banco Keycloak |
| `KC_BOOTSTRAP_ADMIN_PASSWORD` | Senha do admin Keycloak |

### Variables necessárias (Settings → Secrets and variables → Actions → Variables)

| Variable | Exemplo |
|---|---|
| `EC2_HOST` | `ec2-xx-xx-xx-xx.compute-1.amazonaws.com` |
| `EC2_USER` | `ubuntu` |
| `EC2_PROJECT_PATH` | `/home/ubuntu/identity-and-access-management` |
| `KC_DB` | `postgres` |
| `KC_DB_USERNAME` | `keycloak` |
| `KC_BOOTSTRAP_ADMIN_USERNAME` | `admin` |
| `KC_HTTP_ENABLED` | `true` |
| `KC_HOSTNAME_STRICT` | `false` |
| `KC_PROXY_HEADERS` | `xforwarded` |
| `KC_HOSTNAME` | `https://ec2-xx-xx.compute-1.amazonaws.com` |

## Endpoints

| URL | Descrição |
|---|---|
| `https://<EC2_HOST>/` | Keycloak — tela de login |
| `https://<EC2_HOST>/admin` | Console de administração |
| `https://<EC2_HOST>/realms/master` | Realm master |
| `https://<EC2_HOST>/health/ready` | Health check |
| `https://<EC2_HOST>:4200/` | Financial System (Angular) |
| `https://<EC2_HOST>:4200/api/` | Financial System API (Django) |

## Desenvolvimento local

Para rodar localmente sem SSL:

```bash
# Ajuste o .env para desenvolvimento
KC_HOSTNAME=http://localhost:8080
KC_HOSTNAME_STRICT=false

docker compose up -d --build
# Acesse: http://localhost:8080
```