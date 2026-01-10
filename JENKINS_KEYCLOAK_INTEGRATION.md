# Jenkins Keycloak Integration Guide

This guide explains how to configure Jenkins to use Keycloak for authentication, using the same `gateway` realm so that users can log in to **both Jenkins and the Gateway application** with the same credentials.

## Overview

The integration uses the OpenID Connect (OIDC) protocol through Keycloak. Users defined in the `gateway` realm can authenticate to:
- ✅ RMS Gateway Application
- ✅ Jenkins CI/CD
- ✅ Any other application using the same realm

## Pre-configured Users

The following users are pre-configured in the `gateway` realm:

| Username | Password | Gateway Role | Jenkins Role | Access Level |
|----------|----------|--------------|--------------|--------------|
| `platformadmin` | `PlatformAdmin123!` | ROLE_ADMIN | jenkins-admin | Full admin access to both |
| `gwadmin` | `gwadmin` | ROLE_ADMIN | jenkins-admin | Full admin access to both |
| `developer` | `Developer123!` | user | jenkins-developer | Can build/view jobs |
| `viewer` | `Viewer123!` | user | jenkins-viewer | Read-only access |

> **⚠️ Important:** Change these default passwords in production!

## Jenkins Roles Mapping

| Keycloak Role | Jenkins Permission |
|---------------|-------------------|
| `jenkins-admin` | Overall/Administer - Full control |
| `jenkins-developer` | Job/Build, Job/Read, Job/Workspace - Can build and view jobs |
| `jenkins-viewer` | Overall/Read, Job/Read - Read-only access |

## Setup Instructions

### Step 1: Install Jenkins OpenID Connect Plugin

1. Go to Jenkins → **Manage Jenkins** → **Manage Plugins**
2. Go to **Available plugins** tab
3. Search for **"OpenID Connect Authentication"** (by Michael Bischoff)
4. Install the plugin and restart Jenkins

### Step 2: Configure Keycloak Client (Already Done)

The `jenkins` client is pre-configured in `realm-import/gateway-realm.json` with:

```
Client ID: jenkins
Client Secret: J3nK1nS_S3cR3t_K3y_2024!@#
Redirect URIs: https://jenkins.atparui.com/securityRealm/finishLogin
```

### Step 3: Configure Jenkins Security

1. Go to Jenkins → **Manage Jenkins** → **Configure Global Security**

2. Under **Security Realm**, select **Login with Openid Connect**

3. Configure the following settings:

   | Setting | Value |
   |---------|-------|
   | **Client ID** | `jenkins` |
   | **Client Secret** | `J3nK1nS_S3cR3t_K3y_2024!@#` |
   | **Configuration mode** | Automatic configuration |
   | **Well-known configuration endpoint** | `https://auth.atparui.com/realms/gateway/.well-known/openid-configuration` |
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
   | **End session endpoint** | `https://auth.atparui.com/realms/gateway/protocol/openid-connect/logout` |

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
   | `jenkins-developer` | developer |
   | `jenkins-viewer` | viewer |

4. **If using Matrix-based security:**

   Add groups based on Keycloak roles:
   - `jenkins-admin` → All permissions
   - `jenkins-developer` → Build, Read permissions
   - `jenkins-viewer` → Read only

### Step 5: Save and Test

1. Click **Save** at the bottom of the page

2. **IMPORTANT:** Before saving, ensure you have at least one admin user configured, or you might lock yourself out!

3. Open a new incognito window and navigate to Jenkins

4. You should be redirected to Keycloak login page

5. Login with one of the pre-configured users (e.g., `platformadmin` / `PlatformAdmin123!`)

6. You should be redirected back to Jenkins with appropriate permissions

## Environment Variables

Add these to your `.env` file for reference:

```env
# Jenkins Keycloak Integration
JENKINS_KEYCLOAK_CLIENT_ID=jenkins
JENKINS_KEYCLOAK_CLIENT_SECRET=J3nK1nS_S3cR3t_K3y_2024!@#
JENKINS_KEYCLOAK_REALM=gateway
JENKINS_KEYCLOAK_AUTH_URL=https://auth.atparui.com
JENKINS_KEYCLOAK_DISCOVERY_URL=https://auth.atparui.com/realms/gateway/.well-known/openid-configuration
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

## Troubleshooting

### "Invalid redirect URI" Error

Make sure the redirect URI in Keycloak matches exactly:
- For production: `https://jenkins.atparui.com/securityRealm/finishLogin`
- For local: `http://localhost:8080/securityRealm/finishLogin`

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

To add new users that can access both Jenkins and Gateway:

### Option 1: Via Keycloak Admin Console

1. Login to Keycloak Admin Console: `https://auth.atparui.com/admin`
2. Select the `gateway` realm
3. Go to **Users** → **Add user**
4. Fill in user details
5. Go to **Credentials** tab → Set password (uncheck Temporary)
6. Go to **Role Mappings** → Assign roles:
   - For Gateway: `ROLE_ADMIN` or `user`
   - For Jenkins: `jenkins-admin`, `jenkins-developer`, or `jenkins-viewer`

### Option 2: Update realm-import JSON

Add users to `realm-import/gateway-realm.json` and re-import:

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
    "user",
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
| Keycloak Gateway Realm | https://auth.atparui.com/realms/gateway | - |
| Jenkins | https://jenkins.atparui.com | `platformadmin` / `PlatformAdmin123!` |
| Gateway App | https://rmsdashboard.atparui.com | `platformadmin` / `PlatformAdmin123!` |

## Related Documentation

- [JENKINS_SETUP.md](JENKINS_SETUP.md) - Jenkins Pipeline setup
- [GATEWAY_REALM_SETUP.md](GATEWAY_REALM_SETUP.md) - Gateway realm configuration
- [SECURE_SETUP.md](SECURE_SETUP.md) - Security best practices
