# Plan: Securing Consul UI at https://consul.atparui.com

## Overview
This plan outlines how to expose and secure the Consul UI at `https://consul.atparui.com` using nginx reverse proxy with Keycloak authentication, while keeping all other services (including Consul API endpoints) unchanged.

## Current Setup Analysis

### Existing Infrastructure
- **Keycloak**: Running in Docker, exposed via nginx at `https://auth.atparui.com`
- **Consul**: Running in Docker container `rms-consul`, exposing port `8500` on host
- **Nginx**: Running on the server as reverse proxy
- **Consul UI**: Currently accessible at `http://localhost:8500/ui` (unsecured)

### Current Nginx Configuration
- Template exists in `nginx/nginx-secure.conf` with placeholder domain `consul.your-domain.com`
- Keycloak is already configured with SSL and security headers
- Consul upstream is already defined: `consul_backend` → `127.0.0.1:8500`

## Security Requirements

### What Needs to be Secured
- ✅ **Consul UI** (`/ui/*` paths) - Must require authentication
- ❌ **Consul API** (`/v1/*` paths) - Should remain accessible for internal services
- ❌ **Other services** - No changes needed

### Authentication Method
**Recommended**: Use Keycloak OAuth2/OIDC with nginx `auth_request` module
- Leverages existing Keycloak infrastructure
- Provides SSO experience
- Secure and scalable

**Alternative Options**:
1. HTTP Basic Authentication (simpler, less secure)
2. IP whitelisting + Basic Auth (if only specific IPs need access)
3. Keycloak login page redirect (simpler but less elegant)

## Implementation Plan

### Phase 1: SSL Certificate Setup

**Task 1.1**: Obtain SSL certificate for `consul.atparui.com`
- Option A: Use Let's Encrypt (free, automated renewal)
- Option B: Use existing certificate authority
- Store certificates in nginx SSL directory (typically `/etc/nginx/ssl/`)

**Files to create/update**:
- `/etc/nginx/ssl/consul.atparui.com.crt` (certificate)
- `/etc/nginx/ssl/consul.atparui.com.key` (private key)

---

### Phase 2: Keycloak Client Configuration

**Task 2.1**: Create a new Keycloak client for Consul UI authentication

**Client Details**:
- **Client ID**: `consul-ui`
- **Client Protocol**: `openid-connect`
- **Access Type**: `public` (or `confidential` if using client secret)
- **Valid Redirect URIs**: 
  - `https://consul.atparui.com/oauth2/callback`
  - `https://consul.atparui.com/oauth2/redirect`
- **Web Origins**: `https://consul.atparui.com`
- **Standard Flow Enabled**: Yes
- **Implicit Flow Enabled**: No
- **Direct Access Grants Enabled**: No (UI only)

**Realm**: Use existing realm (likely `gateway` or `master`)

**Task 2.2**: Configure client roles (optional)
- Create roles if role-based access is needed
- Assign roles to users who should access Consul UI

---

### Phase 3: Nginx Configuration Updates

**Task 3.1**: Update nginx configuration for Consul UI

**Location**: Update `nginx/nginx-secure.conf` or create new server block in main nginx config

**Key Components**:

1. **SSL Server Block** for `consul.atparui.com`:
   - Listen on port 443 with SSL
   - SSL certificate configuration
   - Security headers (HSTS, X-Frame-Options, etc.)

2. **Protected UI Path** (`/ui` and `/ui/*`):
   - Use `auth_request` module to validate with Keycloak
   - Proxy to Consul backend only if authenticated
   - Handle OAuth2 callback

3. **Unprotected API Path** (`/v1/*`):
   - Direct proxy to Consul backend
   - No authentication required (for internal services)

4. **OAuth2 Callback Handler**:
   - Handle `/oauth2/callback` endpoint
   - Exchange authorization code for tokens
   - Set session cookies

**Nginx Modules Required**:
- `ngx_http_auth_request_module` (for auth_request)
- `ngx_http_ssl_module` (for SSL)
- Standard proxy modules

**Task 3.2**: HTTP to HTTPS Redirect
- Add server block on port 80
- Redirect all HTTP traffic to HTTPS

---

### Phase 4: OAuth2 Authentication Flow Implementation

**Option A: Using nginx auth_request with Keycloak Token Validation**

**Flow**:
1. User accesses `https://consul.atparui.com/ui`
2. Nginx checks authentication via `auth_request` to Keycloak token validation endpoint
3. If not authenticated, redirect to Keycloak login
4. After login, Keycloak redirects back with authorization code
5. Nginx exchanges code for tokens (or uses session cookie)
6. User accesses Consul UI

**Implementation**:
- Use nginx `auth_request` directive pointing to Keycloak token validation
- Use `lua-resty-openidc` (if using OpenResty) or
- Use `oauth2_proxy` as sidecar, or
- Use custom nginx configuration with Keycloak endpoints

**Option B: Using oauth2_proxy (Recommended for Simplicity)**

**Flow**:
1. Deploy `oauth2_proxy` container/service
2. Configure it to use Keycloak as OAuth2 provider
3. Nginx routes `/ui` requests through oauth2_proxy
4. oauth2_proxy handles authentication and proxies to Consul

**Advantages**:
- Simpler nginx configuration
- Handles OAuth2 flow automatically
- Session management built-in
- Can be deployed as Docker container

**Option C: Using Keycloak Gatekeeper (Deprecated but still works)**

**Flow**:
1. Deploy Keycloak Gatekeeper
2. Configure as reverse proxy in front of Consul UI
3. Nginx routes to Gatekeeper, which handles auth

---

### Phase 5: Path-Based Routing Configuration

**Nginx Location Blocks**:

```nginx
# Consul UI - Protected
location /ui {
    auth_request /auth;
    proxy_pass http://consul_backend;
    # ... proxy settings
}

# Consul API - Unprotected (for internal services)
location /v1 {
    proxy_pass http://consul_backend;
    # ... proxy settings
}

# OAuth2 callback
location /oauth2/callback {
    # Handle OAuth2 callback
}

# Auth validation endpoint
location = /auth {
    internal;
    proxy_pass http://keycloak/realms/gateway/protocol/openid-connect/userinfo;
    # ... validation logic
}
```

---

### Phase 6: Testing and Validation

**Test Scenarios**:

1. **Unauthenticated Access**:
   - Access `https://consul.atparui.com/ui` → Should redirect to Keycloak login
   - After login → Should redirect back to Consul UI

2. **Authenticated Access**:
   - Access `https://consul.atparui.com/ui` → Should show Consul UI directly (if session exists)

3. **API Access** (should remain unchanged):
   - `curl https://consul.atparui.com/v1/status/leader` → Should work without auth
   - Internal services should still be able to access Consul API

4. **SSL Verification**:
   - Verify SSL certificate is valid
   - Check security headers are present
   - Test HTTP to HTTPS redirect

5. **Session Management**:
   - Test session timeout
   - Test logout functionality
   - Test token refresh

---

## Recommended Implementation Approach

### **Approach 1: oauth2_proxy (Easiest)**

**Steps**:
1. Deploy `oauth2_proxy` container alongside Consul
2. Configure oauth2_proxy with Keycloak OAuth2 settings
3. Update nginx to route `/ui` through oauth2_proxy
4. Keep `/v1` routes directly to Consul

**Pros**:
- Simple configuration
- Handles OAuth2 flow automatically
- Good documentation and community support
- Can be containerized

**Cons**:
- Additional service to manage
- Slight latency overhead

---

### **Approach 2: nginx auth_request with Keycloak (More Complex)**

**Steps**:
1. Configure Keycloak client
2. Use nginx `auth_request` module
3. Implement OAuth2 callback handling in nginx
4. May require OpenResty or custom Lua scripts

**Pros**:
- No additional services
- Full control over authentication flow
- Lower latency

**Cons**:
- More complex nginx configuration
- Requires nginx modules (auth_request, possibly Lua)
- More maintenance

---

### **Approach 3: HTTP Basic Auth (Simplest, Less Secure)**

**Steps**:
1. Create htpasswd file with users
2. Configure nginx basic auth for `/ui` path only
3. Keep `/v1` unprotected

**Pros**:
- Very simple
- No additional services
- Fast to implement

**Cons**:
- Less secure (no SSO)
- Manual user management
- No integration with Keycloak

---

## Detailed Configuration Files Needed

### 1. Nginx Configuration
**File**: Update `nginx/nginx-secure.conf` or main nginx config

**Changes**:
- Update server_name from `consul.your-domain.com` to `consul.atparui.com`
- Update SSL certificate paths
- Add path-based routing for `/ui` (protected) and `/v1` (unprotected)
- Add OAuth2 authentication configuration

### 2. Keycloak Client Configuration
**Method**: Via Keycloak Admin Console or REST API

**Settings**:
- Client ID, redirect URIs, web origins
- Client authentication settings
- Token settings

### 3. Docker Compose (if using oauth2_proxy)
**File**: `docker-compose.yml` or separate compose file

**Add**:
- oauth2_proxy service
- Environment variables for Keycloak connection
- Network configuration

### 4. Environment Variables
**File**: `.env` or `env.example`

**Add**:
- `CONSUL_UI_DOMAIN=consul.atparui.com`
- `CONSUL_UI_CLIENT_ID=consul-ui`
- `CONSUL_UI_CLIENT_SECRET=` (if using confidential client)
- `OAUTH2_PROXY_*` variables (if using oauth2_proxy)

---

## Security Considerations

### 1. Token Security
- Use secure, HTTP-only cookies for sessions
- Implement proper token validation
- Set appropriate token expiration times

### 2. API Protection (Optional Future Enhancement)
- Consider adding API key authentication for `/v1` endpoints if needed
- Use IP whitelisting for sensitive API operations
- Monitor API access logs

### 3. Network Security
- Ensure Consul container is not directly exposed to internet
- Only nginx should be accessible from outside
- Use firewall rules to restrict access

### 4. SSL/TLS
- Use strong SSL/TLS protocols (TLS 1.2+)
- Implement HSTS headers
- Regular certificate renewal

---

## Rollback Plan

If issues occur:

1. **Quick Rollback**: Comment out Consul server block in nginx, restart nginx
2. **Partial Rollback**: Remove authentication, keep SSL (temporary)
3. **Full Rollback**: Revert nginx config to previous version

**Backup Strategy**:
- Backup current nginx configuration before changes
- Document current Consul access method
- Test rollback procedure in non-production first

---

## Implementation Checklist

### Pre-Implementation
- [ ] Verify SSL certificate for `consul.atparui.com` is available
- [ ] Backup current nginx configuration
- [ ] Verify Keycloak is accessible and working
- [ ] Test current Consul UI access at `localhost:8500/ui`

### Keycloak Setup
- [ ] Create `consul-ui` client in Keycloak
- [ ] Configure client redirect URIs
- [ ] Configure web origins
- [ ] Test client configuration
- [ ] Create/assign user roles if needed

### Nginx Configuration
- [ ] Update server_name to `consul.atparui.com`
- [ ] Configure SSL certificates
- [ ] Add path-based routing (`/ui` protected, `/v1` unprotected)
- [ ] Configure OAuth2 authentication (choose approach)
- [ ] Add security headers
- [ ] Configure HTTP to HTTPS redirect
- [ ] Test nginx configuration syntax

### Testing
- [ ] Test SSL certificate validity
- [ ] Test HTTP to HTTPS redirect
- [ ] Test unauthenticated access to `/ui` (should redirect to login)
- [ ] Test authenticated access to `/ui` (should show UI)
- [ ] Test API access to `/v1` (should work without auth)
- [ ] Test session management
- [ ] Test logout functionality
- [ ] Verify internal services can still access Consul API

### Documentation
- [ ] Document new configuration
- [ ] Update any deployment scripts
- [ ] Document user access process
- [ ] Document troubleshooting steps

---

## Next Steps

1. **Choose Implementation Approach**: Decide between oauth2_proxy, nginx auth_request, or basic auth
2. **Obtain SSL Certificate**: Set up certificate for `consul.atparui.com`
3. **Configure Keycloak Client**: Create and configure the OAuth2 client
4. **Update Nginx Configuration**: Implement chosen authentication method
5. **Test Thoroughly**: Verify all scenarios work as expected
6. **Deploy**: Apply changes to production

---

## Questions to Clarify

Before implementation, confirm:

1. **Which Keycloak realm** should be used? (`gateway`, `master`, or new realm?)
2. **User access**: Who should have access? All authenticated users or specific roles?
3. **API access**: Should `/v1` API remain completely open or need some protection?
4. **SSL certificate**: Do you already have a certificate, or should we use Let's Encrypt?
5. **Preferred approach**: oauth2_proxy, nginx auth_request, or basic auth?
6. **Session timeout**: What should be the session duration?

---

## References

- [Nginx auth_request Module](http://nginx.org/en/docs/http/ngx_http_auth_request_module.html)
- [oauth2_proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Keycloak OAuth2/OIDC](https://www.keycloak.org/docs/latest/securing_apps/)
- [Consul UI Documentation](https://www.consul.io/docs/agent/web-ui)

