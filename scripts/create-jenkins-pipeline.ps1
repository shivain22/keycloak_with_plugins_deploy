# PowerShell script to create a Jenkins pipeline programmatically
# Usage: .\create-jenkins-pipeline.ps1 -JenkinsUrl "http://jenkins.example.com:8080" -Username "admin" -Password "password" -JobName "Keycloak-Deployment" -GitRepoUrl "https://github.com/user/repo.git"

param(
    [Parameter(Mandatory=$true)]
    [string]$JenkinsUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$true)]
    [string]$JobName,
    
    [Parameter(Mandatory=$false)]
    [string]$GitRepoUrl = "",
    
    [Parameter(Mandatory=$false)]
    [string]$GitBranch = "*/master",
    
    [Parameter(Mandatory=$false)]
    [string]$JenkinsfilePath = "Jenkinsfile",
    
    [Parameter(Mandatory=$false)]
    [string]$CredentialsId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigXmlPath = "jenkins-job-config.xml"
)

# Remove trailing slash from Jenkins URL
$JenkinsUrl = $JenkinsUrl.TrimEnd('/')

# Create base64 encoded credentials
$pair = "${Username}:${Password}"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
    Authorization = "Basic $encodedCreds"
    "Content-Type" = "application/xml"
}

Write-Host "Connecting to Jenkins at: $JenkinsUrl" -ForegroundColor Cyan

# Test Jenkins connection
try {
    $response = Invoke-WebRequest -Uri "$JenkinsUrl/api/json" -Headers $headers -Method Get -UseBasicParsing
    Write-Host "✓ Successfully connected to Jenkins" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to connect to Jenkins: $_" -ForegroundColor Red
    exit 1
}

# Check if job already exists
try {
    $jobCheck = Invoke-WebRequest -Uri "$JenkinsUrl/job/$JobName/api/json" -Headers $headers -Method Get -UseBasicParsing -ErrorAction SilentlyContinue
    if ($jobCheck.StatusCode -eq 200) {
        Write-Host "⚠ Job '$JobName' already exists. Do you want to update it? (Y/N)" -ForegroundColor Yellow
        $response = Read-Host
        if ($response -ne "Y" -and $response -ne "y") {
            Write-Host "Aborted." -ForegroundColor Yellow
            exit 0
        }
        Write-Host "Updating existing job..." -ForegroundColor Cyan
    }
} catch {
    # Job doesn't exist, which is fine
    Write-Host "Job '$JobName' does not exist. Creating new job..." -ForegroundColor Cyan
}

# Read and prepare XML configuration
$xmlContent = ""
if (Test-Path $ConfigXmlPath) {
    Write-Host "Reading configuration from: $ConfigXmlPath" -ForegroundColor Cyan
    $xmlContent = Get-Content -Path $ConfigXmlPath -Raw
    
    # Replace placeholders if GitRepoUrl is provided
    if ($GitRepoUrl -ne "") {
        $xmlContent = $xmlContent -replace "REPLACE_WITH_YOUR_GITHUB_REPO_URL", $GitRepoUrl
    }
    
    if ($CredentialsId -ne "") {
        $xmlContent = $xmlContent -replace "REPLACE_WITH_YOUR_GITHUB_CREDENTIALS_ID", $CredentialsId
    }
    
    # Update branch if different
    if ($GitBranch -ne "*/master") {
        $xmlContent = $xmlContent -replace '\*/master', $GitBranch
    }
    
    # Update Jenkinsfile path if different
    if ($JenkinsfilePath -ne "Jenkinsfile") {
        $xmlContent = $xmlContent -replace '<scriptPath>Jenkinsfile</scriptPath>', "<scriptPath>$JenkinsfilePath</scriptPath>"
    }
} else {
    Write-Host "⚠ Config XML file not found. Creating minimal pipeline configuration..." -ForegroundColor Yellow
    
    # Create minimal pipeline XML
    $xmlContent = @"
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.45">
  <description>Automated deployment pipeline for Keycloak with custom providers.</description>
  <keepDependencies>false</keepDependencies>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.94">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.11.3">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>$GitRepoUrl</url>
          $(if ($CredentialsId -ne "") { "<credentialsId>$CredentialsId</credentialsId>" } else { "" })
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>$GitBranch</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
    </scm>
    <scriptPath>$JenkinsfilePath</scriptPath>
    <lightweight>false</lightweight>
  </definition>
  <disabled>false</disabled>
</flow-definition>
"@
}

# Create or update the job
try {
    $uri = "$JenkinsUrl/createItem?name=$JobName"
    if (Test-Path "$JenkinsUrl/job/$JobName") {
        $uri = "$JenkinsUrl/job/$JobName/config.xml"
    }
    
    Write-Host "Creating/updating pipeline job: $JobName" -ForegroundColor Cyan
    
    if (Test-Path "$JenkinsUrl/job/$JobName") {
        # Update existing job
        $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $xmlContent -UseBasicParsing
    } else {
        # Create new job
        $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $xmlContent -UseBasicParsing
    }
    
    Write-Host "✓ Pipeline job '$JobName' created/updated successfully!" -ForegroundColor Green
    Write-Host "Job URL: $JenkinsUrl/job/$JobName" -ForegroundColor Cyan
    
    # Trigger a build (optional)
    Write-Host "`nDo you want to trigger a build now? (Y/N)" -ForegroundColor Yellow
    $triggerBuild = Read-Host
    if ($triggerBuild -eq "Y" -or $triggerBuild -eq "y") {
        Write-Host "Triggering build..." -ForegroundColor Cyan
        try {
            $buildResponse = Invoke-WebRequest -Uri "$JenkinsUrl/job/$JobName/build" -Headers $headers -Method Post -UseBasicParsing
            Write-Host "✓ Build triggered successfully!" -ForegroundColor Green
            Write-Host "View build at: $JenkinsUrl/job/$JobName" -ForegroundColor Cyan
        } catch {
            Write-Host "⚠ Build trigger failed: $_" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "✗ Failed to create/update pipeline: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`n✓ Done!" -ForegroundColor Green

