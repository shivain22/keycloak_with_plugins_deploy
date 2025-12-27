#!/bin/bash
# Bash script to create a Jenkins pipeline programmatically
# Usage: ./create-jenkins-pipeline.sh --jenkins-url "http://jenkins.example.com:8080" --username "admin" --password "password" --job-name "Keycloak-Deployment"

set -e

# Default values
GIT_BRANCH="*/master"
JENKINSFILE_PATH="Jenkinsfile"
CONFIG_XML_PATH="jenkins-job-config.xml"
TRIGGER_BUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --jenkins-url)
            JENKINS_URL="$2"
            shift 2
            ;;
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        --job-name)
            JOB_NAME="$2"
            shift 2
            ;;
        --git-repo-url)
            GIT_REPO_URL="$2"
            shift 2
            ;;
        --git-branch)
            GIT_BRANCH="$2"
            shift 2
            ;;
        --jenkinsfile-path)
            JENKINSFILE_PATH="$2"
            shift 2
            ;;
        --credentials-id)
            CREDENTIALS_ID="$2"
            shift 2
            ;;
        --config-xml-path)
            CONFIG_XML_PATH="$2"
            shift 2
            ;;
        --trigger-build)
            TRIGGER_BUILD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$JENKINS_URL" || -z "$USERNAME" || -z "$PASSWORD" || -z "$JOB_NAME" ]]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 --jenkins-url URL --username USER --password PASS --job-name JOB_NAME [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  --jenkins-url      Jenkins server URL"
    echo "  --username         Jenkins username"
    echo "  --password         Jenkins password or API token"
    echo "  --job-name         Name of the Jenkins job"
    echo ""
    echo "Optional:"
    echo "  --git-repo-url     Git repository URL"
    echo "  --git-branch       Git branch (default: */master)"
    echo "  --jenkinsfile-path Path to Jenkinsfile (default: Jenkinsfile)"
    echo "  --credentials-id   Jenkins credentials ID for Git"
    echo "  --config-xml-path  Path to config XML (default: jenkins-job-config.xml)"
    echo "  --trigger-build    Trigger build after creation"
    exit 1
fi

# Remove trailing slash from Jenkins URL
JENKINS_URL="${JENKINS_URL%/}"

# Create base64 encoded credentials
AUTH_HEADER=$(echo -n "${USERNAME}:${PASSWORD}" | base64)

echo "Connecting to Jenkins at: $JENKINS_URL"

# Test Jenkins connection
if ! curl -s -f -u "${USERNAME}:${PASSWORD}" "${JENKINS_URL}/api/json" > /dev/null; then
    echo "✗ Failed to connect to Jenkins"
    exit 1
fi

echo "✓ Successfully connected to Jenkins"

# Check if job already exists
if curl -s -f -u "${USERNAME}:${PASSWORD}" "${JENKINS_URL}/job/${JOB_NAME}/api/json" > /dev/null 2>&1; then
    echo "⚠ Job '$JOB_NAME' already exists."
    read -p "Do you want to update it? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    echo "Updating existing job..."
    JOB_EXISTS=true
else
    echo "Job '$JOB_NAME' does not exist. Creating new job..."
    JOB_EXISTS=false
fi

# Read and prepare XML configuration
XML_CONTENT=""
if [[ -f "$CONFIG_XML_PATH" ]]; then
    echo "Reading configuration from: $CONFIG_XML_PATH"
    XML_CONTENT=$(cat "$CONFIG_XML_PATH")
    
    # Replace placeholders
    if [[ -n "$GIT_REPO_URL" ]]; then
        XML_CONTENT=$(echo "$XML_CONTENT" | sed "s|REPLACE_WITH_YOUR_GITHUB_REPO_URL|$GIT_REPO_URL|g")
    fi
    
    if [[ -n "$CREDENTIALS_ID" ]]; then
        XML_CONTENT=$(echo "$XML_CONTENT" | sed "s|REPLACE_WITH_YOUR_GITHUB_CREDENTIALS_ID|$CREDENTIALS_ID|g")
    fi
    
    # Update branch if different
    if [[ "$GIT_BRANCH" != "*/master" ]]; then
        XML_CONTENT=$(echo "$XML_CONTENT" | sed "s|\*/master|$GIT_BRANCH|g")
    fi
    
    # Update Jenkinsfile path if different
    if [[ "$JENKINSFILE_PATH" != "Jenkinsfile" ]]; then
        XML_CONTENT=$(echo "$XML_CONTENT" | sed "s|<scriptPath>Jenkinsfile</scriptPath>|<scriptPath>$JENKINSFILE_PATH</scriptPath>|g")
    fi
else
    echo "⚠ Config XML file not found. Creating minimal pipeline configuration..."
    
    CREDENTIALS_TAG=""
    if [[ -n "$CREDENTIALS_ID" ]]; then
        CREDENTIALS_TAG="<credentialsId>$CREDENTIALS_ID</credentialsId>"
    fi
    
    XML_CONTENT="<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin=\"workflow-job@2.45\">
  <description>Automated deployment pipeline for Keycloak with custom providers.</description>
  <keepDependencies>false</keepDependencies>
  <definition class=\"org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition\" plugin=\"workflow-cps@2.94\">
    <scm class=\"hudson.plugins.git.GitSCM\" plugin=\"git@4.11.3\">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${GIT_REPO_URL:-REPLACE_WITH_YOUR_GITHUB_REPO_URL}</url>
          $CREDENTIALS_TAG
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>$GIT_BRANCH</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class=\"empty-list\"/>
    </scm>
    <scriptPath>$JENKINSFILE_PATH</scriptPath>
    <lightweight>false</lightweight>
  </definition>
  <disabled>false</disabled>
</flow-definition>"
fi

# Create or update the job
echo "Creating/updating pipeline job: $JOB_NAME"

if [[ "$JOB_EXISTS" == true ]]; then
    # Update existing job
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Content-Type: application/xml" \
        --data-binary "$XML_CONTENT" \
        "${JENKINS_URL}/job/${JOB_NAME}/config.xml")
else
    # Create new job
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Content-Type: application/xml" \
        --data-binary "$XML_CONTENT" \
        "${JENKINS_URL}/createItem?name=${JOB_NAME}")
fi

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo "✓ Pipeline job '$JOB_NAME' created/updated successfully!"
    echo "Job URL: ${JENKINS_URL}/job/${JOB_NAME}"
    
    # Trigger a build
    if [[ "$TRIGGER_BUILD" == true ]]; then
        echo "Triggering build..."
        if curl -s -f -X POST -u "${USERNAME}:${PASSWORD}" "${JENKINS_URL}/job/${JOB_NAME}/build" > /dev/null; then
            echo "✓ Build triggered successfully!"
            echo "View build at: ${JENKINS_URL}/job/${JOB_NAME}"
        else
            echo "⚠ Build trigger failed"
        fi
    else
        read -p "Do you want to trigger a build now? (y/N): " trigger_response
        if [[ "$trigger_response" =~ ^[Yy]$ ]]; then
            echo "Triggering build..."
            if curl -s -f -X POST -u "${USERNAME}:${PASSWORD}" "${JENKINS_URL}/job/${JOB_NAME}/build" > /dev/null; then
                echo "✓ Build triggered successfully!"
                echo "View build at: ${JENKINS_URL}/job/${JOB_NAME}"
            else
                echo "⚠ Build trigger failed"
            fi
        fi
    fi
else
    echo "✗ Failed to create/update pipeline (HTTP $HTTP_CODE)"
    echo "$BODY"
    exit 1
fi

echo ""
echo "✓ Done!"

