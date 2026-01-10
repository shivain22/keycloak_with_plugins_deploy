# Realm Configuration Update Summary

## Changes Made

Both `gateway-realm.json` and `rms-service-realm.json` have been updated with:

### 1. Theme Configuration
- **Login Theme**: `rms-auth-theme-plugin`
- **Account Theme**: `rms-auth-theme-plugin`
- **Admin Theme**: `rms-auth-theme-plugin`
- **Email Theme**: `rms-auth-theme-plugin`

### 2. Authentication Flow Configuration

#### New Flow: "browser with phone auto registration"
- **Type**: Browser flow (top-level)
- **Description**: Browser flow with Phone Username Password Form with Auto Registration
- **Structure**:
  ```
  browser with phone auto registration (top-level flow)
  ├── Cookie (ALTERNATIVE, priority 10)
  ├── Identity Provider Redirector (ALTERNATIVE, priority 20)
  └── forms (sub-flow, ALTERNATIVE, priority 30)
      └── Phone Username Password Form with Auto Registration (REQUIRED, priority 10)
  ```

#### Authenticator Configuration
- **Provider ID**: `auth-phone-auto-reg-form`
- **Display Name**: "Phone Username Password Form with Auto Registration"
- **Configuration**:
  - `enableAutoRegistration`: `true` - Automatically register users who don't exist
  - `autoRegPhoneAsUsername`: `true` - Use phone number as username for auto-registered users
  - `loginWithPhoneVerify`: `true` - Allow login using phone number and OTP verification
  - `loginWithPhoneNumber`: `true` - Allow login using phone number and password

### 3. Flow Binding
- **Browser Flow**: Set to `browser with phone auto registration`
- This replaces the default browser flow with the new phone-based flow

## Phone Provider Details

### Provider Information
- **Provider ID**: `auth-phone-auto-reg-form`
- **Class**: `cc.coopersoft.keycloak.phone.authentication.authenticators.browser.PhoneUsernamePasswordFormWithAutoRegistration`
- **JAR Files**:
  - `keycloak-phone-provider.jar` (main provider)
  - `keycloak-phone-provider-msg91.jar` (MSG91 SMS integration)

### Configuration Properties
| Property | Default | Description |
|----------|---------|-------------|
| `enableAutoRegistration` | `false` | Automatically register users who don't exist when they successfully verify their phone number |
| `autoRegPhoneAsUsername` | `true` | Use phone number as username for auto-registered users |
| `loginWithPhoneVerify` | `true` | Allow login using phone number and OTP verification |
| `loginWithPhoneNumber` | `true` | Allow login using phone number and password |

## Theme Details

### Theme Information
- **Theme Name**: `rms-auth-theme-plugin`
- **JAR File**: `keycloak-theme-for-kc-26.2-and-above.jar`
- **Location**: `providers/keycloak-theme-for-kc-26.2-and-above.jar`
- **Repository**: `https://github.com/atpar-org/rms-auth-theme-plugin.git`

## How It Works

1. **User Login Flow**:
   - User enters phone number on login screen
   - System sends OTP to phone number
   - User enters OTP code
   - If user exists: Normal login
   - If user doesn't exist: Auto-registration (if enabled)

2. **Auto-Registration**:
   - New user is created automatically
   - Username: Phone number (if `autoRegPhoneAsUsername` is true)
   - Phone number stored as user attribute
   - Phone verified flag set to true

## Deployment

### Importing the Realm Configuration

The realm configurations will be automatically imported when Keycloak starts if:
- The files are in the `realm-import/` directory
- Keycloak is configured to import realms on startup

### Manual Import (if needed)

1. **Via Admin Console**:
   - Go to **Realm Settings** > **Import**
   - Select the realm JSON file
   - Click **Import**

2. **Via REST API**:
   ```bash
   curl -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <admin-token>" \
     -d @realm-import/gateway-realm.json \
     http://localhost:8080/admin/realms
   ```

### Verification

After deployment, verify:
1. **Theme**: Login page should use `rms-auth-theme-plugin` theme
2. **Authentication Flow**: 
   - Go to **Authentication** > **Flows**
   - Verify "browser with phone auto registration" flow exists
   - Check that it's set as the Browser Flow in **Bindings**
3. **Authenticator**: 
   - In the flow, verify "Phone Username Password Form with Auto Registration" is present
   - Check its configuration matches the settings above

## Testing

1. **Test Existing User Login**:
   - Enter phone number of existing user
   - Should follow normal login flow

2. **Test Auto-Registration**:
   - Enter new phone number
   - Complete OTP verification
   - User should be auto-registered and logged in

3. **Test Theme**:
   - Login page should display custom theme
   - Check for theme-specific styling and components

## Troubleshooting

### Theme Not Applied
- Verify theme JAR is in `providers/` directory
- Check Keycloak logs for theme loading errors
- Ensure theme name matches exactly: `rms-auth-theme-plugin`

### Authentication Flow Not Working
- Verify phone provider JARs are in `providers/` directory
- Check Keycloak logs for authenticator errors
- Verify flow is set as Browser Flow in Bindings
- Check authenticator configuration values

### Auto-Registration Not Working
- Verify `enableAutoRegistration` is set to `true`
- Check that duplicate phone is disabled in realm settings
- Ensure phone provider (MSG91) is configured
- Check Keycloak logs for auto-registration events

## Files Modified

- `realm-import/gateway-realm.json`
- `realm-import/rms-service-realm.json`

## Next Steps

1. Restart Keycloak to apply the new realm configurations
2. Verify the theme is applied on the login page
3. Test the phone authentication flow
4. Test auto-registration with a new phone number
5. Monitor Keycloak logs for any errors

