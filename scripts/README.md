# Jenkins Pipeline Creation Scripts

This directory contains scripts to programmatically create Jenkins pipelines using the Jenkins REST API.

## Available Scripts

1. **`create-jenkins-pipeline.ps1`** - PowerShell script for Windows
2. **`create-jenkins-pipeline.py`** - Python script (cross-platform, recommended)
3. **`create-jenkins-pipeline.sh`** - Bash script for Linux/macOS

## Prerequisites

### For PowerShell Script
- Windows PowerShell 5.1 or PowerShell Core
- No additional dependencies required

### For Python Script
- Python 3.6 or higher
- `requests` library: `pip install requests`

### For Bash Script
- Bash 4.0 or higher
- `curl` command-line tool
- `base64` command (usually pre-installed)

## Usage

### PowerShell (Windows)

```powershell
.\scripts\create-jenkins-pipeline.ps1 `
    -JenkinsUrl "http://jenkins.example.com:8080" `
    -Username "admin" `
    -Password "your-password-or-api-token" `
    -JobName "Keycloak-Deployment" `
    -GitRepoUrl "https://github.com/your-username/your-repo.git" `
    -CredentialsId "github-credentials-id" `
    -GitBranch "*/master" `
    -JenkinsfilePath "Jenkinsfile"
```

### Python (Cross-platform)

```bash
# Install dependencies first
pip install requests

# Run the script
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "http://jenkins.example.com:8080" \
    --username "admin" \
    --password "your-password-or-api-token" \
    --job-name "Keycloak-Deployment" \
    --git-repo-url "https://github.com/your-username/your-repo.git" \
    --credentials-id "github-credentials-id" \
    --git-branch "*/master" \
    --jenkinsfile-path "Jenkinsfile" \
    --trigger-build
```

### Bash (Linux/macOS)

```bash
# Make script executable
chmod +x scripts/create-jenkins-pipeline.sh

# Run the script
./scripts/create-jenkins-pipeline.sh \
    --jenkins-url "http://jenkins.example.com:8080" \
    --username "admin" \
    --password "your-password-or-api-token" \
    --job-name "Keycloak-Deployment" \
    --git-repo-url "https://github.com/your-username/your-repo.git" \
    --credentials-id "github-credentials-id" \
    --git-branch "*/master" \
    --jenkinsfile-path "Jenkinsfile" \
    --trigger-build
```

## Parameters

### Required Parameters

- `--jenkins-url` / `-JenkinsUrl`: Jenkins server URL (e.g., `http://jenkins.example.com:8080`)
- `--username` / `-Username`: Jenkins username
- `--password` / `-Password`: Jenkins password or API token (recommended)
- `--job-name` / `-JobName`: Name of the Jenkins job to create

### Optional Parameters

- `--git-repo-url` / `-GitRepoUrl`: Git repository URL (required if not using config XML)
- `--git-branch` / `-GitBranch`: Git branch to build (default: `*/master`)
- `--jenkinsfile-path` / `-JenkinsfilePath`: Path to Jenkinsfile in repository (default: `Jenkinsfile`)
- `--credentials-id` / `-CredentialsId`: Jenkins credentials ID for Git authentication
- `--config-xml-path` / `-ConfigXmlPath`: Path to Jenkins job config XML file (default: `jenkins-job-config.xml`)
- `--trigger-build` / `-TriggerBuild`: Automatically trigger a build after creating the job

## Getting Jenkins API Token

For security, it's recommended to use an API token instead of your password:

1. Log in to Jenkins
2. Click on your username (top right)
3. Click "Configure"
4. Scroll to "API Token" section
5. Click "Add new Token" → "Generate"
6. Copy the token and use it as the password parameter

## Creating Jenkins Credentials for Git

If your repository requires authentication, you need to create credentials in Jenkins:

1. Go to Jenkins → Manage Jenkins → Credentials
2. Click "Add Credentials"
3. Choose:
   - **Kind**: "Username with password" or "SSH Username with private key"
   - **Username**: Your Git username
   - **Password/Private Key**: Your Git password or SSH key
   - **ID**: A unique ID (e.g., `github-credentials`)
4. Use this ID in the `--credentials-id` parameter

## Examples

### Example 1: Create pipeline with public repository

```bash
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "http://localhost:8080" \
    --username "admin" \
    --password "your-api-token" \
    --job-name "Keycloak-Deployment" \
    --git-repo-url "https://github.com/your-username/keycloak_with_plugins_deploy.git"
```

### Example 2: Create pipeline with private repository (using credentials)

```bash
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "http://localhost:8080" \
    --username "admin" \
    --password "your-api-token" \
    --job-name "Keycloak-Deployment" \
    --git-repo-url "https://github.com/your-username/keycloak_with_plugins_deploy.git" \
    --credentials-id "github-credentials"
```

### Example 3: Create pipeline using existing config XML

```bash
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "http://localhost:8080" \
    --username "admin" \
    --password "your-api-token" \
    --job-name "Keycloak-Deployment" \
    --config-xml-path "jenkins-job-config.xml"
```

### Example 4: Create pipeline and trigger build immediately

```bash
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "http://localhost:8080" \
    --username "admin" \
    --password "your-api-token" \
    --job-name "Keycloak-Deployment" \
    --git-repo-url "https://github.com/your-username/keycloak_with_plugins_deploy.git" \
    --trigger-build
```

## How It Works

The scripts use the Jenkins REST API to:

1. **Test Connection**: Verify connectivity to Jenkins
2. **Check Existing Job**: Determine if the job already exists
3. **Read Configuration**: Load XML configuration from file or generate minimal config
4. **Create/Update Job**: POST XML configuration to Jenkins API
5. **Trigger Build** (optional): Start a build immediately after creation

### API Endpoints Used

- `GET /api/json` - Test connection
- `GET /job/{job-name}/api/json` - Check if job exists
- `POST /createItem?name={job-name}` - Create new job
- `POST /job/{job-name}/config.xml` - Update existing job
- `POST /job/{job-name}/build` - Trigger build

## Troubleshooting

### Connection Failed

- Verify Jenkins URL is correct and accessible
- Check if Jenkins requires HTTPS
- Ensure username and password/API token are correct
- Check firewall/network settings

### Job Creation Failed

- Verify you have permissions to create jobs in Jenkins
- Check if the job name contains invalid characters
- Review Jenkins logs for detailed error messages
- Ensure all required plugins are installed (Pipeline, Git)

### Credentials Not Found

- Verify the credentials ID exists in Jenkins
- Check that credentials are in the correct scope (Global or System)
- Ensure credentials have the correct type (Username/Password or SSH)

### Build Trigger Failed

- Verify the job was created successfully
- Check Jenkins logs for build errors
- Ensure the repository is accessible
- Verify the Jenkinsfile exists in the specified path

## Security Best Practices

1. **Use API Tokens**: Always use API tokens instead of passwords
2. **Store Credentials Securely**: Use environment variables or secret management tools
3. **Limit Permissions**: Use Jenkins roles/authorization to limit what users can do
4. **Use HTTPS**: Always use HTTPS for Jenkins URLs in production
5. **Rotate Tokens**: Regularly rotate API tokens

## Environment Variables

You can use environment variables to avoid passing sensitive information:

```bash
# Set environment variables
export JENKINS_URL="http://jenkins.example.com:8080"
export JENKINS_USERNAME="admin"
export JENKINS_PASSWORD="your-api-token"

# Modify scripts to read from environment variables
# Or use them in your command:
python scripts/create-jenkins-pipeline.py \
    --jenkins-url "$JENKINS_URL" \
    --username "$JENKINS_USERNAME" \
    --password "$JENKINS_PASSWORD" \
    --job-name "Keycloak-Deployment" \
    --git-repo-url "https://github.com/your-username/your-repo.git"
```

## Additional Resources

- [Jenkins REST API Documentation](https://www.jenkins.io/doc/book/using/remote-access-api/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [Jenkins Credentials Documentation](https://www.jenkins.io/doc/book/using/using-credentials/)

