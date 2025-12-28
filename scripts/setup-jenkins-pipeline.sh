#!/bin/bash
# Quick setup script to create Jenkins pipeline for keycloak_with_plugins_deploy
# This script will create the pipeline with the correct repository URL

set -e

# Default values
JENKINS_URL="${JENKINS_URL:-}"
JENKINS_USERNAME="${JENKINS_USERNAME:-}"
JENKINS_PASSWORD="${JENKINS_PASSWORD:-}"
JOB_NAME="${JOB_NAME:-Keycloak-Deployment}"
GIT_REPO_URL="https://github.com/shivain22/keycloak_with_plugins_deploy.git"
GIT_BRANCH="*/main"
CREDENTIALS_ID="${CREDENTIALS_ID:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Jenkins Pipeline Setup for Keycloak"
echo "=========================================="
echo ""

# Get Jenkins URL
if [ -z "$JENKINS_URL" ]; then
    read -p "Enter Jenkins URL (e.g., http://jenkins.example.com:8080): " JENKINS_URL
fi

# Get Jenkins username
if [ -z "$JENKINS_USERNAME" ]; then
    read -p "Enter Jenkins username: " JENKINS_USERNAME
fi

# Get Jenkins password/API token
if [ -z "$JENKINS_PASSWORD" ]; then
    read -sp "Enter Jenkins password or API token: " JENKINS_PASSWORD
    echo ""
fi

# Ask about credentials (optional)
if [ -z "$CREDENTIALS_ID" ]; then
    read -p "Enter Jenkins credentials ID for Git (leave empty if repo is public): " CREDENTIALS_ID
fi

echo ""
echo "Creating pipeline with the following settings:"
echo "  Jenkins URL: $JENKINS_URL"
echo "  Job Name: $JOB_NAME"
echo "  Repository: $GIT_REPO_URL"
echo "  Branch: $GIT_BRANCH"
if [ -n "$CREDENTIALS_ID" ]; then
    echo "  Credentials ID: $CREDENTIALS_ID"
fi
echo ""

# Run the creation script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if [ -n "$CREDENTIALS_ID" ]; then
    bash scripts/create-jenkins-pipeline.sh \
        --jenkins-url "$JENKINS_URL" \
        --username "$JENKINS_USERNAME" \
        --password "$JENKINS_PASSWORD" \
        --job-name "$JOB_NAME" \
        --git-repo-url "$GIT_REPO_URL" \
        --git-branch "$GIT_BRANCH" \
        --credentials-id "$CREDENTIALS_ID" \
        --trigger-build
else
    bash scripts/create-jenkins-pipeline.sh \
        --jenkins-url "$JENKINS_URL" \
        --username "$JENKINS_USERNAME" \
        --password "$JENKINS_PASSWORD" \
        --job-name "$JOB_NAME" \
        --git-repo-url "$GIT_REPO_URL" \
        --git-branch "$GIT_BRANCH" \
        --trigger-build
fi

echo ""
echo -e "${GREEN}✓ Pipeline setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure GitHub webhook (see GITHUB_WEBHOOK_SETUP.md)"
echo "2. Test the pipeline by pushing to main/master branch"
echo "3. Monitor builds at: $JENKINS_URL/job/$JOB_NAME"



