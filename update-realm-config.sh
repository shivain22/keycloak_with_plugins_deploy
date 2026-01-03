#!/bin/bash
# Script to update Keycloak realm configuration via Admin API
# This is needed because Keycloak only imports realms when the database is empty
# Since the database has a persistent volume, we need to update via API

set -e

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:9292}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM_FILE="${1:-realm-import/gateway-realm.json}"

if [ ! -f "$REALM_FILE" ]; then
    echo "ERROR: Realm file not found: $REALM_FILE" >&2
    exit 1
fi

echo "=== Updating Keycloak Realm Configuration ==="
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Realm file: $REALM_FILE"
echo ""

# Get admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$KEYCLOAK_ADMIN" \
  -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || \
  jq -r '.access_token' 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
    echo "ERROR: Failed to get admin token. Check Keycloak is running and credentials are correct." >&2
    exit 1
fi

echo "✓ Admin token obtained"
echo ""

# Extract realm name from JSON file
REALM_NAME=$(python3 -c "import sys, json; print(json.load(open('$REALM_FILE'))['realm'])" 2>/dev/null || \
             jq -r '.realm' "$REALM_FILE" 2>/dev/null)

if [ -z "$REALM_NAME" ]; then
    echo "ERROR: Could not extract realm name from $REALM_FILE" >&2
    exit 1
fi

echo "Realm name: $REALM_NAME"
echo ""

# Update realm configuration
echo "Updating realm configuration..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/realm-update-response.json \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d @"$REALM_FILE" \
  "$KEYCLOAK_URL/admin/realms/$REALM_NAME")

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 204 ]; then
    echo "✓ Realm configuration updated successfully"
    echo ""
    echo "The following changes have been applied:"
    echo "  - Theme: rms-auth-theme-plugin"
    echo "  - Authentication flow: browser with phone auto registration"
    echo "  - Auto-registration: enabled"
    echo ""
    echo "Please verify in Keycloak Admin Console:"
    echo "  1. Realm Settings > Themes - should show 'rms-auth-theme-plugin'"
    echo "  2. Authentication > Flows - should show 'browser with phone auto registration'"
    echo "  3. Authentication > Flows > browser with phone auto registration"
    echo "     > Phone Username Password Form with Auto Registration"
    echo "     > Enable Auto Registration should be ON"
else
    echo "ERROR: Failed to update realm. HTTP code: $HTTP_CODE" >&2
    echo "Response:" >&2
    cat /tmp/realm-update-response.json >&2
    echo "" >&2
    exit 1
fi

