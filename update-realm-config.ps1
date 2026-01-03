# PowerShell script to update Keycloak realm configuration via Admin API
# This is needed because Keycloak only imports realms when the database is empty
# Since the database has a persistent volume, we need to update via API

param(
    [string]$KeycloakUrl = "http://localhost:9292",
    [string]$KeycloakAdmin = "admin",
    [string]$KeycloakAdminPassword = "admin",
    [string]$RealmFile = "realm-import\gateway-realm.json"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Updating Keycloak Realm Configuration ===" -ForegroundColor Cyan
Write-Host "Keycloak URL: $KeycloakUrl"
Write-Host "Realm file: $RealmFile"
Write-Host ""

if (-not (Test-Path $RealmFile)) {
    Write-Host "ERROR: Realm file not found: $RealmFile" -ForegroundColor Red
    exit 1
}

# Get admin token
Write-Host "Getting admin token..." -ForegroundColor Yellow
$tokenBody = @{
    username = $KeycloakAdmin
    password = $KeycloakAdminPassword
    grant_type = "password"
    client_id = "admin-cli"
} | ConvertTo-Json

try {
    $tokenResponse = Invoke-RestMethod -Uri "$KeycloakUrl/realms/master/protocol/openid-connect/token" `
        -Method Post `
        -ContentType "application/x-www-form-urlencoded" `
        -Body "username=$KeycloakAdmin&password=$KeycloakAdminPassword&grant_type=password&client_id=admin-cli"
    
    $adminToken = $tokenResponse.access_token
    
    if (-not $adminToken) {
        Write-Host "ERROR: Failed to get admin token. Check Keycloak is running and credentials are correct." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Admin token obtained" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "ERROR: Failed to get admin token: $_" -ForegroundColor Red
    exit 1
}

# Extract realm name from JSON file
try {
    $realmJson = Get-Content $RealmFile | ConvertFrom-Json
    $realmName = $realmJson.realm
    
    if (-not $realmName) {
        Write-Host "ERROR: Could not extract realm name from $RealmFile" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Realm name: $realmName" -ForegroundColor Cyan
    Write-Host ""
} catch {
    Write-Host "ERROR: Failed to parse realm file: $_" -ForegroundColor Red
    exit 1
}

# Update realm configuration
Write-Host "Updating realm configuration..." -ForegroundColor Yellow
try {
    $realmContent = Get-Content $RealmFile -Raw
    
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $adminToken"
    }
    
    $response = Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$realmName" `
        -Method Put `
        -Headers $headers `
        -Body $realmContent
    
    Write-Host "✓ Realm configuration updated successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "The following changes have been applied:" -ForegroundColor Cyan
    Write-Host "  - Theme: rms-auth-theme-plugin"
    Write-Host "  - Authentication flow: browser with phone auto registration"
    Write-Host "  - Auto-registration: enabled"
    Write-Host ""
    Write-Host "Please verify in Keycloak Admin Console:" -ForegroundColor Yellow
    Write-Host "  1. Realm Settings > Themes - should show 'rms-auth-theme-plugin'"
    Write-Host "  2. Authentication > Flows - should show 'browser with phone auto registration'"
    Write-Host "  3. Authentication > Flows > browser with phone auto registration"
    Write-Host "     > Phone Username Password Form with Auto Registration"
    Write-Host "     > Enable Auto Registration should be ON"
    
} catch {
    Write-Host "ERROR: Failed to update realm: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

