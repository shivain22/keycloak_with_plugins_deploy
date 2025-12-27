# Quick Start: Creating Jenkins Pipeline Programmatically

## Overview

You can create Jenkins pipelines programmatically using any of the three scripts provided. All scripts use the Jenkins REST API to create pipeline jobs.

## Quick Start (Python - Recommended)

### 1. Install Python dependencies

```bash
pip install requests
```

### 2. Run the script

```bash
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "http://your-jenkins-server:8080" \
    --username "your-username" \
    --password "your-password-or-api-token" \
    --job-name "Keycloak-Deployment" \
    --git-repo-url "https://github.com/your-username/your-repo.git"
```

## Quick Start (PowerShell - Windows)

```powershell
.\scripts\create-jenkins-pipeline.ps1 `
    -JenkinsUrl "http://your-jenkins-server:8080" `
    -Username "your-username" `
    -Password "your-password-or-api-token" `
    -JobName "Keycloak-Deployment" `
    -GitRepoUrl "https://github.com/your-username/your-repo.git"
```

## Quick Start (Bash - Linux/macOS)

```bash
chmod +x scripts/create-jenkins-pipeline.sh

./scripts/create-jenkins-pipeline.sh \
    --jenkins-url "http://your-jenkins-server:8080" \
    --username "your-username" \
    --password "your-password-or-api-token" \
    --job-name "Keycloak-Deployment" \
    --git-repo-url "https://github.com/your-username/your-repo.git"
```

## What You Need

1. **Jenkins URL**: Your Jenkins server address (e.g., `http://jenkins.example.com:8080`)
2. **Username**: Your Jenkins username
3. **Password or API Token**: Your Jenkins password or API token (API token recommended)
4. **Job Name**: Name for your pipeline job (e.g., `Keycloak-Deployment`)
5. **Git Repository URL**: Your repository URL (if not using existing config XML)

## Getting Your Jenkins API Token

1. Log in to Jenkins
2. Click your username (top right) → **Configure**
3. Scroll to **API Token** section
4. Click **Add new Token** → **Generate**
5. Copy the token (you won't see it again!)

## Using Existing Config XML

If you have a `jenkins-job-config.xml` file, the script will use it automatically:

```bash
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "http://your-jenkins-server:8080" \
    --username "your-username" \
    --password "your-api-token" \
    --job-name "Keycloak-Deployment" \
    --config-xml-path "jenkins-job-config.xml"
```

The script will automatically replace placeholders like:
- `REPLACE_WITH_YOUR_GITHUB_REPO_URL`
- `REPLACE_WITH_YOUR_GITHUB_CREDENTIALS_ID`

## Private Repository? Add Credentials

If your repository is private, create credentials in Jenkins first:

1. Jenkins → **Manage Jenkins** → **Credentials**
2. Click **Add Credentials**
3. Choose **Username with password**
4. Enter your Git username and password
5. Set an **ID** (e.g., `github-credentials`)
6. Use this ID in the script:

```bash
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "http://your-jenkins-server:8080" \
    --username "your-username" \
    --password "your-api-token" \
    --job-name "Keycloak-Deployment" \
    --git-repo-url "https://github.com/your-username/your-repo.git" \
    --credentials-id "github-credentials"
```

## Common Options

- `--git-branch "*/main"` - Build from main branch instead of master
- `--jenkinsfile-path "path/to/Jenkinsfile"` - Custom Jenkinsfile path
- `--trigger-build` - Automatically trigger a build after creation

## Troubleshooting

### "Failed to connect to Jenkins"
- Check your Jenkins URL is correct
- Verify Jenkins is running and accessible
- Check if you need HTTPS instead of HTTP

### "Job creation failed"
- Verify you have permissions to create jobs
- Check Jenkins logs for detailed errors
- Ensure Pipeline and Git plugins are installed

### "Credentials not found"
- Verify the credentials ID exists in Jenkins
- Check credentials are in Global scope
- Ensure credentials type matches (Username/Password)

## Next Steps

After creating the pipeline:
1. Go to Jenkins dashboard
2. Find your new job
3. Click **Build Now** to test
4. View build logs to verify everything works

For more details, see [scripts/README.md](README.md)

