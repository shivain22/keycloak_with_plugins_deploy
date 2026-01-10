# Domain and Redirect URI Fixes

## Summary

This document summarizes the changes made to fix domain references and post-logout redirect URIs.

## Changes Made

### 1. Domain Update
- **Status**: ✅ Already using `auth.atparui.com` throughout
- **Note**: No references to `rmsauth.atparui.com` were found in the codebase

### 2. Post-Logout Redirect URIs Fix

#### Problem
Post-logout redirect URIs were stored as comma-separated strings in the `attributes` section of realm JSON files, which could cause Keycloak to treat them as invalid URIs.

#### Solution
Converted all post-logout redirect URIs from comma-separated strings in `attributes.post.logout.redirect.uris` to proper JSON arrays in the `postLogoutRedirectUris` field.

#### Files Updated

**atpar-infra-realm.json:**
- `jenkins` client: Changed from `"https://jenkins.atparui.com,http://localhost:8180"` to array format
- `consul` client: Changed from `"https://consul.atparui.com"` to array format
- `grafana` client: Changed from `"https://grafana.atparui.com"` to array format
- `argocd` client: Changed from `"https://argocd.atparui.com"` to array format

**gateway-realm.json:**
- `gateway-web` client: Changed from `"http://localhost:9000,https://rmsdashboard.atparui.com,https://rmsgateway.atparui.com"` to array format
- `gateway-mobile` client: Changed from `"http://localhost:9000,https://rmsdashboard.atparui.com"` to array format

#### Format Change

**Before:**
```json
"attributes": {
  "post.logout.redirect.uris": "https://example.com,https://example2.com"
}
```

**After:**
```json
"attributes": {
  // post.logout.redirect.uris removed from here
},
"postLogoutRedirectUris": [
  "https://example.com",
  "https://example2.com"
]
```

### 3. Docker Compose OAuth2 Proxy Configuration

#### Problem
OAuth2 Proxy for Consul was configured to use the `gateway` realm instead of the `atpar-infra` realm.

#### Solution
Updated `docker-compose.yml` to use the correct realm and client:
- Changed `OAUTH2_PROXY_CLIENT_ID` from `gateway-web` to `consul`
- Changed `OAUTH2_PROXY_CLIENT_SECRET` from gateway secret to `C0nSuL@InFrA2024SecureKey!`
- Changed `OAUTH2_PROXY_OIDC_ISSUER_URL` from `https://auth.atparui.com/realms/gateway` to `https://auth.atparui.com/realms/atpar-infra`

#### Updated Configuration
```yaml
- --client-id=${OAUTH2_PROXY_CLIENT_ID:-consul}
- --client-secret=${OAUTH2_PROXY_CLIENT_SECRET:-C0nSuL@InFrA2024SecureKey!}
- --oidc-issuer-url=${OAUTH2_PROXY_OIDC_ISSUER_URL:-https://auth.atparui.com/realms/atpar-infra}
```

## Verification Steps

1. **Import Realms**: After updating the realm JSON files, re-import them into Keycloak
2. **Verify Post-Logout URIs**: Check in Keycloak Admin Console that post-logout redirect URIs are properly listed as separate entries
3. **Test OAuth2 Proxy**: Verify that Consul UI authentication works with the `atpar-infra` realm
4. **Test Logout**: Test logout flows for all clients to ensure proper redirects

## Related Documentation

- [Infrastructure Realm Setup](./realms/INFRASTRUCTURE_REALM_SETUP.md)
- [Gateway Realm Setup](./realms/GATEWAY_REALM_SETUP.md)
- [Consul OAuth2 Setup](./infrastructure/CONSUL_OAUTH2_SETUP.md)

## Date
Updated: $(Get-Date -Format "yyyy-MM-dd")
