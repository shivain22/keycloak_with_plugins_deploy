# PowerShell script to organize all .md files into docs/ folders
# Excludes: README.md in root, node_modules, .git directories

param(
    [string]$WorkspaceRoot = "c:\Users\shiva\cursor_workspace",
    [string]$EclipseWorkspaceRoot = "c:\Users\shiva\eclipse-workspace"
)

$ErrorActionPreference = "Continue"

function Move-MdFilesToDocs {
    param(
        [string]$ProjectPath
    )
    
    $projectName = Split-Path -Leaf $ProjectPath
    Write-Host "`n=== Processing: $projectName ===" -ForegroundColor Cyan
    
    # Create docs folder if it doesn't exist
    $docsPath = Join-Path $ProjectPath "docs"
    if (-not (Test-Path $docsPath)) {
        New-Item -ItemType Directory -Path $docsPath -Force | Out-Null
        Write-Host "Created docs/ folder" -ForegroundColor Green
    }
    
    # Find all .md files excluding:
    # - README.md in root
    # - Files in node_modules
    # - Files in .git
    # - Files already in docs/
    $mdFiles = Get-ChildItem -Path $ProjectPath -File -Filter "*.md" -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $fullPath = $_.FullName
        $relativePath = $fullPath.Replace($ProjectPath, "").TrimStart('\')
        
        # Skip if already in docs/
        if ($relativePath.StartsWith("docs")) { return $false }
        
        # Skip node_modules
        if ($relativePath -match "node_modules") { return $false }
        
        # Skip .git
        if ($relativePath -match "\.git") { return $false }
        
        # Skip README.md in root
        if ($_.Name -eq "README.md" -and $_.DirectoryName -eq $ProjectPath) { return $false }
        
        return $true
    }
    
    if ($mdFiles.Count -eq 0) {
        Write-Host "  No .md files to move" -ForegroundColor Yellow
        return
    }
    
    Write-Host "  Found $($mdFiles.Count) .md files to move" -ForegroundColor Yellow
    
    foreach ($file in $mdFiles) {
        $relativePath = $file.FullName.Replace($ProjectPath, "").TrimStart('\')
        $targetPath = Join-Path $docsPath (Split-Path -Leaf $file.Name)
        
        # Handle duplicates by adding directory name prefix
        if (Test-Path $targetPath) {
            $dirName = Split-Path -Parent $relativePath
            if ($dirName -and $dirName -ne ".") {
                $dirPrefix = ($dirName -replace '[\\\/]', '_') + "_"
                $targetPath = Join-Path $docsPath ($dirPrefix + $file.Name)
            } else {
                $targetPath = Join-Path $docsPath ("root_" + $file.Name)
            }
        }
        
        try {
            Move-Item -Path $file.FullName -Destination $targetPath -Force
            Write-Host "  Moved: $relativePath -> docs/$(Split-Path -Leaf $targetPath)" -ForegroundColor Green
        } catch {
            Write-Host "  ERROR moving $relativePath : $_" -ForegroundColor Red
        }
    }
}

# Process cursor_workspace projects
Write-Host "Processing cursor_workspace projects..." -ForegroundColor Cyan
$cursorProjects = Get-ChildItem -Path $WorkspaceRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -notmatch '^\.' -and $_.Name -ne "node_modules"
}

foreach ($project in $cursorProjects) {
    Move-MdFilesToDocs -ProjectPath $project.FullName
}

# Process eclipse-workspace projects
Write-Host "`nProcessing eclipse-workspace projects..." -ForegroundColor Cyan
$eclipseProjects = Get-ChildItem -Path $EclipseWorkspaceRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -notmatch '^\.' -and $_.Name -ne "node_modules" -and $_.Name -ne ".metadata"
}

foreach ($project in $eclipseProjects) {
    Move-MdFilesToDocs -ProjectPath $project.FullName
}

Write-Host "`n=== Organization Complete ===" -ForegroundColor Green
