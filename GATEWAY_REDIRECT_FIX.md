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

Updated the `oauth2AuthenticationSuccessHandler()` method in `SecurityConfiguration.java` to:

1. **Detect reverse proxy**: Check for `X-Forwarded-Port`, `X-Forwarded-Host`, or `X-Forwarded-Proto` headers
2. **Handle reverse proxy correctly**: 
   - If behind reverse proxy, use the forwarded port or standard ports (80/443) based on scheme
   - Don't append port number for standard ports (80 for HTTP, 443 for HTTPS)
3. **Preserve local development**: Still use ports 9000/9060 for local development

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
- **Docker Compose**: `C:\Users\shiva\cursor_workspace\keycloak_with_plugins_deploy\docker-compose.yml`
- **Ports Documentation**: `C:\Users\shiva\cursor_workspace\keycloak_with_plugins_deploy\PORTS_EXPOSED.md`

