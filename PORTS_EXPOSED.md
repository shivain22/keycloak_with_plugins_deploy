# Ports Exposed on Host Machine

This document lists all ports that are exposed on the host machine when running `docker compose up`.

## Summary

Yes, when you run `start.sh` or `fresh-start.sh`, the script will:
1. ✅ Generate realm configurations from templates
2. ✅ Clone repos and build Keycloak artifacts (providers/themes)
3. ✅ Clone gateway and service repos
4. ✅ Build Docker images using `mvnw clean package jib:build`
5. ✅ Push images to Docker Hub
6. ✅ Start all services with `docker compose up`

## Exposed Ports

### Application Ports

| Service | Container Port | Host Port (Default) | Environment Variable | Description |
|---------|---------------|---------------------|---------------------|-------------|
| **Gateway** | 8080 | **9293** | `GATEWAY_HTTP_PORT` | Gateway UI + Backend API (single port) |
| **Service** | 8080 | **9294** | `SERVICE_HTTP_PORT` | Service Backend API |
| **Keycloak** | 8080 | **9292** | `KEYCLOAK_HTTP_PORT` | Keycloak Authentication Server |

### Database Ports

| Service | Container Port | Host Port (Default) | Environment Variable | Description |
|---------|---------------|---------------------|---------------------|-------------|
| **Keycloak DB** | 5432 | **5434** | `POSTGRES_PORT` | PostgreSQL for Keycloak |
| **RMS PostgreSQL** | 5432 | **5435** | `RMS_POSTGRES_PORT` | Business Database (RMS) |

## Important Notes

### Gateway Port Configuration

The **Gateway** (rms-gateway) serves both:
- **Frontend UI** (React/Angular application)
- **Backend API** (Spring Boot Gateway)

Both are served on the **same port** (8080 inside container, 9293 on host by default).

- UI is typically served at: `http://localhost:9293/` (or your configured port)
- API endpoints are at: `http://localhost:9293/api/...`

This is standard for JHipster gateway applications - they serve the frontend as static files and proxy API requests.

### Service Port Configuration

The **Service** (rms-service) only exposes:
- **Backend API** on port 8080 (inside container), mapped to 9294 on host by default

### Port Mapping Format

All ports use the format: `"${ENV_VAR:-default}:container_port"`

You can override any port by setting the environment variable in your `.env` file.

## Example .env Configuration

```bash
# Application Ports (updated to avoid conflicts)
KEYCLOAK_HTTP_PORT=9292
GATEWAY_HTTP_PORT=9293
SERVICE_HTTP_PORT=9294

# Database Ports (updated to avoid conflicts)
POSTGRES_PORT=5434
RMS_POSTGRES_PORT=5435
```

## For Production/Reverse Proxy Setup

When setting up your reverse proxy (nginx/apache) for production:

1. **rmsgateway.atparui.com** → Map to host port `9293` (or your configured `GATEWAY_HTTP_PORT`)
2. **rmsservice.atparui.com** → Map to host port `9294` (or your configured `SERVICE_HTTP_PORT`)
3. **rmsauth.atparui.com** → Map to host port `9292` (or your configured `KEYCLOAK_HTTP_PORT`)
4. **rmsdashboard.atparui.com** → Map to host port `9293` (same as gateway, since gateway serves the UI)

### Important for Production

- The gateway serves both UI and API on the same port
- Your reverse proxy should route:
  - `/api/*` → Gateway backend API
  - `/*` → Gateway frontend UI
- All traffic goes through the same port (9293 by default)

## Verifying Ports

After starting, you can verify ports are exposed:

```bash
# Check exposed ports
docker compose ps

# Or check specific service
docker port rms-gateway
docker port rms-service
docker port keycloak
```

## Port Conflicts

If you have port conflicts, update your `.env` file:

```bash
# Example: Change gateway port to 9093
GATEWAY_HTTP_PORT=9093

# Example: Change service port to 9094
SERVICE_HTTP_PORT=9094

# Example: Change Keycloak port to 9092
KEYCLOAK_HTTP_PORT=9092
```

Then restart: `./start.sh`

