# Consul UI OAuth2 Proxy Setup Guide

## Overview
This guide explains how to set up OAuth2 Proxy to secure the Consul UI at `https://consul.atparui.com` using Keycloak authentication.

## Prerequisites
- Keycloak running at `https://rmsauth.atparui.com`
- Gateway realm configured with `gateway-web` client
- SSL certificate for `consul.atparui.com` (already configured via Certbot)
- Consul running in Docker container

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

## Step 2: Configure Keycloak Client

The `gateway-web` client in the `gateway` realm needs to have the following redirect URI:

1. Log into Keycloak Admin Console at `https://rmsauth.atparui.com`
2. Navigate to: **Clients** → **gateway-web** → **Settings**
3. Add to **Valid Redirect URIs**:
   ```
   https://consul.atparui.com/oauth2/callback
   ```
4. Add to **Web Origins**:
   ```
   https://consul.atparui.com
   ```
5. Ensure **Standard Flow Enabled** is `ON`
6. Click **Save**

## Step 3: Update Environment Variables

Edit your `.env` file and set the following:

```bash
# OAuth2 Proxy for Consul UI Security
OAUTH2_PROXY_PORT=4180
OAUTH2_PROXY_CLIENT_ID=gateway-web
OAUTH2_PROXY_CLIENT_SECRET=M5nP8qR2sT6uV9wX1yZ3aC4dE7fG0h
OAUTH2_PROXY_OIDC_ISSUER_URL=https://rmsauth.atparui.com/realms/gateway
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
   - You should be redirected to Keycloak login
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
   ├─ /ui, / → OAuth2 Proxy (localhost:4180) → Keycloak Auth → Consul (consul:8500)
   │
   └─ /v1/ → Consul (192.168.0.102:8500) [Direct, no auth]
```

## Troubleshooting

### Issue: OAuth2 Proxy fails to start
- Check that `OAUTH2_PROXY_COOKIE_SECRET` is set in `.env`
- Verify all environment variables are correct
- Check logs: `docker logs rms-oauth2-proxy`

### Issue: Redirect loop or authentication fails
- Verify Keycloak client has correct redirect URI: `https://consul.atparui.com/oauth2/callback`
- Check that `OAUTH2_PROXY_REDIRECT_URL` matches exactly
- Verify `OAUTH2_PROXY_OIDC_ISSUER_URL` is correct
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
- **Client Secret**: The `gateway-web` client secret is used. Ensure it's kept secure.
- **API Access**: The `/v1/` API endpoints remain unprotected. Consider adding IP whitelisting if needed.
- **HTTPS Only**: All traffic should use HTTPS (already configured via Certbot).

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

## References

- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Keycloak OIDC Configuration](https://www.keycloak.org/docs/latest/securing_apps/)
- [Consul UI Documentation](https://www.consul.io/docs/agent/web-ui)

