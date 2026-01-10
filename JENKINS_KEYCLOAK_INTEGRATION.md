# Jenkins Keycloak Integration Guide

This guide explains how to configure Jenkins to use Keycloak for authentication using the unified `atpar-infra` infrastructure realm.

## Overview

The integration uses the OpenID Connect (OIDC) protocol through Keycloak. Users defined in the `atpar-infra` realm can authenticate to Jenkins CI/CD as well as other infrastructure tools (Consul, Grafana, etc.).

> **Note:** Jenkins authentication has been consolidated into the `atpar-infra` realm for unified infrastructure access management.

## Pre-configured Users

The following users are pre-configured in the `atpar-infra` realm:

| Username | Password | Roles | Access Level |
|----------|----------|-------|--------------|
| `infra-admin` | `InfraAdmin@2024!` | infra-admin, jenkins-admin | Full admin access |
| `devops-lead` | `DevOps@2024!` | infra-admin, jenkins-admin | Full admin access |
| `developer` | `Developer@2024!` | infra-developer, jenkins-developer | Can build and view jobs |
| `viewer` | `Viewer@2024!` | infra-viewer, jenkins-viewer | Read-only access |

> **⚠️ Important:** Change these default passwords in production!

## Jenkins Roles

| Keycloak Role | Jenkins Permission |
|---------------|-------------------|
| `jenkins-admin` / `infra-admin` | Overall/Administer - Full control |
| `jenkins-developer` / `infra-developer` | Job/Build, Job/Read, Job/Workspace - Can build and view jobs |
| `jenkins-viewer` / `infra-viewer` | Overall/Read, Job/Read - Read-only access |

## Setup Instructions

### Step 1: Install Jenkins OpenID Connect Plugin

1. Go to Jenkins → **Manage Jenkins** → **Manage Plugins**
2. Go to **Available plugins** tab
3. Search for **"OpenID Connect Authentication"** (by Michael Bischoff)
4. Install the plugin and restart Jenkins

### Step 2: Keycloak Client (Already Configured)

The `jenkins` client is pre-configured in `realm-import/atpar-infra-realm.json` with:

```
Client ID: jenkins
Client Secret: AtP4rJ3nK1nSS3cR3t2024SecureKey
Realm: atpar-infra
Redirect URIs: https://jenkins.atparui.com/securityRealm/finishLogin
```

### Step 3: Configure Jenkins Security

1. Go to Jenkins → **Manage Jenkins** → **Configure Global Security**

2. Under **Security Realm**, select **Login with Openid Connect**

3. Configure the following settings:

   | Setting | Value |
   |---------|-------|
   | **Client ID** | `jenkins` |
   | **Client Secret** | `AtP4rJ3nK1nSS3cR3t2024SecureKey` |
   | **Configuration mode** | Automatic configuration |
   | **Well-known configuration endpoint** | `https://auth.atparui.com/realms/atpar-infra/.well-known/openid-configuration` |
   | **User name field name** | `preferred_username` |
   | **Full name field name** | `name` |
   | **Email field name** | `email` |
   | **Groups field name** | `roles` |

4. Click **Advanced** and configure:

   | Setting | Value |
   |---------|-------|
   | **Token field to check for groups** | `roles` |
   | **Scopes** | `openid profile email roles` |
   | **Enable logout** | ✅ Checked |
   | **Post logout redirect URL** | `https://jenkins.atparui.com` |
   | **End session endpoint** | `https://auth.atparui.com/realms/atpar-infra/protocol/openid-connect/logout` |

### Step 4: Configure Authorization

1. Still in **Configure Global Security**, under **Authorization**

2. Select **Role-Based Strategy** (requires Role-based Authorization Strategy plugin)
   
   OR use **Matrix-based security** with these settings:

3. **If using Role-Based Strategy:**
   
   Go to **Manage Jenkins** → **Manage and Assign Roles** → **Manage Roles**
   
   Create these roles:
   
   | Role Name | Permissions |
   |-----------|-------------|
   | `admin` | All permissions |
   | `developer` | Overall/Read, Job/Build, Job/Cancel, Job/Read, Job/Workspace, View/Read |
   | `viewer` | Overall/Read, Job/Read, View/Read |
   
   Then go to **Assign Roles** and map:
   
   | Keycloak Role | Jenkins Role |
   |---------------|--------------|
   | `jenkins-admin` | admin |
   | `infra-admin` | admin |
   | `jenkins-developer` | developer |
   | `infra-developer` | developer |
   | `jenkins-viewer` | viewer |
   | `infra-viewer` | viewer |

4. **If using Matrix-based security:**

   Add groups based on Keycloak roles:
   - `jenkins-admin` / `infra-admin` → All permissions
   - `jenkins-developer` / `infra-developer` → Build, Read permissions
   - `jenkins-viewer` / `infra-viewer` → Read only

### Step 5: Save and Test

1. Click **Save** at the bottom of the page

2. **IMPORTANT:** Before saving, ensure you have at least one admin user configured, or you might lock yourself out!

3. Open a new incognito window and navigate to Jenkins

4. You should be redirected to Keycloak login page (atpar-infra realm)

5. Login with the pre-configured user (e.g., `infra-admin` / `InfraAdmin@2024!`)

6. You should be redirected back to Jenkins with appropriate permissions

## Environment Variables

Add these to your `.env` file for reference:

```env
# Jenkins Keycloak Integration (atpar-infra realm)
JENKINS_KEYCLOAK_CLIENT_ID=jenkins
JENKINS_KEYCLOAK_CLIENT_SECRET=AtP4rJ3nK1nSS3cR3t2024SecureKey
JENKINS_KEYCLOAK_REALM=atpar-infra
JENKINS_KEYCLOAK_AUTH_URL=https://auth.atparui.com
JENKINS_KEYCLOAK_DISCOVERY_URL=https://auth.atparui.com/realms/atpar-infra/.well-known/openid-configuration
```

## Docker Compose Integration (Optional)

If you want to run Jenkins alongside Keycloak in Docker, add this to your `docker-compose.yml`:

```yaml
  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins
    depends_on:
      - keycloak
    ports:
      - "${JENKINS_HTTP_PORT:-8180}:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
    extra_hosts:
      - "auth.atparui.com:host-gateway"
    restart: unless-stopped

volumes:
  jenkins_home:
```

## Migration from atpar-jenkins Realm

If you were previously using the separate `atpar-jenkins` realm:

1. Update Jenkins OIDC configuration:
   - Change realm from `atpar-jenkins` to `atpar-infra`
   - Update Well-known endpoint URL
   - Update logout endpoint URL

2. Map both old and new roles:
   - `jenkins-admin` AND `infra-admin` → admin
   - `jenkins-developer` AND `infra-developer` → developer
   - `jenkins-viewer` AND `infra-viewer` → viewer

3. Users need to be recreated in `atpar-infra` realm (already done in realm JSON)

4. Delete the old `atpar-jenkins` realm from Keycloak (optional)

## Troubleshooting

### "Invalid redirect URI" Error

Make sure the redirect URI in Keycloak matches exactly:
- For production: `https://jenkins.atparui.com/securityRealm/finishLogin`
- For local: `http://localhost:8180/securityRealm/finishLogin`

### User logged in but no permissions

1. Check that roles are properly mapped in Jenkins
2. Verify the user has the correct roles in Keycloak (Users → select user → Role Mappings)
3. Check the `roles` claim in the JWT token

### Cannot reach Keycloak from Jenkins container

If Jenkins is running in Docker alongside Keycloak:
1. Add `extra_hosts` to map `auth.atparui.com` to the host
2. Or use internal Docker network URL: `http://keycloak:8080`

### Locked out of Jenkins

1. Stop Jenkins
2. Edit `$JENKINS_HOME/config.xml`
3. Set `<useSecurity>false</useSecurity>`
4. Restart Jenkins and reconfigure security

## Adding New Users

To add new users that can access Jenkins:

### Option 1: Via Keycloak Admin Console

1. Login to Keycloak Admin Console: `https://auth.atparui.com/admin`
2. Select the `atpar-infra` realm
3. Go to **Users** → **Add user**
4. Fill in user details
5. Go to **Credentials** tab → Set password (uncheck Temporary)
6. Go to **Role Mappings** → Assign roles:
   - `infra-admin` + `jenkins-admin` for full access
   - `infra-developer` + `jenkins-developer` for build access
   - `infra-viewer` + `jenkins-viewer` for read-only access

### Option 2: Update realm-import JSON

Add users to `realm-import/atpar-infra-realm.json` and re-import:

```json
{
  "username": "newuser",
  "enabled": true,
  "emailVerified": true,
  "firstName": "New",
  "lastName": "User",
  "email": "newuser@example.com",
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
  "requiredActions": [],
  "attributes": {
    "skipPhoneVerification": ["true"]
  }
}
```

## Security Best Practices

1. **Change default passwords** immediately in production
2. **Use HTTPS** for both Jenkins and Keycloak
3. **Rotate client secrets** periodically
4. **Enable MFA** in Keycloak for admin users
5. **Review and audit** role assignments regularly
6. **Use least privilege** - assign minimum required roles

## Quick Reference

| Service | URL | Default Admin |
|---------|-----|---------------|
| Keycloak Admin | https://auth.atparui.com/admin | `admin` / (from .env) |
| Keycloak atpar-infra Realm | https://auth.atparui.com/realms/atpar-infra | - |
| Jenkins | https://jenkins.atparui.com | `infra-admin` / `InfraAdmin@2024!` |

## Realm Configuration Summary

The `atpar-infra` realm contains:

- **Unified Roles:**
  - `infra-admin` - Full access to all infrastructure tools
  - `infra-developer` - Developer access (build, deploy, read/write)
  - `infra-viewer` - Read-only access

- **Jenkins-specific Roles:**
  - `jenkins-admin` - Full Jenkins administration access
  - `jenkins-developer` - Can build and view jobs
  - `jenkins-viewer` - Read-only access

- **Clients:**
  - `jenkins` - OIDC client for Jenkins authentication
  - `consul` - OAuth2 Proxy client for Consul UI
  - `grafana` - OIDC client for Grafana (future)
  - `argocd` - OIDC client for ArgoCD (future)

- **Pre-configured Users:**
  - `infra-admin` - Full access to all tools
  - `devops-lead` - Full access to all tools
  - `developer` - Developer access
  - `viewer` - Read-only access

## Related Documentation

- [INFRASTRUCTURE_REALM_SETUP.md](INFRASTRUCTURE_REALM_SETUP.md) - Infrastructure realm overview
- [CONSUL_OAUTH2_SETUP.md](CONSUL_OAUTH2_SETUP.md) - Consul OAuth2 Proxy setup
- [SECURE_SETUP.md](SECURE_SETUP.md) - Security best practices
- [GATEWAY_REALM_SETUP.md](GATEWAY_REALM_SETUP.md) - Gateway realm configuration
