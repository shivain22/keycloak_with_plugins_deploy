# Gateway Redirect Issue - Fixed

## Problem

The RMS Gateway was redirecting to `https://rmsgateway.atparui.com:9000/` after OAuth2 login, which is incorrect for production.

## Root Cause

The `SecurityConfiguration.java` file in the gateway had hardcoded logic that:
1. Defaulted to port 9000 (development frontend port) when it couldn't detect the correct port
2. Didn't properly handle reverse proxy scenarios where:
   - `X-Forwarded-Port` header contains 443 (HTTPS) or 80 (HTTP)
   - The request comes through a reverse proxy on standard ports
3. Always appended port 9000 to the redirect URL, even in production

## Solution

Fixed **THREE** critical issues:

### 1. OAuth2 Success Handler (`SecurityConfiguration.java`)

Updated the `oauth2AuthenticationSuccessHandler()` method to:

1. **Detect reverse proxy**: Check for `X-Forwarded-Port`, `X-Forwarded-Host`, or `X-Forwarded-Proto` headers
2. **Handle reverse proxy correctly**: 
   - If behind reverse proxy, use the forwarded port or standard ports (80/443) based on scheme
   - Don't append port number for standard ports (80 for HTTP, 443 for HTTPS)
   - **Always ignore port 9000/9060 in production** (even if forwarded by misconfigured proxy)
3. **Preserve local development**: Still use ports 9000/9060 for local development

### 2. OAuth2 Redirect URI Builder (`DynamicServerOAuth2AuthorizationRequestResolver.java`)

Updated the `buildAuthorizationRequest()` method to:

1. **Detect reverse proxy**: Same detection logic as above
2. **Build correct redirect URI for Keycloak**:
   - In production: Use standard ports (80/443) - no port in URL
   - **Always ignore port 9000/9060** if detected in production (likely misconfigured proxy)
   - In local dev: Use gateway port (9293) for OAuth callbacks
3. **Prevent port 9000 in production**: Even if `X-Forwarded-Port: 9000` is set (misconfigured proxy), ignore it

### 3. Spring Boot Forward Headers Configuration (`application-prod.yml`)

**CRITICAL FIX**: Added `server.forward-headers-strategy: native` to production configuration.

This is **essential** for Spring WebFlux (reactive) to properly use `X-Forwarded-*` headers when behind a reverse proxy. Without this:
- Spring Security cannot correctly resolve `{baseUrl}` placeholder in redirect URIs
- The gateway will use the internal container URL instead of the public URL
- OAuth2 redirects will fail or redirect to wrong ports

**What this does:**
- Enables Spring Boot to automatically use `X-Forwarded-Proto`, `X-Forwarded-Host`, and `X-Forwarded-Port` headers
- Allows Spring Security to correctly build redirect URIs based on the original request
- Works with the custom redirect handlers to ensure correct URLs

### Key Changes

- **Production**: Never use port 9000/9060, always use standard ports (80/443) or no port
- **Local Dev**: Use appropriate ports (9000/9060 for webpack, 9293 for gateway)
- **Robust Detection**: Properly detects reverse proxy scenarios and handles edge cases
- **Forward Headers**: Enabled native forward headers strategy for proper reverse proxy support

## Ports for Gateway UI

### Local Development
- **Gateway UI**: `http://localhost:9293` (host port)
  - Container port: 8080
  - Environment variable: `GATEWAY_HTTP_PORT` (default: 9293)

### Production
- **Gateway UI**: `https://rmsgateway.atparui.com` (no port - uses standard HTTPS port 443)
- **Gateway API**: `https://rmsgateway.atparui.com/api/...` (same domain, different path)

### Important Notes

1. **Gateway serves both UI and API on the same port**:
   - UI: `http://localhost:9293/` or `https://rmsgateway.atparui.com/`
   - API: `http://localhost:9293/api/...` or `https://rmsgateway.atparui.com/api/...`

2. **Port 9000** is only used for:
   - Local development with webpack dev server
   - Development frontend proxy
   - NOT for production

3. **Production Setup**:
   - Reverse proxy (nginx/apache) should route:
     - `rmsgateway.atparui.com` → `localhost:9293` (or your configured `GATEWAY_HTTP_PORT`)
   - The gateway will serve both UI and API on port 8080 (container) / 9293 (host)

## Testing the Fix

After rebuilding and redeploying the gateway:

1. **Local Test**:
   ```bash
   # Access gateway UI
   http://localhost:9293
   
   # Should redirect to Keycloak for login
   # After login, should redirect back to http://localhost:9293 (not :9000)
   ```

2. **Production Test**:
   ```bash
   # Access gateway UI
   https://rmsgateway.atparui.com
   
   # Should redirect to Keycloak for login
   # After login, should redirect back to https://rmsgateway.atparui.com (no port)
   ```

## Next Steps

1. **Rebuild the gateway**:
   ```bash
   cd C:\Users\shiva\eclipse-workspace\rms
   ./mvnw clean package
   ```

2. **Rebuild Docker image** (if using Docker):
   ```bash
   cd C:\Users\shiva\cursor_workspace\keycloak_with_plugins_deploy
   docker compose build gateway
   # Or use the apps-builder service to rebuild
   ```

3. **Redeploy**:
   ```bash
   docker compose up -d gateway
   ```

4. **Verify**:
   - Check gateway logs: `docker compose logs gateway`
   - Test login flow and verify redirect URL is correct

## Related Files

- **Gateway Security Config**: `C:\Users\shiva\eclipse-workspace\rms\src\main\java\com\atparui\rms\config\SecurityConfiguration.java`
- **OAuth2 Redirect URI Builder**: `C:\Users\shiva\eclipse-workspace\rms\src\main\java\com\atparui\rms\config\DynamicServerOAuth2AuthorizationRequestResolver.java`
- **Docker Compose**: `C:\Users\shiva\cursor_workspace\keycloak_with_plugins_deploy\docker-compose.yml`
- **Ports Documentation**: `C:\Users\shiva\cursor_workspace\keycloak_with_plugins_deploy\PORTS_EXPOSED.md`

## Additional Notes

### Keycloak Redirect URI Configuration

The Keycloak realm configuration includes `http://localhost:9000/login/oauth2/code/oidc` for local development. In production, the redirect URI is dynamically built by the gateway and should be:
- `https://rmsgateway.atparui.com/login/oauth2/code/oidc` (if gateway handles OAuth)
- `https://rmsdashboard.atparui.com/login/oauth2/code/oidc` (if dashboard handles OAuth)

Make sure your Keycloak client has the production redirect URI registered. The gateway will send the correct redirect URI in the OAuth2 authorization request, and Keycloak will validate it against the allowed redirect URIs.

### Reverse Proxy Configuration

Ensure your reverse proxy (nginx/apache) is correctly setting the `X-Forwarded-*` headers:
- `X-Forwarded-Proto: https` (for HTTPS)
- `X-Forwarded-Host: rmsgateway.atparui.com`
- `X-Forwarded-Port: 443` (or omit for standard ports)

**Important**: If your reverse proxy is forwarding `X-Forwarded-Port: 9000`, that's a misconfiguration. The gateway will now ignore it and use standard ports, but you should fix the reverse proxy configuration.

