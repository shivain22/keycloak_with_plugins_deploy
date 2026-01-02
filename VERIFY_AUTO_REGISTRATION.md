# Verify Auto-Registration is Enabled

## Current Configuration Status

✅ **Both realm files have `enableAutoRegistration: "true"` configured:**

### Gateway Realm
- Location: `realm-import/gateway-realm.json`
- Config Alias: `phone-auto-reg-config`
- `enableAutoRegistration`: `"true"` ✅
- `autoRegPhoneAsUsername`: `"true"` ✅
- `loginWithPhoneVerify`: `"true"` ✅
- `loginWithPhoneNumber`: `"true"` ✅

### RMS Service Realm
- Location: `realm-import/rms-service-realm.json`
- Config Alias: `phone-auto-reg-config`
- `enableAutoRegistration`: `"true"` ✅
- `autoRegPhoneAsUsername`: `"true"` ✅
- `loginWithPhoneVerify`: `"true"` ✅
- `loginWithPhoneNumber`: `"true"` ✅

## Configuration Structure

The configuration is set in two places (both are required for Keycloak):

1. **Inline in the execution** (for immediate reference):
   ```json
   "authenticationConfig": {
     "alias": "phone-auto-reg-config",
     "config": {
       "enableAutoRegistration": "true",
       ...
     }
   }
   ```

2. **Separate authenticatorConfig array** (for persistence):
   ```json
   "authenticatorConfig": [
     {
       "alias": "phone-auto-reg-config",
       "config": {
         "enableAutoRegistration": "true",
         ...
       }
     }
   ]
   ```

## If Auto-Registration Shows as "Off" in Admin Console

If you see "Enable Auto Registration" as "Off" in the Keycloak admin console, it means:

1. **Realm hasn't been re-imported**: The realm configuration needs to be re-imported to apply the changes.

### Solution: Re-import the Realm

**Option 1: Restart Keycloak** (if auto-import is configured)
```bash
docker compose restart keycloak
```

**Option 2: Manual Import via Admin Console**
1. Go to **Realm Settings** > **Partial Import**
2. Select the realm JSON file (`gateway-realm.json` or `rms-service-realm.json`)
3. Check **Authentication** and **Authenticator config** options
4. Click **Import**

**Option 3: Manual Import via REST API**
```bash
# Get admin token first
ADMIN_TOKEN=$(curl -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  http://localhost:8080/realms/master/protocol/openid-connect/token | jq -r '.access_token')

# Import realm
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d @realm-import/gateway-realm.json \
  http://localhost:8080/admin/realms
```

**Option 4: Update Existing Flow Configuration**
1. Go to **Authentication** > **Flows**
2. Click on **browser with phone auto registration** flow
3. Click the gear icon next to **Phone Username Password Form with Auto Registration**
4. In the modal, toggle **Enable Auto Registration** to **On**
5. Click **Save**

## Verification Steps

After re-importing, verify the configuration:

1. **Check Admin Console**:
   - Go to **Authentication** > **Flows**
   - Click on **browser with phone auto registration**
   - Click gear icon next to **Phone Username Password Form with Auto Registration**
   - Verify **Enable Auto Registration** toggle is **On** ✅

2. **Check via REST API**:
   ```bash
   curl -X GET \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     http://localhost:8080/admin/realms/gateway/authentication/flows/browser%20with%20phone%20auto%20registration/executions
   ```

3. **Test Auto-Registration**:
   - Try logging in with a new phone number
   - Complete OTP verification
   - User should be auto-registered and logged in

## Configuration Values Reference

| Property | Value | Description |
|----------|-------|-------------|
| `enableAutoRegistration` | `"true"` | **Enable automatic user registration when phone is verified** |
| `autoRegPhoneAsUsername` | `"true"` | Use phone number as username for auto-registered users |
| `loginWithPhoneVerify` | `"true"` | Allow login using phone number and OTP verification |
| `loginWithPhoneNumber` | `"true"` | Allow login using phone number and password |

## Troubleshooting

### Issue: Configuration not applying after import

**Possible causes:**
1. Realm import didn't include authentication flows
2. Flow already exists and wasn't overwritten
3. Config alias mismatch

**Solution:**
- Delete the existing flow first, then re-import
- Or manually update the flow configuration in admin console

### Issue: Auto-registration still not working

**Check:**
1. Phone provider (MSG91) is configured
2. Duplicate phone is disabled in realm settings
3. Phone theme is active
4. Check Keycloak logs for errors

## Files to Check

- `realm-import/gateway-realm.json` - Line 436, 450
- `realm-import/rms-service-realm.json` - Line 404, 418

Both should have `"enableAutoRegistration": "true"` ✅

