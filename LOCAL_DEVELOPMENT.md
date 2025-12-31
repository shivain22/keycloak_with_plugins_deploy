# Local Development Setup Guide

This guide explains how to run Gateway and Service locally on your laptop while connecting to **all** infrastructure services (PostgreSQL, Kafka, Consul, Elasticsearch, Keycloak) running on a remote server via **SSH tunneling**.

**Note:** All services on the server are secured behind Nginx with SSL and bound to localhost only. SSH tunneling is used for local development access.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Remote Server                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │PostgreSQL│  │  Kafka   │  │  Consul  │  │Keycloak  │  │
│  │  :5435   │  │  :9092   │  │  :8500   │  │  :8080   │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│  ┌──────────┐  ┌──────────┐                              │
│  │Elastic   │  │Zookeeper │                              │
│  │  :9200   │  │  :2181   │                              │
│  └──────────┘  └──────────┘                              │
└─────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │                    │                    │
         │ SSH Tunnel         │ DNS/Subdomain     │ DNS/Subdomain
         │ (PostgreSQL)       │ (Kafka, Consul)    │ (Keycloak)
         │                    │                    │
┌────────┴────────────────────┴────────────────────┴────────┐
│                    Your Laptop                              │
│  ┌──────────┐  ┌──────────┐                               │
│  │ Gateway  │  │ Service  │                               │
│  │ :8080    │  │ :8081    │                               │
│  └──────────┘  └──────────┘                               │
│                                                             │
│  SSH Tunnel: localhost:5433 → server:5435 (Gateway DB)     │
│  SSH Tunnel: localhost:5434 → server:5435 (Service DB)     │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Remote Server Setup:**
   - Infrastructure services running using `docker-compose-secure.yml` (all services bound to localhost)
   - Nginx configured with SSL certificates for subdomains
   - SSH access to the server
   - Services are NOT exposed to public internet (localhost only)

2. **Local Setup:**
   - Java 17+
   - Maven 3.6+
   - SSH client installed
   - Access to remote server via SSH

## Step 1: Configure Remote Server Services (Secure)

On the remote server, use `docker-compose-secure.yml` which binds all services to localhost:

```bash
cd keycloak_with_plugins_deploy
docker compose -f docker-compose-secure.yml up -d
```

**Key Security Features:**
- All services bind to `127.0.0.1` only (not accessible from outside)
- Services accessible via:
  - SSH tunnel (for local development)
  - Nginx with SSL (for external HTTPS access)

**Port Bindings (localhost only):**
- PostgreSQL: `127.0.0.1:5435:5432`
- Kafka: `127.0.0.1:9295:9092`
- Consul: `127.0.0.1:8500:8500`
- Elasticsearch: `127.0.0.1:9200:9200`
- Keycloak: `127.0.0.1:9292:8080`
- Zookeeper: `127.0.0.1:2181:2181`

## Step 2: Configure Nginx with SSL (Server Side)

See `SECURE_SETUP.md` for detailed Nginx configuration. Services are accessed via:
- **External access:** HTTPS through Nginx (e.g., `https://keycloak.your-domain.com`)
- **Local development:** SSH tunnels to localhost ports

**Note:** For local development, you don't need DNS entries - all services are accessed via SSH tunnels to `localhost`.

## Step 3: Configure SSH Tunnels (All Services)

The SSH tunnel configuration now supports **multiple tunnels** for all services:

### Option A: Using Password Authentication

```yaml
ssh:
  tunnel:
    enabled: true
    host: your-server.com
    port: 22
    username: your-username
    password: your-password
    
    # PostgreSQL Tunnel
    postgres:
      remote-host: localhost
      remote-port: 5435
      local-port: 5433  # Gateway uses 5433, Service uses 5434
    
    # Kafka Tunnel
    kafka:
      remote-host: localhost
      remote-port: 9295
      local-port: 9092
    
    # Consul Tunnel
    consul:
      remote-host: localhost
      remote-port: 8500
      local-port: 8500
    
    # Elasticsearch Tunnel
    elasticsearch:
      remote-host: localhost
      remote-port: 9200
      local-port: 9200
    
    # Keycloak Tunnel
    keycloak:
      remote-host: localhost
      remote-port: 9292
      local-port: 8080
```

### Option B: Using SSH Key Authentication (Recommended)

```yaml
ssh:
  tunnel:
    enabled: true
    host: your-server.com
    port: 22
    username: your-username
    private-key: /path/to/your/.ssh/id_rsa
    private-key-passphrase:  # Optional, if key is encrypted
    
    # All tunnel configurations as above...
```

## Step 4: Configure Application Properties

### Gateway Configuration (`rms/src/main/resources/config/application-local.yml`)

All services now connect via SSH tunnels to localhost:

```yaml
ssh:
  tunnel:
    enabled: true
    host: ${SSH_TUNNEL_HOST:your-server.com}
    username: ${SSH_TUNNEL_USERNAME:your-username}
    password: ${SSH_TUNNEL_PASSWORD:your-password}
    # OR use private key:
    # private-key: ${SSH_TUNNEL_PRIVATE_KEY:/path/to/.ssh/id_rsa}
    
    postgres:
      remote-port: 5435
      local-port: 5433
    kafka:
      remote-port: 9295
      local-port: 9092
    consul:
      remote-port: 8500
      local-port: 8500
    elasticsearch:
      remote-port: 9200
      local-port: 9200
    keycloak:
      remote-port: 9292
      local-port: 8080

spring:
  # All services connect to localhost (via SSH tunnels)
  cloud:
    consul:
      host: localhost  # Via SSH tunnel
      port: 8500
  kafka:
    bootstrap-servers: localhost:9092  # Via SSH tunnel
  elasticsearch:
    uris: http://localhost:9200  # Via SSH tunnel

security:
  oauth2:
    client:
      provider:
        oidc:
          issuer-uri: http://localhost:8080/realms/gateway  # Via SSH tunnel
```

### Service Configuration (`rms-service/src/main/resources/config/application-local.yml`)

Similar configuration, but note:
- Service uses `postgres.local-port: 5434` (different from Gateway's 5433)
- Service uses different Keycloak realm: `http://localhost:8080/realms/service`

## Step 5: Run Applications Locally

### Gateway

```bash
cd rms
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Or set environment variables:

```bash
export SPRING_PROFILES_ACTIVE=local
export SSH_TUNNEL_HOST=your-server.com
export SSH_TUNNEL_USERNAME=your-username
export SSH_TUNNEL_PASSWORD=your-password
export SPRING_CLOUD_CONSUL_HOST=consul.your-domain.com
export SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka.your-domain.com:9092
export KEYCLOAK_ISSUER_URI=https://keycloak.your-domain.com/realms/gateway

mvn spring-boot:run
```

### Service

```bash
cd rms-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Or with environment variables:

```bash
export SPRING_PROFILES_ACTIVE=local
export SSH_TUNNEL_HOST=your-server.com
export SSH_TUNNEL_USERNAME=your-username
export SSH_TUNNEL_PASSWORD=your-password
export SSH_TUNNEL_LOCAL_PORT=5434  # Service uses different port
export SPRING_CLOUD_CONSUL_HOST=consul.your-domain.com
export SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka.your-domain.com:9092
export KEYCLOAK_ISSUER_URI=https://keycloak.your-domain.com/realms/service

mvn spring-boot:run
```

## Step 6: Verify SSH Tunnels

When the application starts, you should see logs like:

```
=== Creating SSH Tunnels ===
SSH Host: your-server.com:22
SSH Username: your-username
SSH session connected successfully
PostgreSQL tunnel established: localhost:5433 -> your-server.com:localhost:5435
Kafka tunnel established: localhost:9092 -> your-server.com:localhost:9295
Consul tunnel established: localhost:8500 -> your-server.com:localhost:8500
Elasticsearch tunnel established: localhost:9200 -> your-server.com:localhost:9200
Keycloak tunnel established: localhost:8080 -> your-server.com:localhost:9292
=== All SSH Tunnels Established ===
```

## Troubleshooting

### SSH Tunnel Fails

1. **Check SSH connectivity:**
   ```bash
   ssh your-username@your-server.com
   ```

2. **Verify remote port is accessible:**
   ```bash
   ssh your-username@your-server.com "nc -zv localhost 5435"
   ```

3. **Check if local port is already in use:**
   ```bash
   # Linux/Mac
   lsof -i :5433
   # Windows
   netstat -ano | findstr :5433
   ```

4. **Verify SSH tunnel configuration in logs:**
   - Look for "SSH tunnel established" message
   - Check for any JSch exceptions

### Database Connection Fails

1. **Verify tunnel is working:**
   ```bash
   # Test connection through tunnel
   psql -h localhost -p 5433 -U rms_gateway -d rms_gateway
   ```

2. **Check database credentials:**
   - Ensure `rms_gateway` and `rms_service` databases exist on server
   - Verify usernames and passwords match

3. **Check application logs:**
   - Look for connection errors
   - Verify `DB_HOST` and `DB_PORT` are correct

### Service Connection Issues (All via SSH Tunnels)

1. **Test all tunnels:**
   ```bash
   # Test Consul (via tunnel)
   curl http://localhost:8500/v1/status/leader
   
   # Test Elasticsearch (via tunnel)
   curl http://localhost:9200/_cluster/health
   
   # Test Kafka (via tunnel) - requires Kafka client
   # Test Keycloak (via tunnel)
   curl http://localhost:8080/realms/gateway/.well-known/openid-configuration
   ```

2. **Verify all tunnels are established:**
   - Check application startup logs for "All SSH Tunnels Established"
   - Verify each service tunnel is listed

3. **Check if local ports are in use:**
   ```bash
   # Linux/Mac
   lsof -i :5433 -i :9092 -i :8500 -i :9200 -i :8080
   # Windows
   netstat -ano | findstr "5433 9092 8500 9200 8080"
   ```

## Environment Variables Reference

### SSH Tunnel Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SSH_TUNNEL_ENABLED` | Enable/disable SSH tunnel | `true` |
| `SSH_TUNNEL_HOST` | SSH server hostname | Required |
| `SSH_TUNNEL_PORT` | SSH server port | `22` |
| `SSH_TUNNEL_USERNAME` | SSH username | Required |
| `SSH_TUNNEL_PASSWORD` | SSH password | Optional |
| `SSH_TUNNEL_PRIVATE_KEY` | Path to SSH private key | Optional |
| `SSH_TUNNEL_PRIVATE_KEY_PASSPHRASE` | SSH key passphrase | Optional |
| `SSH_TUNNEL_REMOTE_HOST` | Remote DB host (on server) | `localhost` |
| `SSH_TUNNEL_REMOTE_PORT` | Remote DB port | `5435` |
| `SSH_TUNNEL_LOCAL_PORT` | Local tunnel port | `5433` (Gateway), `5434` (Service) |

### Service Connection Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SPRING_CLOUD_CONSUL_HOST` | Consul hostname | `consul.your-domain.com` |
| `SPRING_CLOUD_CONSUL_PORT` | Consul port | `8500` |
| `SPRING_KAFKA_BOOTSTRAP_SERVERS` | Kafka brokers | `kafka.your-domain.com:9092` |
| `SPRING_ELASTICSEARCH_URIS` | Elasticsearch URI | `http://elasticsearch.your-domain.com:9200` |
| `KEYCLOAK_ISSUER_URI` | Keycloak issuer URI | `https://keycloak.your-domain.com/realms/{realm}` |

## Port Summary

| Service | Server Port (localhost) | Local Port (via SSH) | Access Method |
|---------|-------------------------|---------------------|---------------|
| PostgreSQL (Gateway) | 5435 | 5433 | SSH tunnel |
| PostgreSQL (Service) | 5435 | 5434 | SSH tunnel |
| Kafka | 9295 | 9092 | SSH tunnel |
| Zookeeper | 2181 | - | Internal only |
| Consul | 8500 | 8500 | SSH tunnel |
| Elasticsearch | 9200 | 9200 | SSH tunnel |
| Keycloak | 9292 | 8080 | SSH tunnel |
| Gateway | - | 8080 | Local app |
| Service | - | 8081 | Local app |

**Note:** All server ports are bound to `127.0.0.1` only (not accessible from outside). External access is via Nginx with SSL (see `SECURE_SETUP.md`).

## Security Notes

1. **SSH Keys:** Prefer SSH key authentication over passwords
2. **Credentials:** Never commit passwords or private keys to git
3. **Firewall:** Ensure only necessary ports are exposed
4. **TLS:** Consider using TLS for service connections in production

## Next Steps

1. Set up DNS entries or hosts file
2. Configure SSH tunnel credentials
3. Update `application-local.yml` with your server details
4. Run Gateway and Service locally
5. Test connectivity to all services

For issues or questions, check the application logs and verify each service connection individually.

