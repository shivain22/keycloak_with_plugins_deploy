# Generate realm JSON files from templates with environment variable substitution
# Usage: .\scripts\generate-realm-configs.ps1 [local|dev|staging|prod]

param(
    [string]$Env = "local"
)

$ErrorActionPreference = "Stop"

$REPO_ROOT = Split-Path -Parent $PSScriptRoot
Set-Location $REPO_ROOT

# Load environment variables from .env file if it exists
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

# Set defaults based on environment (will be overridden in switch statement)
$GATEWAY_HTTP_PORT = if ($env:GATEWAY_HTTP_PORT) { $env:GATEWAY_HTTP_PORT } else { "9293" }
$SERVICE_HTTP_PORT = if ($env:SERVICE_HTTP_PORT) { $env:SERVICE_HTTP_PORT } else { "9294" }
$KEYCLOAK_HTTP_PORT = if ($env:KEYCLOAK_HTTP_PORT) { $env:KEYCLOAK_HTTP_PORT } else { "9292" }

switch ($Env) {
    "local" {
        $GATEWAY_HTTP_PORT = if ($env:GATEWAY_HTTP_PORT) { $env:GATEWAY_HTTP_PORT } else { "9293" }
        $SERVICE_HTTP_PORT = if ($env:SERVICE_HTTP_PORT) { $env:SERVICE_HTTP_PORT } else { "9294" }
        $KEYCLOAK_HTTP_PORT = if ($env:KEYCLOAK_HTTP_PORT) { $env:KEYCLOAK_HTTP_PORT } else { "9292" }
        $GATEWAY_URL = if ($env:GATEWAY_URL) { $env:GATEWAY_URL } else { "http://localhost:$GATEWAY_HTTP_PORT" }
        $SERVICE_URL = if ($env:SERVICE_URL) { $env:SERVICE_URL } else { "http://localhost:$SERVICE_HTTP_PORT" }
        $FRONTEND_URL = if ($env:FRONTEND_URL) { $env:FRONTEND_URL } else { "http://localhost:9000" }
        $KEYCLOAK_URL = if ($env:KEYCLOAK_URL) { $env:KEYCLOAK_URL } else { "http://localhost:$KEYCLOAK_HTTP_PORT" }
        $GATEWAY_URL_PROD = if ($env:GATEWAY_URL_PROD) { $env:GATEWAY_URL_PROD } else { "https://rmsgateway.atparui.com" }
        $SERVICE_URL_PROD = if ($env:SERVICE_URL_PROD) { $env:SERVICE_URL_PROD } else { "https://rmsservice.atparui.com" }
        $DASHBOARD_URL_PROD = if ($env:DASHBOARD_URL_PROD) { $env:DASHBOARD_URL_PROD } else { "https://rmsdashboard.atparui.com" }
    }
    "dev" {
        $GATEWAY_URL = if ($env:GATEWAY_URL) { $env:GATEWAY_URL } else { "https://gateway-dev.example.com" }
        $SERVICE_URL = if ($env:SERVICE_URL) { $env:SERVICE_URL } else { "https://service-dev.example.com" }
        $FRONTEND_URL = if ($env:FRONTEND_URL) { $env:FRONTEND_URL } else { "https://app-dev.example.com" }
        $KEYCLOAK_URL = if ($env:KEYCLOAK_URL) { $env:KEYCLOAK_URL } else { "https://auth-dev.example.com" }
        $GATEWAY_URL_PROD = if ($env:GATEWAY_URL_PROD) { $env:GATEWAY_URL_PROD } else { "https://rmsgateway.atparui.com" }
        $SERVICE_URL_PROD = if ($env:SERVICE_URL_PROD) { $env:SERVICE_URL_PROD } else { "https://rmsservice.atparui.com" }
        $DASHBOARD_URL_PROD = if ($env:DASHBOARD_URL_PROD) { $env:DASHBOARD_URL_PROD } else { "https://rmsdashboard.atparui.com" }
    }
    "staging" {
        $GATEWAY_URL = if ($env:GATEWAY_URL) { $env:GATEWAY_URL } else { "https://gateway-staging.example.com" }
        $SERVICE_URL = if ($env:SERVICE_URL) { $env:SERVICE_URL } else { "https://service-staging.example.com" }
        $FRONTEND_URL = if ($env:FRONTEND_URL) { $env:FRONTEND_URL } else { "https://app-staging.example.com" }
        $KEYCLOAK_URL = if ($env:KEYCLOAK_URL) { $env:KEYCLOAK_URL } else { "https://auth-staging.example.com" }
        $GATEWAY_URL_PROD = if ($env:GATEWAY_URL_PROD) { $env:GATEWAY_URL_PROD } else { "https://rmsgateway.atparui.com" }
        $SERVICE_URL_PROD = if ($env:SERVICE_URL_PROD) { $env:SERVICE_URL_PROD } else { "https://rmsservice.atparui.com" }
        $DASHBOARD_URL_PROD = if ($env:DASHBOARD_URL_PROD) { $env:DASHBOARD_URL_PROD } else { "https://rmsdashboard.atparui.com" }
    }
    "prod" {
        $GATEWAY_URL = if ($env:GATEWAY_URL) { $env:GATEWAY_URL } else { "https://rmsgateway.atparui.com" }
        $SERVICE_URL = if ($env:SERVICE_URL) { $env:SERVICE_URL } else { "https://rmsservice.atparui.com" }
        $FRONTEND_URL = if ($env:FRONTEND_URL) { $env:FRONTEND_URL } else { "https://rmsdashboard.atparui.com" }
        $KEYCLOAK_URL = if ($env:KEYCLOAK_URL) { $env:KEYCLOAK_URL } else { "https://rmsauth.atparui.com" }
        $GATEWAY_URL_PROD = if ($env:GATEWAY_URL_PROD) { $env:GATEWAY_URL_PROD } else { "https://rmsgateway.atparui.com" }
        $SERVICE_URL_PROD = if ($env:SERVICE_URL_PROD) { $env:SERVICE_URL_PROD } else { "https://rmsservice.atparui.com" }
        $DASHBOARD_URL_PROD = if ($env:DASHBOARD_URL_PROD) { $env:DASHBOARD_URL_PROD } else { "https://rmsdashboard.atparui.com" }
    }
    default {
        Write-Host "Unknown environment: $Env" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Generating realm configs for environment: $Env" -ForegroundColor Cyan
Write-Host "Gateway URL: $GATEWAY_URL"
Write-Host "Service URL: $SERVICE_URL"
Write-Host "Frontend URL: $FRONTEND_URL"
Write-Host "Keycloak URL: $KEYCLOAK_URL"
Write-Host "Production Gateway URL: $GATEWAY_URL_PROD"
Write-Host "Production Service URL: $SERVICE_URL_PROD"
Write-Host "Production Dashboard URL: $DASHBOARD_URL_PROD"

# Create realm-import directory if it doesn't exist
if (-not (Test-Path "realm-import")) {
    New-Item -ItemType Directory -Path "realm-import" | Out-Null
}

# Read template and replace variables
function Replace-Template {
    param($TemplatePath, $OutputPath)
    $content = Get-Content $TemplatePath -Raw
    $content = $content -replace '\$\{GATEWAY_URL\}', $GATEWAY_URL
    $content = $content -replace '\$\{SERVICE_URL\}', $SERVICE_URL
    $content = $content -replace '\$\{FRONTEND_URL\}', $FRONTEND_URL
    $content = $content -replace '\$\{KEYCLOAK_URL\}', $KEYCLOAK_URL
    $content = $content -replace '\$\{GATEWAY_URL_PROD\}', $GATEWAY_URL_PROD
    $content = $content -replace '\$\{SERVICE_URL_PROD\}', $SERVICE_URL_PROD
    $content = $content -replace '\$\{DASHBOARD_URL_PROD\}', $DASHBOARD_URL_PROD
    Set-Content -Path $OutputPath -Value $content
}

# Generate realm files
if (Test-Path "realm-import-templates\gateway-realm.json.template") {
    Replace-Template "realm-import-templates\gateway-realm.json.template" "realm-import\gateway-realm.json"
}
if (Test-Path "realm-import-templates\rms-service-realm.json.template") {
    Replace-Template "realm-import-templates\rms-service-realm.json.template" "realm-import\rms-service-realm.json"
}

Write-Host "Realm configs generated successfully!" -ForegroundColor Green

