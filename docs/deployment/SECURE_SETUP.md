# Secure Infrastructure Setup Guide

This guide explains how to secure all infrastructure services behind Nginx with SSL certificates and use SSH tunneling for local development.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Remote Server                            │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Nginx (SSL Termination)                 │  │
│  │  - keycloak.your-domain.com (HTTPS)                 │  │
│  │  - consul.your-domain.com (HTTPS)                   │  │
│  │  - elasticsearch.your-domain.com (HTTPS)            │  │
│  └─────────────────────────────────────────────────────┘  │
│         │                                                   │
│         │ (localhost only)                                 │
│         ▼                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │PostgreSQL│  │  Kafka   │  │  Consul  │  │Keycloak  │  │
│  │:5435     │  │  :9295   │  │  :8500   │  │  :9292   │  │
│  │(localhost)│ │(localhost)│ │(localhost)│ │(localhost)│ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│  ┌──────────┐  ┌──────────┐                              │
│  │Elastic   │  │Zookeeper │                              │
│  │  :9200   │  │  :2181   │                              │
│  │(localhost)│ │(localhost)│                             │
│  └──────────┘  └──────────┘                              │
└─────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │                    │                    │
         │ SSH Tunnels        │ SSH Tunnels        │ SSH Tunnel
         │ (All Services)     │ (All Services)     │ (Keycloak)
         │                    │                    │
┌────────┴────────────────────┴────────────────────┴────────┐
│                    Your Laptop                              │
│  ┌──────────┐  ┌──────────┐                               │
│  │ Gateway  │  │ Service  │                               │
│  │ :8080    │  │ :8081    │                               │
│  └──────────┘  └──────────┘                               │
│                                                             │
│  SSH Tunnels:                                               │
│  - localhost:5433 → server:5435 (Gateway DB)              │
│  - localhost:5434 → server:5435 (Service DB)               │
│  - localhost:9092 → server:9295 (Kafka)                    │
│  - localhost:8500 → server:8500 (Consul)                   │
│  - localhost:9200 → server:9200 (Elasticsearch)            │
│  - localhost:8080 → server:9292 (Keycloak)                 │
└─────────────────────────────────────────────────────────────┘
```

## Step 1: Configure Docker Compose for Security

Use `docker-compose-secure.yml` which binds all services to `127.0.0.1` only:

```bash
cd keycloak_with_plugins_deploy
docker compose -f docker-compose-secure.yml up -d
```

### Key Changes in Secure Configuration:

- All ports bind to `127.0.0.1` instead of `0.0.0.0`
- Services are NOT accessible from outside the server
- Only accessible via:
  - SSH tunnel (for local development)
  - Nginx reverse proxy (for external HTTPS access)

## Step 2: Obtain SSL Certificates

### Option A: Let's Encrypt (Recommended)

```bash
# Install certbot
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx

# Obtain certificates for all subdomains
sudo certbot certonly --nginx -d keycloak.your-domain.com
sudo certbot certonly --nginx -d consul.your-domain.com
sudo certbot certonly --nginx -d elasticsearch.your-domain.com

# Certificates will be stored in:
# /etc/letsencrypt/live/keycloak.your-domain.com/
# /etc/letsencrypt/live/consul.your-domain.com/
# /etc/letsencrypt/live/elasticsearch.your-domain.com/
```

### Option B: Self-Signed Certificates (Development Only)

```bash
# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate for Keycloak
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/keycloak.your-domain.com.key \
  -out /etc/nginx/ssl/keycloak.your-domain.com.crt \
  -subj "/CN=keycloak.your-domain.com"

# Repeat for other services...
```

## Step 3: Configure Nginx

1. **Copy Nginx configuration:**

```bash
sudo cp keycloak_with_plugins_deploy/nginx/nginx-secure.conf /etc/nginx/sites-available/rms-services
sudo ln -s /etc/nginx/sites-available/rms-services /etc/nginx/sites-enabled/
```

2. **Update SSL certificate paths** in `/etc/nginx/sites-available/rms-services`:

```nginx
ssl_certificate /etc/letsencrypt/live/keycloak.your-domain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/keycloak.your-domain.com/privkey.pem;
```

3. **Test and reload Nginx:**

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Step 4: Configure DNS

Create DNS A records pointing to your server IP:

```
keycloak.your-domain.com  →  YOUR_SERVER_IP
consul.your-domain.com    →  YOUR_SERVER_IP
elasticsearch.your-domain.com → YOUR_SERVER_IP
```

## Step 5: Configure Local Development

### Update `application-local.yml`

The SSH tunnel configuration now supports multiple tunnels:

```yaml
ssh:
  tunnel:
    enabled: true
    host: your-server.com
    username: your-username
    password: your-password  # or use private-key
    
    # PostgreSQL Tunnel
    postgres:
      remote-port: 5435
      local-port: 5433  # Gateway uses 5433, Service uses 5434
    
    # Kafka Tunnel
    kafka:
      remote-port: 9295
      local-port: 9092
    
    # Consul Tunnel
    consul:
      remote-port: 8500
      local-port: 8500
    
    # Elasticsearch Tunnel
    elasticsearch:
      remote-port: 9200
      local-port: 9200
    
    # Keycloak Tunnel
    keycloak:
      remote-port: 9292
      local-port: 8080
```

### Environment Variables

```bash
export SPRING_PROFILES_ACTIVE=local
export SSH_TUNNEL_ENABLED=true
export SSH_TUNNEL_HOST=your-server.com
export SSH_TUNNEL_USERNAME=your-username
export SSH_TUNNEL_PASSWORD=your-password

# Run Gateway
cd rms
mvn spring-boot:run

# Run Service (in another terminal)
cd rms-service
mvn spring-boot:run
```

## Step 6: Verify Setup

### Test SSH Tunnels

When applications start, you should see:

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

### Test Service Connections

```bash
# Test PostgreSQL (via tunnel)
psql -h localhost -p 5433 -U rms_gateway -d rms_gateway

# Test Consul (via tunnel)
curl http://localhost:8500/v1/status/leader

# Test Elasticsearch (via tunnel)
curl http://localhost:9200/_cluster/health

# Test Keycloak (via tunnel)
curl http://localhost:8080/realms/gateway/.well-known/openid-configuration
```

### Test External HTTPS Access

```bash
# Test Keycloak via HTTPS
curl https://keycloak.your-domain.com/realms/gateway/.well-known/openid-configuration

# Test Consul via HTTPS (if not restricted)
curl https://consul.your-domain.com/v1/status/leader
```

## Security Best Practices

1. **Firewall Configuration:**
   ```bash
   # Allow only SSH, HTTP, and HTTPS
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

2. **Restrict Service Access:**
   - PostgreSQL, Kafka, Zookeeper: SSH tunnel only (no external access)
   - Consul, Elasticsearch: SSH tunnel or restricted IPs via Nginx
   - Keycloak: HTTPS via Nginx (public access with SSL)

3. **SSL Certificate Renewal:**
   ```bash
   # Let's Encrypt certificates expire every 90 days
   # Set up auto-renewal
   sudo certbot renew --dry-run
   
   # Add to crontab for auto-renewal
   sudo crontab -e
   # Add: 0 0 * * * certbot renew --quiet
   ```

4. **Monitor Access:**
   - Review Nginx access logs: `/var/log/nginx/access.log`
   - Monitor failed SSH attempts: `/var/log/auth.log`
   - Set up fail2ban for SSH protection

## Port Summary

| Service | Server Port (localhost) | Local Port (via SSH) | External Access |
|---------|-------------------------|---------------------|-----------------|
| PostgreSQL | 5435 | 5433 (Gateway), 5434 (Service) | SSH tunnel only |
| Kafka | 9295 | 9092 | SSH tunnel only |
| Zookeeper | 2181 | - | SSH tunnel only |
| Consul | 8500 | 8500 | HTTPS via Nginx (optional) |
| Elasticsearch | 9200 | 9200 | HTTPS via Nginx (restricted) |
| Keycloak | 9292 | 8080 | HTTPS via Nginx (public) |

## Troubleshooting

### Services Not Accessible

1. **Check if services are bound to localhost:**
   ```bash
   sudo netstat -tlnp | grep 127.0.0.1
   ```

2. **Verify Docker Compose is using secure config:**
   ```bash
   docker compose -f docker-compose-secure.yml ps
   ```

3. **Check Nginx status:**
   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   ```

### SSH Tunnel Issues

1. **Verify SSH connectivity:**
   ```bash
   ssh your-username@your-server.com
   ```

2. **Check if local ports are available:**
   ```bash
   # Linux/Mac
   lsof -i :5433
   lsof -i :9092
   # Windows
   netstat -ano | findstr :5433
   ```

3. **Review application logs** for tunnel creation errors

### SSL Certificate Issues

1. **Verify certificate paths in Nginx config**
2. **Check certificate validity:**
   ```bash
   openssl x509 -in /etc/letsencrypt/live/keycloak.your-domain.com/fullchain.pem -text -noout
   ```
3. **Ensure DNS is properly configured**

## Next Steps

1. Set up SSL certificates for all subdomains
2. Configure Nginx with SSL termination
3. Update docker-compose to use secure configuration
4. Configure local development with SSH tunnels
5. Test all service connections
6. Set up monitoring and logging

This setup ensures all services are secure and only accessible via SSH tunnel (for development) or HTTPS through Nginx (for production access).

