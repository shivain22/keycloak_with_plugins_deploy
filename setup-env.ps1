# Quick script to set up .env file from env.example

if (Test-Path ".env") {
    $response = Read-Host "WARNING: .env file already exists! Do you want to overwrite it? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Aborted. .env file not changed." -ForegroundColor Yellow
        exit 0
    }
}

Copy-Item env.example .env
Write-Host "✅ Created .env file from env.example" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Review and update .env file with your specific values"
Write-Host "   2. Update MSG91_AUTH_KEY and MSG91_TEMPLATE_ID if using MSG91"
Write-Host "   3. Update DOCKER_PASSWORD with your Docker Hub password"
Write-Host "   4. For production, set ENVIRONMENT=prod and update URLs"
Write-Host ""
Write-Host "Then run: .\fresh-start.ps1"

