#!/usr/bin/env python3
"""
Python script to create a Jenkins pipeline programmatically
Usage: python create-jenkins-pipeline.py --jenkins-url "http://jenkins.example.com:8080" --username "admin" --password "password" --job-name "Keycloak-Deployment"
"""

import argparse
import requests
import sys
from requests.auth import HTTPBasicAuth
from pathlib import Path


def test_jenkins_connection(jenkins_url, username, password):
    """Test connection to Jenkins"""
    try:
        response = requests.get(
            f"{jenkins_url}/api/json",
            auth=HTTPBasicAuth(username, password),
            timeout=10
        )
        response.raise_for_status()
        print("✓ Successfully connected to Jenkins")
        return True
    except requests.exceptions.RequestException as e:
        print(f"✗ Failed to connect to Jenkins: {e}")
        return False


def check_job_exists(jenkins_url, job_name, username, password):
    """Check if a job already exists"""
    try:
        response = requests.get(
            f"{jenkins_url}/job/{job_name}/api/json",
            auth=HTTPBasicAuth(username, password),
            timeout=10
        )
        return response.status_code == 200
    except requests.exceptions.RequestException:
        return False


def read_config_xml(config_path, git_repo_url, credentials_id, git_branch, jenkinsfile_path):
    """Read and prepare XML configuration"""
    if Path(config_path).exists():
        print(f"Reading configuration from: {config_path}")
        with open(config_path, 'r', encoding='utf-8') as f:
            xml_content = f.read()
        
        # Replace placeholders
        if git_repo_url:
            xml_content = xml_content.replace("REPLACE_WITH_YOUR_GITHUB_REPO_URL", git_repo_url)
        
        if credentials_id:
            xml_content = xml_content.replace("REPLACE_WITH_YOUR_GITHUB_CREDENTIALS_ID", credentials_id)
        
        # Update branch if different
        if git_branch != "*/master":
            xml_content = xml_content.replace("*/master", git_branch)
        
        # Update Jenkinsfile path if different
        if jenkinsfile_path != "Jenkinsfile":
            xml_content = xml_content.replace(
                "<scriptPath>Jenkinsfile</scriptPath>",
                f"<scriptPath>{jenkinsfile_path}</scriptPath>"
            )
        
        return xml_content
    else:
        print("⚠ Config XML file not found. Creating minimal pipeline configuration...")
        
        # Create minimal pipeline XML
        credentials_tag = f"<credentialsId>{credentials_id}</credentialsId>" if credentials_id else ""
        
        xml_content = f"""<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.45">
  <description>Automated deployment pipeline for Keycloak with custom providers.</description>
  <keepDependencies>false</keepDependencies>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.94">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.11.3">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>{git_repo_url or 'REPLACE_WITH_YOUR_GITHUB_REPO_URL'}</url>
          {credentials_tag}
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>{git_branch}</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
    </scm>
    <scriptPath>{jenkinsfile_path}</scriptPath>
    <lightweight>false</lightweight>
  </definition>
  <disabled>false</disabled>
</flow-definition>
"""
        return xml_content


def create_or_update_job(jenkins_url, job_name, xml_content, username, password):
    """Create or update a Jenkins job"""
    auth = HTTPBasicAuth(username, password)
    
    # Check if job exists
    job_exists = check_job_exists(jenkins_url, job_name, username, password)
    
    if job_exists:
        print(f"⚠ Job '{job_name}' already exists. Updating...")
        url = f"{jenkins_url}/job/{job_name}/config.xml"
        method = "POST"
    else:
        print(f"Creating new job: {job_name}")
        url = f"{jenkins_url}/createItem?name={job_name}"
        method = "POST"
    
    try:
        response = requests.request(
            method=method,
            url=url,
            auth=auth,
            data=xml_content.encode('utf-8'),
            headers={"Content-Type": "application/xml"},
            timeout=30
        )
        response.raise_for_status()
        print(f"✓ Pipeline job '{job_name}' created/updated successfully!")
        print(f"Job URL: {jenkins_url}/job/{job_name}")
        return True
    except requests.exceptions.RequestException as e:
        print(f"✗ Failed to create/update pipeline: {e}")
        if hasattr(e.response, 'text'):
            print(f"Response: {e.response.text}")
        return False


def trigger_build(jenkins_url, job_name, username, password):
    """Trigger a build for the job"""
    try:
        response = requests.post(
            f"{jenkins_url}/job/{job_name}/build",
            auth=HTTPBasicAuth(username, password),
            timeout=10
        )
        response.raise_for_status()
        print("✓ Build triggered successfully!")
        print(f"View build at: {jenkins_url}/job/{job_name}")
        return True
    except requests.exceptions.RequestException as e:
        print(f"⚠ Build trigger failed: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Create a Jenkins pipeline programmatically",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Create pipeline with all options
  python create-jenkins-pipeline.py \\
    --jenkins-url "http://jenkins.example.com:8080" \\
    --username "admin" \\
    --password "password" \\
    --job-name "Keycloak-Deployment" \\
    --git-repo-url "https://github.com/user/repo.git" \\
    --credentials-id "github-credentials"

  # Create pipeline using existing config XML
  python create-jenkins-pipeline.py \\
    --jenkins-url "http://jenkins.example.com:8080" \\
    --username "admin" \\
    --password "password" \\
    --job-name "Keycloak-Deployment" \\
    --config-xml-path "jenkins-job-config.xml"
        """
    )
    
    parser.add_argument("--jenkins-url", required=True, help="Jenkins server URL (e.g., http://jenkins.example.com:8080)")
    parser.add_argument("--username", required=True, help="Jenkins username")
    parser.add_argument("--password", required=True, help="Jenkins password or API token")
    parser.add_argument("--job-name", required=True, help="Name of the Jenkins job to create")
    parser.add_argument("--git-repo-url", default="", help="Git repository URL")
    parser.add_argument("--git-branch", default="*/master", help="Git branch to build (default: */master)")
    parser.add_argument("--jenkinsfile-path", default="Jenkinsfile", help="Path to Jenkinsfile in repo (default: Jenkinsfile)")
    parser.add_argument("--credentials-id", default="", help="Jenkins credentials ID for Git authentication")
    parser.add_argument("--config-xml-path", default="jenkins-job-config.xml", help="Path to Jenkins job config XML file")
    parser.add_argument("--trigger-build", action="store_true", help="Trigger a build after creating the job")
    
    args = parser.parse_args()
    
    # Remove trailing slash from Jenkins URL
    jenkins_url = args.jenkins_url.rstrip('/')
    
    print(f"Connecting to Jenkins at: {jenkins_url}")
    
    # Test connection
    if not test_jenkins_connection(jenkins_url, args.username, args.password):
        sys.exit(1)
    
    # Check if job exists and ask for confirmation
    if check_job_exists(jenkins_url, args.job_name, args.username, args.password):
        response = input(f"⚠ Job '{args.job_name}' already exists. Do you want to update it? (y/N): ")
        if response.lower() != 'y':
            print("Aborted.")
            sys.exit(0)
    
    # Read and prepare XML configuration
    xml_content = read_config_xml(
        args.config_xml_path,
        args.git_repo_url,
        args.credentials_id,
        args.git_branch,
        args.jenkinsfile_path
    )
    
    # Create or update the job
    if not create_or_update_job(jenkins_url, args.job_name, xml_content, args.username, args.password):
        sys.exit(1)
    
    # Trigger build if requested
    if args.trigger_build:
        trigger_build(jenkins_url, args.job_name, args.username, args.password)
    else:
        response = input("\nDo you want to trigger a build now? (y/N): ")
        if response.lower() == 'y':
            trigger_build(jenkins_url, args.job_name, args.username, args.password)
    
    print("\n✓ Done!")


if __name__ == "__main__":
    main()

