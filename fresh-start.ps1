# Fresh start script - deletes all volumes and starts from scratch
# - Stops any existing containers
# - Removes all volumes (postgres_data, m2_cache)
# - Builds & runs the "artifacts" one-shot container (produces ./providers/*.jar)
# - Starts Postgres + Keycloak
#
# Usage:
#   .\fresh-start.ps1
#
# Optional:
#   .\fresh-start.ps1 -logs      # tail keycloak logs after start
#   .\fresh-start.ps1 -rebuild   # force rebuild of the artifacts image

param(
    [switch]$rebuild,
    [switch]$logs
)

$ErrorActionPreference = "Stop"

# Get the script directory
$REPO_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $REPO_ROOT

# Check if docker is available
try {
    docker --version | Out-Null
} catch {
    Write-Host "ERROR: docker not found on PATH" -ForegroundColor Red
    exit 1
}

Write-Host "==> Stopping existing containers (if any) ..." -ForegroundColor Cyan
& docker compose down 2>&1 | Out-Null
# Ignore errors if no containers are running

Write-Host "==> Removing all volumes (postgres_data, m2_cache) ..." -ForegroundColor Cyan
# Remove volumes using docker compose (most reliable way)
& docker compose down -v 2>&1 | Out-Null

# Also try removing volumes directly by name (in case compose down -v didn't catch them)
$volumes = @("keycloak_with_plugins_deploy_postgres_data", "postgres_data", 
             "keycloak_with_plugins_deploy_m2_cache", "m2_cache")
foreach ($vol in $volumes) {
    try {
        & docker volume rm $vol 2>&1 | Out-Null
        Write-Host "  Removed volume: $vol" -ForegroundColor Yellow
    } catch {
        # Volume doesn't exist or already removed, ignore
    }
}

Write-Host "==> Building artifacts (providers) ..." -ForegroundColor Cyan
# Build the image first if --rebuild was requested
if ($rebuild) {
    Write-Host "  (rebuilding artifacts image...)" -ForegroundColor Yellow
    & docker compose build artifacts
    if ($LASTEXITCODE -ne 0 -or -not $?) {
        Write-Host "ERROR: Artifacts image build failed!" -ForegroundColor Red
        exit 1
    }
}

# Use 'docker compose run' for one-shot containers (properly handles exit codes)
& docker compose run --rm artifacts
if ($LASTEXITCODE -ne 0 -or -not $?) {
    Write-Host "ERROR: Artifacts build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "==> Starting Postgres + Keycloak ..." -ForegroundColor Cyan
if ($rebuild) {
    & docker compose up --build -d
} else {
    & docker compose up -d
}
if ($LASTEXITCODE -ne 0 -or -not $?) {
    Write-Host "ERROR: Failed to start containers!" -ForegroundColor Red
    exit 1
}

Write-Host "==> Done." -ForegroundColor Green

# Read KEYCLOAK_HTTP_PORT from .env file
$KEYCLOAK_PORT = "8080"
if (Test-Path ".env") {
    $envContent = Get-Content ".env" | Where-Object { $_ -match "^KEYCLOAK_HTTP_PORT=" }
    if ($envContent) {
        $portMatch = $envContent -match "KEYCLOAK_HTTP_PORT=(.+)"
        if ($portMatch) {
            $KEYCLOAK_PORT = ($envContent -split "=")[1].Trim(' "')
        }
    }
}
Write-Host "Keycloak should be available at: http://localhost:$KEYCLOAK_PORT" -ForegroundColor Green

if ($logs) {
    Write-Host "==> Tailing Keycloak logs (Ctrl+C to stop) ..." -ForegroundColor Cyan
    & docker compose logs -f --tail 200 keycloak
}

