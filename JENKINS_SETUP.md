# Jenkins Pipeline Setup Guide

This guide will help you set up the Jenkins pipeline for automated deployment of your Keycloak setup.

## Prerequisites

1. **Jenkins installed** on your server
2. **Docker and Docker Compose** installed on the Jenkins server (or agent)
3. **GitHub repository** with your Keycloak deployment code
4. **Jenkins plugins** installed:
   - Pipeline
   - Git
   - GitHub plugin (for webhook triggers)
   - Docker Pipeline (optional, but recommended)

## Setup Options

### Option 1: Using Jenkinsfile (Recommended - Pipeline as Code)

This is the modern approach where the pipeline definition is stored in your repository.

#### Steps:

1. **Push the Jenkinsfile to your repository**
   - The `Jenkinsfile` is already in your repo root
   - Commit and push it to your master branch

2. **Create a new Pipeline job in Jenkins**
   - Go to Jenkins Dashboard → New Item
   - Enter a job name (e.g., "Keycloak-Deployment")
   - Select "Pipeline" and click OK

3. **Configure the Pipeline**
   - **Pipeline Definition**: Select "Pipeline script from SCM"
   - **SCM**: Select "Git"
   - **Repository URL**: Enter your GitHub repository URL
     - Example: `https://github.com/your-username/keycloak_with_plugins_deploy.git`
   - **Credentials**: Add your GitHub credentials if the repo is private
   - **Branches to build**: `*/master`
   - **Script Path**: `Jenkinsfile` (should be auto-detected)

4. **Configure GitHub Webhook (for automatic triggers)**
   - In your GitHub repository, go to Settings → Webhooks
   - Click "Add webhook"
   - **Payload URL**: `http://your-jenkins-server:port/github-webhook/`
     - If Jenkins is behind a reverse proxy, use the public URL
   - **Content type**: `application/json`
   - **Events**: Select "Just the push event" or "Let me select individual events" → check "Pushes"
   - **Active**: Checked
   - Click "Add webhook"

5. **Configure Build Triggers (Alternative if webhook doesn't work)**
   - In Jenkins job configuration, under "Build Triggers"
   - Check "GitHub hook trigger for GITScm polling"
   - Or use "Poll SCM" with schedule: `H/5 * * * *` (every 5 minutes)

6. **Save and test**
   - Click "Save"
   - Click "Build Now" to test the pipeline
   - Check the console output for any issues

### Option 2: Import Jenkins Job Configuration XML

If you prefer to import a pre-configured job:

1. **Edit the XML file**
   - Open `jenkins-job-config.xml`
   - Replace `REPLACE_WITH_YOUR_GITHUB_REPO_URL` with your actual repository URL
   - Replace `REPLACE_WITH_YOUR_GITHUB_CREDENTIALS_ID` with your Jenkins credentials ID
     - To find/create credentials: Jenkins → Manage Jenkins → Credentials → Add credentials
     - Use "Username with password" or "SSH Username with private key" for GitHub

2. **Import the job**
   - Go to Jenkins Dashboard → New Item
   - Enter a job name (e.g., "Keycloak-Deployment")
   - Select "Freestyle project" (we'll change it)
   - Click OK
   - Scroll down and click "Cancel" (we'll import instead)
   - Go to Jenkins Dashboard → Manage Jenkins → Import Job
   - Select the `jenkins-job-config.xml` file
   - Click "Import"

3. **Verify configuration**
   - Open the imported job
   - Check that the repository URL and credentials are correct
   - Update any settings as needed

## Environment Setup

### Required Environment Variables

Make sure your `.env` file is properly configured on the Jenkins server. You can:

1. **Create `.env` file in the workspace**
   - The pipeline will automatically create it from `env.example` if missing
   - But you should create it manually with proper values for production

2. **Use Jenkins Credentials for sensitive values**
   - Store sensitive values (like `MSG91_AUTH_KEY`, `KC_DB_PASSWORD`) in Jenkins Credentials
   - Update the Jenkinsfile to inject them as environment variables

### Example: Injecting Credentials in Jenkinsfile

Add this to the `environment` block in your Jenkinsfile:

```groovy
environment {
    // ... existing variables ...
    
    // Inject credentials
    MSG91_AUTH_KEY = credentials('msg91-auth-key')
    KC_DB_PASSWORD = credentials('keycloak-db-password')
    GITHUB_TOKEN = credentials('github-token')  // If needed for private repos
}
```

Then create these credentials in Jenkins:
- Jenkins → Manage Jenkins → Credentials → Add credentials
- Use "Secret text" for tokens/keys
- Use "Username with password" for username/password pairs

## Pipeline Stages

The pipeline includes the following stages:

1. **Checkout**: Clones the repository
2. **Validate Environment**: Checks for `.env` file and Docker installation
3. **Stop Existing Deployment**: Gracefully stops any running containers
4. **Build Artifacts**: Builds custom Keycloak providers
5. **Deploy Services**: Starts Postgres and Keycloak containers
6. **Health Check**: Verifies Keycloak is ready and healthy
7. **Verify Deployment**: Confirms all containers are running

## Troubleshooting

### Pipeline fails at "Build Artifacts" stage
- Check if Docker is available to Jenkins user
- Verify Jenkins user has permissions to run Docker commands
- Add Jenkins user to docker group: `sudo usermod -aG docker jenkins`
- Restart Jenkins after adding user to docker group

### GitHub webhook not triggering
- Verify webhook URL is accessible from GitHub
- Check Jenkins logs: `tail -f /var/log/jenkins/jenkins.log`
- Ensure GitHub plugin is installed
- Try using "Poll SCM" as a fallback

### Health check timeout
- Increase `HEALTH_CHECK_TIMEOUT` in Jenkinsfile
- Check Keycloak logs: `docker compose logs keycloak`
- Verify port is not already in use

### Permission denied errors
- Ensure Jenkins user has write permissions to workspace directory
- Check Docker socket permissions: `ls -l /var/run/docker.sock`
- May need to add Jenkins to docker group or adjust permissions

## Customization

### Change deployment port
- Update `KEYCLOAK_HTTP_PORT` in your `.env` file
- The pipeline will automatically read it

### Add notifications
Uncomment and configure the notification section in the `post { failure { } }` block:
- Email notifications
- Slack notifications
- Teams notifications

### Add rollback capability
You can extend the pipeline to:
- Tag successful deployments
- Keep previous deployment running
- Rollback to previous version on failure

## Security Best Practices

1. **Never commit `.env` file** with real credentials
2. **Use Jenkins Credentials** for sensitive values
3. **Restrict Jenkins access** to authorized users only
4. **Use HTTPS** for Jenkins and GitHub webhooks
5. **Regularly update** Jenkins and plugins
6. **Monitor** pipeline execution logs

## Support

If you encounter issues:
1. Check Jenkins console output for detailed error messages
2. Review Docker logs: `docker compose logs`
3. Verify all prerequisites are met
4. Check Jenkins system logs

