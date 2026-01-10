# Infrastructure Realm Setup Guide

## Overview

The `atpar-infra` realm provides unified authentication for all infrastructure and DevOps tools. This eliminates the need for separate realms per tool, simplifying user management and providing single sign-on (SSO) across all infrastructure services.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              KEYCLOAK                                       │
├─────────────────┬─────────────────┬─────────────────────────────────────────┤
│   atpar-infra   │    gateway      │           Tenant Realms                 │
│   (DevOps)      │  (SaaS Admin)   │         (Per Customer)                  │
├─────────────────┼─────────────────┼─────────────────────────────────────────┤
│ • Jenkins       │ • Gateway Admin │ • {tenant}-realm                        │
│ • Consul        │   Panel         │ • Created dynamically                   │
│ • Grafana       │ • Platform Mgmt │   when tenant registers                 │
│ • ArgoCD        │ • Tenant Mgmt   │                                         │
│ • SonarQube     │                 │                                         │
└─────────────────┴─────────────────┴─────────────────────────────────────────┘
```

## Realm Files

| Realm | File | Purpose |
|-------|------|---------|
| `atpar-infra` | `realm-import/atpar-infra-realm.json` | Infrastructure tools (Jenkins, Consul, etc.) |
| `gateway` | `realm-import/gateway-realm.json` | SaaS Gateway admin panel |

> **Note:** The `atpar-jenkins` realm has been deprecated. Use `atpar-infra` instead.

## Pre-configured Users

| Username | Password | Roles | Access |
|----------|----------|-------|--------|
| `infra-admin` | `InfraAdmin@2024!` | infra-admin, jenkins-admin | Full access to all tools |
| `devops-lead` | `DevOps@2024!` | infra-admin, jenkins-admin | Full access to all tools |
| `developer` | `Developer@2024!` | infra-developer, jenkins-developer | Build/deploy access |
| `viewer` | `Viewer@2024!` | infra-viewer, jenkins-viewer | Read-only access |

> **⚠️ IMPORTANT:** Change all default passwords in production!

## Role Hierarchy

### Unified Roles (Apply to ALL tools)

| Role | Description |
|------|-------------|
| `infra-admin` | Full administrative access to all infrastructure tools |
| `infra-developer` | Can build, deploy, and modify configurations |
| `infra-viewer` | Read-only access to all tools |

### Tool-Specific Roles

| Role | Tool | Permission |
|------|------|------------|
| `jenkins-admin` | Jenkins | Full admin |
| `jenkins-developer` | Jenkins | Build jobs |
| `jenkins-viewer` | Jenkins | Read-only |

## Role Mapping by Tool

| Role | Jenkins | Consul | Grafana | ArgoCD |
|------|---------|--------|---------|--------|
| `infra-admin` | Admin | Full ACL | Admin | Admin |
| `infra-developer` | Build/Deploy | Read/Write | Editor | Sync |
| `infra-viewer` | Read-only | Read-only | Viewer | Read-only |

## Clients Configuration

### Jenkins

| Setting | Value |
|---------|-------|
| Client ID | `jenkins` |
| Client Secret | `AtP4rJ3nK1nSS3cR3t2024SecureKey` |
| Redirect URI | `https://jenkins.atparui.com/securityRealm/finishLogin` |
| Scopes | `openid profile email roles` |

### Consul (via OAuth2 Proxy)

| Setting | Value |
|---------|-------|
| Client ID | `consul` |
| Client Secret | `C0nSuL@InFrA2024SecureKey!` |
| Redirect URI | `https://consul.atparui.com/oauth2/callback` |
| Scopes | `openid profile email` |

### Grafana (Future)

| Setting | Value |
|---------|-------|
| Client ID | `grafana` |
| Client Secret | `GrAfAnA@InFrA2024SecureKey!` |
| Redirect URI | `https://grafana.atparui.com/login/generic_oauth` |
| Scopes | `openid profile email` |

### ArgoCD (Future)

| Setting | Value |
|---------|-------|
| Client ID | `argocd` |
| Client Secret | `ArG0CD@InFrA2024SecureKey!` |
| Redirect URI | `https://argocd.atparui.com/auth/callback` |
| Scopes | `openid profile email groups` |

## Quick Setup

### 1. Import the Realm

The realm is automatically imported when Keycloak starts if configured in `docker-compose.yml`:

```yaml
keycloak:
  volumes:
    - ./realm-import:/opt/keycloak/data/import
  command: start-dev --import-realm
```

Or import manually:
```bash
# Via Admin Console
# 1. Login to https://auth.atparui.com/admin
# 2. Click "Create realm"
# 3. Upload realm-import/atpar-infra-realm.json
```

### 2. Configure Each Tool

See individual setup guides:
- [JENKINS_KEYCLOAK_INTEGRATION.md](JENKINS_KEYCLOAK_INTEGRATION.md)
- [CONSUL_OAUTH2_SETUP.md](CONSUL_OAUTH2_SETUP.md)

### 3. Verify SSO

1. Login to Jenkins → Redirected to Keycloak → Login once
2. Navigate to Consul → Already authenticated (SSO)
3. Navigate to Grafana → Already authenticated (SSO)

## Environment Variables

Add to your `.env` file:

```bash
# Infrastructure Realm Configuration
INFRA_KEYCLOAK_REALM=atpar-infra
INFRA_KEYCLOAK_AUTH_URL=https://auth.atparui.com
INFRA_KEYCLOAK_DISCOVERY_URL=https://auth.atparui.com/realms/atpar-infra/.well-known/openid-configuration

# Jenkins
JENKINS_KEYCLOAK_CLIENT_ID=jenkins
JENKINS_KEYCLOAK_CLIENT_SECRET=AtP4rJ3nK1nSS3cR3t2024SecureKey

# Consul OAuth2 Proxy
OAUTH2_PROXY_CLIENT_ID=consul
OAUTH2_PROXY_CLIENT_SECRET=C0nSuL@InFrA2024SecureKey!
OAUTH2_PROXY_OIDC_ISSUER_URL=https://auth.atparui.com/realms/atpar-infra

# Grafana (future)
GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=GrAfAnA@InFrA2024SecureKey!

# ArgoCD (future)
ARGOCD_OIDC_CLIENT_ID=argocd
ARGOCD_OIDC_CLIENT_SECRET=ArG0CD@InFrA2024SecureKey!
```

## Adding New Users

### Via Keycloak Admin Console

1. Login to `https://auth.atparui.com/admin`
2. Select `atpar-infra` realm
3. Users → Add user
4. Set credentials (Credentials tab)
5. Assign roles (Role Mappings tab):
   - For full access: `infra-admin`, `jenkins-admin`
   - For developer: `infra-developer`, `jenkins-developer`
   - For viewer: `infra-viewer`, `jenkins-viewer`

### Via Realm JSON

Add to `realm-import/atpar-infra-realm.json` under `users` array:

```json
{
  "username": "newuser",
  "enabled": true,
  "emailVerified": true,
  "firstName": "New",
  "lastName": "User",
  "email": "newuser@atparui.com",
  "credentials": [
    {
      "type": "password",
      "value": "SecurePassword123!",
      "temporary": false
    }
  ],
  "realmRoles": [
    "infra-developer",
    "jenkins-developer"
  ],
  "attributes": {
    "skipPhoneVerification": ["true"]
  }
}
```

## Adding New Infrastructure Tools

### 1. Add Client to Realm JSON

Add to `clients` array in `atpar-infra-realm.json`:

```json
{
  "clientId": "newtool",
  "name": "New Tool",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "secret": "YourSecureSecretHere",
  "publicClient": false,
  "standardFlowEnabled": true,
  "protocol": "openid-connect",
  "redirectUris": [
    "https://newtool.atparui.com/callback"
  ],
  "webOrigins": ["https://newtool.atparui.com"],
  "defaultClientScopes": [
    "openid", "profile", "email", "infra-roles"
  ]
}
```

### 2. Configure the Tool

Each tool has its own OIDC configuration. Common settings:

| Setting | Value |
|---------|-------|
| Discovery URL | `https://auth.atparui.com/realms/atpar-infra/.well-known/openid-configuration` |
| Authorization Endpoint | `https://auth.atparui.com/realms/atpar-infra/protocol/openid-connect/auth` |
| Token Endpoint | `https://auth.atparui.com/realms/atpar-infra/protocol/openid-connect/token` |
| Userinfo Endpoint | `https://auth.atparui.com/realms/atpar-infra/protocol/openid-connect/userinfo` |
| Logout Endpoint | `https://auth.atparui.com/realms/atpar-infra/protocol/openid-connect/logout` |

## Comparison: Before vs After

### Before (Separate Realms)

```
❌ atpar-jenkins realm  →  Jenkins only
❌ gateway realm        →  Consul (wrong place)
❌ User duplication across realms
❌ No SSO between tools
❌ Multiple passwords to manage
```

### After (Unified Realm)

```
✅ atpar-infra realm    →  ALL infrastructure tools
✅ gateway realm        →  SaaS Gateway only
✅ Single user directory
✅ Full SSO across tools
✅ One login for everything
```

## Security Best Practices

1. **Change ALL default passwords** before production deployment
2. **Rotate client secrets** every 90 days
3. **Enable MFA** for all admin users in Keycloak
4. **Use HTTPS** everywhere (already configured)
5. **Audit logs** - Review Keycloak login events regularly
6. **Least privilege** - Assign minimum required roles
7. **Separate realms** - Keep infrastructure separate from tenant realms

## Troubleshooting

### Cannot login to any tool

1. Verify Keycloak is running: `curl https://auth.atparui.com/realms/atpar-infra`
2. Check realm exists in Keycloak admin console
3. Verify user exists and is enabled
4. Check user has required roles

### SSO not working between tools

1. Ensure all tools use the same realm (`atpar-infra`)
2. Check browser allows third-party cookies
3. Verify session timeout settings are consistent

### Role-based access not working

1. Check `roles` claim is included in token
2. Verify `infra-roles` scope is assigned to client
3. Check tool's role mapping configuration

## Related Documentation

- [JENKINS_KEYCLOAK_INTEGRATION.md](JENKINS_KEYCLOAK_INTEGRATION.md) - Jenkins setup details
- [CONSUL_OAUTH2_SETUP.md](CONSUL_OAUTH2_SETUP.md) - Consul OAuth2 Proxy setup
- [GATEWAY_REALM_SETUP.md](GATEWAY_REALM_SETUP.md) - Gateway realm for SaaS admin
- [SECURE_SETUP.md](SECURE_SETUP.md) - Overall security configuration
