# Consul UI OAuth2 Proxy Setup Guide

## Overview
This guide explains how to set up OAuth2 Proxy to secure the Consul UI at `https://consul.atparui.com` using Keycloak authentication via the **atpar-infra** realm.

> **Note:** Consul authentication has been moved from the `gateway` realm to the unified `atpar-infra` infrastructure realm. This allows centralized user management for all DevOps tools (Jenkins, Consul, Grafana, etc.).

## Prerequisites
- Keycloak running at `https://auth.atparui.com`
- `atpar-infra` realm imported (see `realm-import/atpar-infra-realm.json`)
- SSL certificate for `consul.atparui.com` (already configured via Certbot)
- Consul running in Docker container

## Pre-configured Users

The following users are pre-configured in the `atpar-infra` realm:

| Username | Password | Roles | Access Level |
|----------|----------|-------|--------------|
| `infra-admin` | `InfraAdmin@2024!` | infra-admin | Full access |
| `devops-lead` | `DevOps@2024!` | infra-admin | Full access |
| `developer` | `Developer@2024!` | infra-developer | Read/Write |
| `viewer` | `Viewer@2024!` | infra-viewer | Read-only |

> **⚠️ Important:** Change these default passwords in production!

## Step 1: Generate Cookie Secret

OAuth2 Proxy requires a secure cookie secret. Generate it using one of these methods:

**Option A: Using OpenSSL (Recommended)**
```bash
openssl rand -base64 32 | head -c 32 | base64
```

**Option B: Using Python**
```bash
python3 -c 'import secrets, base64; print(base64.b64encode(secrets.token_bytes(32)).decode())'
```

**Option C: Using Node.js**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

Copy the generated value and add it to your `.env` file as `OAUTH2_PROXY_COOKIE_SECRET`.

## Step 2: Keycloak Client (Already Configured)

The `consul` client is pre-configured in the `atpar-infra` realm with:

```
Client ID: consul
Client Secret: C0nSuL@InFrA2024SecureKey!
Realm: atpar-infra
Redirect URIs: https://consul.atparui.com/oauth2/callback
```

## Step 3: Update Environment Variables

Edit your `.env` file and set the following:

```bash
# OAuth2 Proxy for Consul UI Security (using atpar-infra realm)
OAUTH2_PROXY_PORT=4180
OAUTH2_PROXY_CLIENT_ID=consul
OAUTH2_PROXY_CLIENT_SECRET=C0nSuL@InFrA2024SecureKey!
OAUTH2_PROXY_OIDC_ISSUER_URL=https://auth.atparui.com/realms/atpar-infra
OAUTH2_PROXY_REDIRECT_URL=https://consul.atparui.com/oauth2/callback
OAUTH2_PROXY_COOKIE_SECRET=<your-generated-secret-here>
OAUTH2_PROXY_COOKIE_DOMAIN=consul.atparui.com
```

**Important**: Replace `<your-generated-secret-here>` with the cookie secret generated in Step 1.

## Step 4: Update Nginx Configuration

Replace the existing nginx configuration at `/etc/nginx/sites-enabled/consul.atparui.com.conf` with the new configuration from `nginx/consul.atparui.com.conf`.

**On the server:**
```bash
# Backup existing config
sudo cp /etc/nginx/sites-enabled/consul.atparui.com.conf /etc/nginx/sites-enabled/consul.atparui.com.conf.backup

# Copy new config (adjust path as needed)
sudo cp /path/to/nginx/consul.atparui.com.conf /etc/nginx/sites-enabled/consul.atparui.com.conf

# Test nginx configuration
sudo nginx -t

# If test passes, reload nginx
sudo systemctl reload nginx
```

## Step 5: Start OAuth2 Proxy Service

Start the oauth2-proxy container:

```bash
cd /path/to/keycloak_with_plugins_deploy
docker-compose up -d oauth2-proxy
```

Or restart all services:
```bash
docker-compose up -d
```

## Step 6: Verify Setup

1. **Check OAuth2 Proxy is running:**
   ```bash
   docker ps | grep oauth2-proxy
   docker logs rms-oauth2-proxy
   ```

2. **Test Consul UI Access:**
   - Navigate to `https://consul.atparui.com/ui`
   - You should be redirected to Keycloak login (atpar-infra realm)
   - After login, you should be redirected back to Consul UI

3. **Test Consul API (should remain accessible):**
   ```bash
   curl https://consul.atparui.com/v1/status/leader
   ```
   This should work without authentication (for internal services).

## Architecture

```
Internet
   │
   ▼
Nginx (consul.atparui.com)
   │
   ├─ /ui, / → OAuth2 Proxy (localhost:4180) → Keycloak (atpar-infra) → Consul (consul:8500)
   │
   └─ /v1/ → Consul (192.168.0.102:8500) [Direct, no auth]
```

## Role Mapping

| Infra Role | Consul Access |
|------------|---------------|
| `infra-admin` | Full ACL management |
| `infra-developer` | Read/Write services and KV |
| `infra-viewer` | Read-only access |

## Troubleshooting

### Issue: OAuth2 Proxy fails to start
- Check that `OAUTH2_PROXY_COOKIE_SECRET` is set in `.env`
- Verify all environment variables are correct
- Check logs: `docker logs rms-oauth2-proxy`

### Issue: Redirect loop or authentication fails
- Verify Keycloak client has correct redirect URI: `https://consul.atparui.com/oauth2/callback`
- Check that `OAUTH2_PROXY_REDIRECT_URL` matches exactly
- Verify `OAUTH2_PROXY_OIDC_ISSUER_URL` is `https://auth.atparui.com/realms/atpar-infra`
- Check Keycloak client secret matches `OAUTH2_PROXY_CLIENT_SECRET`

### Issue: Consul UI shows but API doesn't work
- Verify `/v1/` location block in nginx is correct
- Check that Consul is accessible at `192.168.0.102:8500`
- Test direct access: `curl http://192.168.0.102:8500/v1/status/leader`

### Issue: Can't access Consul UI after login
- Check oauth2-proxy logs: `docker logs rms-oauth2-proxy`
- Verify oauth2-proxy can reach Consul: `docker exec rms-oauth2-proxy wget -O- http://consul:8500/ui`
- Check nginx logs: `sudo tail -f /var/log/nginx/error.log`

## Security Notes

- **Cookie Secret**: Must be a secure random 32-byte value. Never commit to version control.
- **Client Secret**: Keep the `consul` client secret secure.
- **API Access**: The `/v1/` API endpoints remain unprotected. Consider adding IP whitelisting if needed.
- **HTTPS Only**: All traffic should use HTTPS (already configured via Certbot).

## Migration from gateway Realm

If you were previously using the `gateway` realm for Consul authentication:

1. Update `.env` with new values (see Step 3)
2. Restart oauth2-proxy: `docker-compose restart oauth2-proxy`
3. Users will need to log in again
4. Old users from `gateway` realm won't have access - create them in `atpar-infra` realm

## Rollback

If you need to rollback:

1. **Stop oauth2-proxy:**
   ```bash
   docker-compose stop oauth2-proxy
   ```

2. **Restore old nginx config:**
   ```bash
   sudo cp /etc/nginx/sites-enabled/consul.atparui.com.conf.backup /etc/nginx/sites-enabled/consul.atparui.com.conf
   sudo nginx -t
   sudo systemctl reload nginx
   ```

3. **Update nginx to route directly to Consul:**
   ```nginx
   location / {
       proxy_pass http://192.168.0.102:8500;
       # ... rest of config
   }
   ```

## Related Documentation

- [INFRASTRUCTURE_REALM_SETUP.md](INFRASTRUCTURE_REALM_SETUP.md) - Infrastructure realm overview
- [JENKINS_KEYCLOAK_INTEGRATION.md](JENKINS_KEYCLOAK_INTEGRATION.md) - Jenkins setup (same realm)
- [SECURE_SETUP.md](SECURE_SETUP.md) - Security best practices

## References

- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Keycloak OIDC Configuration](https://www.keycloak.org/docs/latest/securing_apps/)
- [Consul UI Documentation](https://www.consul.io/docs/agent/web-ui)
