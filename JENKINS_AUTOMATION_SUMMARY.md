# Jenkins Automation Setup Summary

## What Was Configured

Your Jenkins pipeline has been configured to:

1. **Watch your GitHub repository**: `https://github.com/shivain22/keycloak_with_plugins_deploy.git`
2. **Trigger automatically** on push/merge to `main` or `master` branch
3. **Run `start.sh`** to deploy Keycloak when triggered

## Changes Made

### 1. Updated `Jenkinsfile`
- Simplified pipeline to use `start.sh` instead of individual docker compose commands
- Maintains health checks and validation
- Triggers on GitHub webhook events

### 2. Updated `jenkins-job-config.xml`
- Set repository URL to: `https://github.com/shivain22/keycloak_with_plugins_deploy.git`
- Configured to watch both `main` and `master` branches
- Ready for GitHub webhook triggers

### 3. Created Automation Scripts
- `scripts/create-jenkins-pipeline.py` - Python script (cross-platform)
- `scripts/create-jenkins-pipeline.ps1` - PowerShell script (Windows)
- `scripts/create-jenkins-pipeline.sh` - Bash script (Linux/macOS)
- `scripts/setup-jenkins-pipeline.sh` - Interactive setup script

All scripts now default to your repository URL.

## Quick Start

### Option 1: Use the Python Script (Recommended)

```bash
# Install dependency
pip install requests

# Create the pipeline
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "http://your-jenkins-server:8080" \
    --username "your-username" \
    --password "your-api-token" \
    --job-name "Keycloak-Deployment"
```

### Option 2: Use the Interactive Setup Script (Linux/macOS)

```bash
chmod +x scripts/setup-jenkins-pipeline.sh
./scripts/setup-jenkins-pipeline.sh
```

### Option 3: Use PowerShell (Windows)

```powershell
.\scripts\create-jenkins-pipeline.ps1 `
    -JenkinsUrl "http://your-jenkins-server:8080" `
    -Username "your-username" `
    -Password "your-api-token" `
    -JobName "Keycloak-Deployment"
```

## Next Steps

### 1. Create the Jenkins Pipeline

Run one of the scripts above to create the pipeline in Jenkins.

### 2. Configure GitHub Webhook

Follow the guide in [GITHUB_WEBHOOK_SETUP.md](GITHUB_WEBHOOK_SETUP.md) to:
- Set up GitHub webhook to trigger Jenkins
- Test the webhook connection
- Verify automatic builds

### 3. Test the Pipeline

1. Make a small change to your repository
2. Commit and push to `main` or `master`:
   ```bash
   git add .
   git commit -m "Test Jenkins automation"
   git push origin main
   ```
3. Check Jenkins - a build should start automatically
4. The build will run `start.sh` to deploy Keycloak

## How It Works

1. **GitHub Push/Merge** → Triggers webhook
2. **Jenkins Receives Webhook** → Starts build
3. **Pipeline Stages**:
   - Checkout code from GitHub
   - Validate environment (Docker, .env file)
   - Run `start.sh` (stops old containers, builds artifacts, starts services)
   - Health check (verifies Keycloak is ready)
4. **Deployment Complete** → Keycloak is running

## Pipeline Flow

```
GitHub Push/Merge
    ↓
GitHub Webhook → Jenkins
    ↓
Checkout Code
    ↓
Validate Environment
    ↓
Run start.sh
    ├─ Stop existing containers
    ├─ Build artifacts (providers)
    └─ Start Postgres + Keycloak
    ↓
Health Check
    ↓
Deployment Complete ✓
```

## Troubleshooting

### Pipeline not triggering
- Check GitHub webhook configuration (see [GITHUB_WEBHOOK_SETUP.md](GITHUB_WEBHOOK_SETUP.md))
- Verify "GitHub hook trigger" is enabled in Jenkins job
- Check Jenkins logs for webhook errors

### Build fails at start.sh
- Ensure Docker is available to Jenkins user
- Check if `.env` file exists or is properly configured
- Verify `start.sh` is executable (pipeline sets this automatically)
- Check build console output for specific errors

### Health check fails
- Keycloak may need more time to start
- Check container logs: `docker compose logs keycloak`
- Verify port is not already in use
- Check `.env` file for correct port configuration

## Files Reference

- **Jenkinsfile** - Pipeline definition (uses `start.sh`)
- **jenkins-job-config.xml** - Jenkins job configuration
- **scripts/** - Automation scripts for creating pipelines
- **GITHUB_WEBHOOK_SETUP.md** - Webhook configuration guide
- **JENKINS_SETUP.md** - Detailed Jenkins setup guide

## Security Notes

1. **Use API Tokens**: Always use Jenkins API tokens instead of passwords
2. **Secure Webhooks**: Configure webhook secrets if possible
3. **Private Repos**: If repository is private, create Jenkins credentials for Git access
4. **Environment Variables**: Store sensitive values in Jenkins credentials, not in code

## Support

For issues or questions:
1. Check build console output in Jenkins
2. Review [GITHUB_WEBHOOK_SETUP.md](GITHUB_WEBHOOK_SETUP.md) for webhook issues
3. Check [JENKINS_SETUP.md](JENKINS_SETUP.md) for detailed setup instructions
4. Review Docker logs: `docker compose logs`



