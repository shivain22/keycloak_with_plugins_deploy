# Production Subdomains Configuration

This document explains how the production subdomains are configured for Keycloak redirect URIs, CORS, and web origins.

## Subdomains

The following subdomains are configured for production:

- **rmsgateway.atparui.com** - Gateway service
- **rmsservice.atparui.com** - Service/API
- **rmsdashboard.atparui.com** - Frontend/Dashboard
- **auth.atparui.com** - Keycloak authentication server

## Configuration Files

### 1. Environment Variables (.env)

The following variables control the production URLs:

```bash
# Production Subdomains
GATEWAY_DOMAIN=rmsgateway.atparui.com
SERVICE_DOMAIN=rmsservice.atparui.com
DASHBOARD_DOMAIN=rmsdashboard.atparui.com
KEYCLOAK_DOMAIN=auth.atparui.com

# Production URLs (HTTPS) - no ports needed (handled by reverse proxy)
GATEWAY_URL_PROD=https://rmsgateway.atparui.com
SERVICE_URL_PROD=https://rmsservice.atparui.com
DASHBOARD_URL_PROD=https://rmsdashboard.atparui.com
KEYCLOAK_URL_PROD=https://auth.atparui.com
```

### 2. Realm Configuration Templates

The realm templates (`realm-import-templates/*.json.template`) include:

- **webOrigins**: Both localhost (for development) and production URLs
- **redirectUris**: OAuth2 callback URLs for both localhost and production
- **post.logout.redirect.uris**: Post-logout redirect URLs

### 3. Generated Realm Files

When you run the start scripts, realm configurations are automatically generated from templates with the correct URLs based on your environment.

## How It Works

1. **Local Development**: Uses `localhost` URLs with ports
2. **Production**: Uses HTTPS subdomains (no ports, handled by reverse proxy)
3. **Both environments**: Production URLs are always included in webOrigins and redirectUris to support both local development and production access

## Keycloak Client Configuration

### Gateway Realm Clients

- **gateway-web**: Web client for gateway
- **gateway-mobile**: Mobile client with PKCE

Both clients include:
- `webOrigins`: `[localhost URLs, production URLs]`
- `redirectUris`: `[localhost callback, production callback]`

### RMS Service Realm Clients

- **rms-service-web**: Web client for service
- **rms-service-mobile**: Mobile client with PKCE

Both clients include:
- `webOrigins`: `[localhost URLs, production URLs]`
- `redirectUris`: `[localhost callback, production callback]`

## Reverse Proxy Configuration

When setting up your reverse proxy (nginx/apache), ensure:

1. **rmsgateway.atparui.com** → Gateway service (port from your server)
2. **rmsservice.atparui.com** → Service/API (port from your server)
3. **rmsdashboard.atparui.com** → Frontend/Dashboard (port from your server)
4. **auth.atparui.com** → Keycloak (port 8080 or your configured port)

## Updating Configuration

1. Update `.env` file with your production URLs
2. Set `ENVIRONMENT=prod` for production deployment
3. Run the start script - it will automatically generate realm configs with correct URLs
4. Keycloak will import the realm configs on startup

## Notes

- Production URLs are **always included** in webOrigins and redirectUris, even in local development
- This allows testing production URLs from local development environment
- HTTPS is required for production (configured via `KC_HOSTNAME_STRICT_HTTPS=true` in prod)
- Ports are not included in production URLs (handled by reverse proxy)

