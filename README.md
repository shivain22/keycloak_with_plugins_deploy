# Keycloak (latest) + Postgres (Docker Compose)

This repo provides a minimal `docker-compose.yml` that runs:

- Keycloak (`quay.io/keycloak/keycloak:latest`)
- Postgres (default `postgres:16`)

Keycloak waits for Postgres using a Postgres `healthcheck` + `depends_on: condition: service_healthy`.

## Usage

1. Create your `.env`:

- Copy `env.template` (or `env.example`) to `.env`
- Adjust values as needed (ports, admin password, DB password, versions)

2. Start (build artifacts first, then Postgres, then Keycloak):

**Option A: Using the start script (recommended)**

- **Linux/macOS:** `./start.sh`
- **Windows:** `.\start.ps1`

Optional flags:
- `--rebuild` / `-rebuild`: Force rebuild of artifacts image
- `--logs` / `-logs`: Tail Keycloak logs after start

**Option B: Manual start**

```bash
docker compose up --build -d
```

3. Open Keycloak:

- `http://localhost:8080`
- Admin console: `http://localhost:8080/admin`

## Artifact build (providers) flow

When you run `docker compose up --build`, an `artifacts` one-shot container runs first:

- Installs Maven/Java/Node in the container
- Clones and builds:
  - `keycloak-phone-provider` (copies `keycloak-phone-provider.jar` and `keycloak-phone-provider-msg91.jar`)
  - `rms-auth-theme-plugin` (builds Keycloakify jars and copies `THEME_JAR_NAME`, default `keycloak-theme-for-kc-26.2-and-above.jar`)
- Cleans and populates `./providers/`

Keycloak mounts `./providers/` into `/opt/keycloak/providers` and starts after the build succeeds.

## Environment variables

See `env.template` for defaults:

- `KEYCLOAK_IMAGE`, `KEYCLOAK_VERSION`
- `POSTGRES_IMAGE`, `POSTGRES_VERSION`
- `KC_DB_NAME`, `KC_DB_USERNAME`, `KC_DB_PASSWORD`
- `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`
 - `PHONE_PROVIDER_REPO_URL`, `PHONE_PROVIDER_BRANCH`
 - `THEME_REPO_URL`, `THEME_BRANCH`, `THEME_JAR_NAME`
 - `SPI_PHONE_*` (phone provider SPI config used on Keycloak startup)


