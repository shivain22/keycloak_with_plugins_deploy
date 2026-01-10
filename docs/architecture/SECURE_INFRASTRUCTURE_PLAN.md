# Secure Infrastructure Setup Plan

## Overview

This plan secures all infrastructure services behind Nginx with SSL and uses SSH tunneling for local development.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Remote Server                            │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Nginx (SSL Termination)                 │  │
│  │  Port 443 (HTTPS)                                    │  │
│  │  - keycloak.your-domain.com                           │  │
│  │  - consul.your-domain.com (optional)                  │  │
│  │  - elasticsearch.your-domain.com (optional)           │  │
│  └─────────────────────────────────────────────────────┘  │
│         │                                                   │
│         │ (localhost:port)                                 │
│         ▼                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │PostgreSQL│  │  Kafka   │  │  Consul  │  │Keycloak  │  │
│  │127.0.0.1│  │127.0.0.1 │  │127.0.0.1 │  │127.0.0.1 │  │
│  │  :5435   │  │  :9295   │  │  :8500   │  │  :9292   │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│  ┌──────────┐  ┌──────────┐                              │
│  │Elastic   │  │Zookeeper │                              │
│  │127.0.0.1 │  │127.0.0.1 │                              │
│  │  :9200   │  │  :2181   │                              │
│  └──────────┘  └──────────┘                              │
└─────────────────────────────────────────────────────────────┘
         ▲
         │
         │ SSH Tunnels (All Services)
         │
┌────────┴──────────────────────────────────────────────────┐
│                    Your Laptop                              │
│  ┌──────────┐  ┌──────────┐                               │
│  │ Gateway  │  │ Service  │                               │
│  │ :8080    │  │ :8081    │                               │
│  └──────────┘  └──────────┘                               │
│                                                             │
│  All services accessed via localhost (SSH tunnels):         │
│  - localhost:5433 → PostgreSQL (Gateway)                    │
│  - localhost:5434 → PostgreSQL (Service)                    │
│  - localhost:9092 → Kafka                                   │
│  - localhost:8500 → Consul                                 │
│  - localhost:9200 → Elasticsearch                          │
│  - localhost:8080 → Keycloak                               │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Steps

### Phase 1: Secure Docker Compose Configuration

**File:** `docker-compose-secure.yml`

**Changes:**
- All port bindings changed from `"PORT:PORT"` to `"127.0.0.1:PORT:PORT"`
- Services are NOT accessible from outside the server
- Only accessible via:
  - SSH tunnel (for local development)
  - Nginx reverse proxy (for external HTTPS access)

**Services Updated:**
- `db` (Keycloak DB): `127.0.0.1:5434:5432`
- `rms-postgresql`: `127.0.0.1:5435:5432`
- `zookeeper`: `127.0.0.1:2181:2181`
- `kafka`: `127.0.0.1:9295:9092`
- `consul`: `127.0.0.1:8500:8500`
- `elasticsearch`: `127.0.0.1:9200:9200`
- `keycloak`: `127.0.0.1:9292:8080`

### Phase 2: Nginx SSL Configuration

**File:** `nginx/nginx-secure.conf`

**Features:**
- SSL termination for Keycloak (required for OAuth2)
- Optional SSL for Consul and Elasticsearch
- HTTP to HTTPS redirect
- Security headers (HSTS, X-Frame-Options, etc.)

**SSL Certificates:**
- Use Let's Encrypt for production
- Self-signed for development/testing

### Phase 3: Enhanced SSH Tunnel Support

**Files:**
- `rms/src/main/java/com/atparui/rms/config/SshTunnelConfig.java`
- `rms-service/src/main/java/com/atparui/rmsservice/config/SshTunnelConfig.java`

**Features:**
- Multiple tunnel support (PostgreSQL, Kafka, Consul, Elasticsearch, Keycloak)
- Automatic tunnel creation on startup
- Automatic cleanup on shutdown
- Support for password and SSH key authentication

### Phase 4: Local Development Configuration

**Files:**
- `rms/src/main/resources/config/application-local.yml`
- `rms-service/src/main/resources/config/application-local.yml`

**Configuration:**
- All services connect to `localhost` (via SSH tunnels)
- No DNS/subdomain configuration needed
- All connections are secure via SSH

## Service Access Matrix

| Service | Server Binding | SSH Tunnel | External Access |
|---------|---------------|------------|-----------------|
| PostgreSQL | `127.0.0.1:5435` | ✅ `localhost:5433/5434` | ❌ None |
| Kafka | `127.0.0.1:9295` | ✅ `localhost:9092` | ❌ None |
| Zookeeper | `127.0.0.1:2181` | ❌ Internal only | ❌ None |
| Consul | `127.0.0.1:8500` | ✅ `localhost:8500` | ⚠️ Optional HTTPS |
| Elasticsearch | `127.0.0.1:9200` | ✅ `localhost:9200` | ⚠️ Optional HTTPS (restricted) |
| Keycloak | `127.0.0.1:9292` | ✅ `localhost:8080` | ✅ HTTPS via Nginx |

## Security Benefits

1. **No Direct Exposure:** Services not accessible from internet
2. **SSL Encryption:** All external access via HTTPS
3. **SSH Tunneling:** Secure local development access
4. **Firewall Friendly:** Only ports 22, 80, 443 need to be open
5. **Access Control:** Can restrict Consul/Elasticsearch to specific IPs

## Quick Start

### On Server:

```bash
# 1. Use secure docker-compose
cd keycloak_with_plugins_deploy
docker compose -f docker-compose-secure.yml up -d

# 2. Set up SSL certificates
sudo certbot certonly --nginx -d keycloak.your-domain.com

# 3. Configure Nginx
sudo cp nginx/nginx-secure.conf /etc/nginx/sites-available/rms-services
sudo ln -s /etc/nginx/sites-available/rms-services /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### On Laptop:

```bash
# 1. Configure SSH tunnel settings in application-local.yml
# 2. Run Gateway
cd rms
mvn spring-boot:run -Dspring-boot.run.profiles=local

# 3. Run Service
cd rms-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

## Files Created/Modified

### New Files:
- `docker-compose-secure.yml` - Secure Docker Compose configuration
- `nginx/nginx-secure.conf` - Nginx SSL configuration
- `SECURE_SETUP.md` - Detailed setup guide
- `SECURE_INFRASTRUCTURE_PLAN.md` - This file

### Modified Files:
- `rms/src/main/java/com/atparui/rms/config/SshTunnelConfig.java` - Multi-tunnel support
- `rms-service/src/main/java/com/atparui/rmsservice/config/SshTunnelConfig.java` - Multi-tunnel support
- `rms/src/main/resources/config/application-local.yml` - All services via tunnels
- `rms-service/src/main/resources/config/application-local.yml` - All services via tunnels
- `LOCAL_DEVELOPMENT.md` - Updated for multi-tunnel setup

## Next Steps

1. ✅ Secure Docker Compose created
2. ✅ SSH tunnel support enhanced
3. ✅ Local development configs updated
4. ⏳ Set up SSL certificates on server
5. ⏳ Configure Nginx on server
6. ⏳ Test all SSH tunnels
7. ⏳ Verify external HTTPS access

This setup provides a secure, production-ready infrastructure while enabling seamless local development via SSH tunneling.

