# identity-and-access-management

Keycloak deployed on [Fly.io](https://fly.io) with Docker and PostgreSQL.

## Deploy

### Prerequisites

- [Fly CLI](https://fly.io/docs/flyctl/install/) installed and authenticated (`fly auth login`)

### 1. Create the app (first time only)

```bash
fly apps create identity-and-access-management
```

### 2. Set secrets (database + admin credentials)

```bash
fly secrets set \
  KC_DB_URL="jdbc:postgresql://<HOST>:<PORT>/<DATABASE>" \
  KC_DB_USERNAME="<USERNAME>" \
  KC_DB_PASSWORD="<PASSWORD>" \
  KC_BOOTSTRAP_ADMIN_USERNAME="admin" \
  KC_BOOTSTRAP_ADMIN_PASSWORD="<ADMIN_PASSWORD>" \
  KC_HOSTNAME="https://identity-and-access-management.fly.dev" \
  KC_PROXY_HEADERS="xforwarded"
```

### 3. Deploy

```bash
fly deploy
```

### 4. Access

- App: https://identity-and-access-management.fly.dev
- Admin Console: https://identity-and-access-management.fly.dev/admin
- Health check: https://identity-and-access-management.fly.dev/health/ready