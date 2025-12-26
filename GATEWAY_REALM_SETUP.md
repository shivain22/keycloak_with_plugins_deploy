# Gateway Realm Setup Guide

This document describes the gateway realm configuration and post-import setup steps.

## Overview

The `gateway` realm is designed to:
- Authenticate the gateway application (frontend and backend)
- Provide a service account client for managing other realms via Keycloak Admin API
- Include role-based access control with `ROLE_ADMIN` role
- Map roles to token claims for easy access by gateway applications

## Realm Configuration

### Default User
- **Username**: `gwadmin`
- **Password**: `gwadmin` (⚠️ **CHANGE THIS IN PRODUCTION**)
- **Email**: `gwadmin@gateway.local`
- **Roles**: `ROLE_ADMIN`

### Realm Roles
- **ROLE_ADMIN**: Administrator role for gateway operations
- **user**: Default user role

### Clients

#### 1. gateway-admin-client
- **Type**: Confidential client with service account
- **Purpose**: Service account for gateway backend to manage realms via Admin API
- **Client Secret**: `gateway-admin-secret-change-me` (⚠️ **CHANGE THIS IN PRODUCTION**)
- **Service Account**: Enabled
- **Flows**: Service account only (no user flows)

#### 2. gateway-frontend
- **Type**: Public client
- **Purpose**: Frontend application authentication
- **Flows**: Authorization Code, Direct Access Grants
- **Root URL**: `http://localhost:8082`
- **Home URL**: `http://localhost:8082`
- **Admin URL**: `http://localhost:8082`
- **Redirect URIs**: `http://localhost:9000/login/oauth2/code/oidc`
- **Post Logout Redirect URIs**: `http://localhost:9000`
- **Web Origins**: `http://localhost:8082`, `http://localhost:9000`

#### 3. gateway-backend
- **Type**: Confidential client
- **Purpose**: Backend application authentication
- **Client Secret**: `gateway-backend-secret-change-me` (⚠️ **CHANGE THIS IN PRODUCTION**)
- **Flows**: Authorization Code, Direct Access Grants
- **Root URL**: `http://localhost:8082`
- **Home URL**: `http://localhost:8082`
- **Admin URL**: `http://localhost:8082`
- **Redirect URIs**: `http://localhost:9000/login/oauth2/code/oidc`
- **Post Logout Redirect URIs**: `http://localhost:9000`
- **Web Origins**: `http://localhost:8082`, `http://localhost:9000`

### Role Mapping in Tokens

The realm includes a custom client scope `gateway-roles` that adds roles as a flat array in token claims:

```json
{
  "roles": ["ROLE_ADMIN", "user"],
  "realm_access": {
    "roles": ["ROLE_ADMIN", "user"]
  }
}
```

This allows both the gateway frontend and backend to easily access user roles from the `roles` claim.

## Post-Import Setup: Granting Realm Management Permissions

To allow the `gateway-admin-client` service account to create and manage realms, you need to grant it permissions in the **master realm**:

### Option 1: Using Admin Console (Recommended)

1. Log in to Keycloak Admin Console as the master realm admin
2. Navigate to **Master Realm** → **Clients** → Find `realm-management` client
3. Go to **Service Accounts Roles** tab
4. Click **Assign role**
5. Filter by clients and select `gateway-admin-client` from the `gateway` realm
6. Assign the following roles:
   - `realm-admin` (or `create-realm` if you only want creation)
   - `manage-realm` (for full realm management)
   - `view-realm` (to view realm details)

### Option 2: Using Admin CLI

```bash
# Get access token for master realm admin
TOKEN=$(curl -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

# Get service account user ID for gateway-admin-client
SERVICE_ACCOUNT_USER_ID=$(curl -X GET "http://localhost:8080/admin/realms/gateway/clients?clientId=gateway-admin-client" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].serviceAccountsEnabled')

# Get the service account user details
SERVICE_USER=$(curl -X GET "http://localhost:8080/admin/realms/gateway/clients?clientId=gateway-admin-client" \
  -H "Authorization: Bearer $TOKEN")

# Get realm-management client UUID in master realm
REALM_MGMT_CLIENT_ID=$(curl -X GET "http://localhost:8080/admin/realms/master/clients?clientId=realm-management" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

# Get realm-admin role UUID
REALM_ADMIN_ROLE=$(curl -X GET "http://localhost:8080/admin/realms/master/clients/$REALM_MGMT_CLIENT_ID/roles/realm-admin" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.id')

# Assign role to service account
# (This requires getting the service account user ID first - see Keycloak Admin API docs)
```

### Option 3: Using Keycloak Admin REST API (Programmatic)

After the realm is imported, use the Admin REST API to grant permissions. Here's a Python example:

```python
import requests

# Get admin token
admin_token = requests.post(
    "http://localhost:8080/realms/master/protocol/openid-connect/token",
    data={
        "username": "admin",
        "password": "admin",
        "grant_type": "password",
        "client_id": "admin-cli"
    }
).json()["access_token"]

headers = {"Authorization": f"Bearer {admin_token}"}

# Get gateway-admin-client service account user ID
gateway_client = requests.get(
    "http://localhost:8080/admin/realms/gateway/clients?clientId=gateway-admin-client",
    headers=headers
).json()[0]

service_account_user_id = gateway_client["serviceAccountsEnabled"]

# Get service account user
service_user = requests.get(
    f"http://localhost:8080/admin/realms/gateway/users",
    headers=headers,
    params={"serviceAccountClientId": gateway_client["id"]}
).json()[0]

# Get realm-management client in master realm
realm_mgmt = requests.get(
    "http://localhost:8080/admin/realms/master/clients?clientId=realm-management",
    headers=headers
).json()[0]

# Get realm-admin role
realm_admin_role = requests.get(
    f"http://localhost:8080/admin/realms/master/clients/{realm_mgmt['id']}/roles/realm-admin",
    headers=headers
).json()

# Assign role to service account user
requests.post(
    f"http://localhost:8080/admin/realms/master/users/{service_user['id']}/role-mappings/clients/{realm_mgmt['id']}",
    headers=headers,
    json=[realm_admin_role]
)
```

## Using the Service Account

Once permissions are granted, the gateway backend can use the service account to manage realms:

```bash
# Get service account token
TOKEN=$(curl -X POST "http://localhost:8080/realms/gateway/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=gateway-admin-client" \
  -d "client_secret=gateway-admin-secret-change-me" | jq -r '.access_token')

# Create a new realm (requires realm-admin role in master realm)
curl -X POST "http://localhost:8080/admin/realms" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "new-tenant-realm",
    "enabled": true
  }'
```

## Security Recommendations

1. **Change Default Passwords**: Update the default admin user password (`gwadmin`)
2. **Change Client Secrets**: Update all client secrets in production
3. **Update URLs for Production**: Change `localhost` URLs to your production domain for:
   - Root URL, Home URL, Admin URL
   - Redirect URIs
   - Post Logout Redirect URIs
   - Web Origins
4. **Use HTTPS**: Ensure `sslRequired` is set to `external` or `all` in production, and use `https://` URLs
5. **Rotate Secrets**: Regularly rotate client secrets and user passwords
6. **Principle of Least Privilege**: Only grant the minimum required permissions to the service account

## Token Claims Structure

After authentication, tokens will include:

```json
{
  "sub": "user-uuid",
  "email": "gwadmin@gateway.local",
  "roles": ["ROLE_ADMIN"],
  "realm_access": {
    "roles": ["ROLE_ADMIN"]
  },
  "resource_access": {
    "gateway-frontend": {
      "roles": []
    }
  }
}
```

The `roles` claim provides a flat array of all realm roles (configured via the `gateway-roles` client scope), making it easy for applications to check user permissions. The claim name is `roles` and it contains all realm roles assigned to the user.

