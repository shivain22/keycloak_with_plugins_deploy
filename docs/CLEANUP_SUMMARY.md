# Script Cleanup Summary

## Overview
Removed unused scripts and Windows PowerShell files since the project is now Linux-only.

## Removed Files

### Unused Shell Scripts (Not Used by start.sh)
1. **BUILD_THEME_ONLY.sh** - Removed
   - **Reason**: Functionality is already available in `start.sh` via `--theme-only` flag
   - **Alternative**: Use `./start.sh --theme-only` or `./start.sh --full-cycle-theme`

2. **build-with-java21.sh** - Removed
   - **Reason**: Not used by `start.sh`; standalone utility script
   - **Alternative**: Use `source set-java21.sh` before running Maven commands directly

### Windows PowerShell Files (Linux-Only Project)
All PowerShell (.ps1) files have been removed as the project is Linux-only:

1. **fix-post-logout-redirect.ps1** - Removed
   - **Alternative**: Use Keycloak Admin Console or Admin API directly

2. **fresh-start.ps1** - Removed
   - **Alternative**: Use `./fresh-start.sh` (bash equivalent exists)

3. **start.ps1** - Removed
   - **Alternative**: Use `./start.sh` (bash equivalent exists)

4. **update-realm-config.ps1** - Removed
   - **Alternative**: Use `./update-realm-config.sh` (bash equivalent exists)

5. **setup-env.ps1** - Removed
   - **Alternative**: Use `./setup-env.sh` (bash equivalent exists)

6. **scripts/generate-realm-configs.ps1** - Removed
   - **Alternative**: Use `./scripts/generate-realm-configs.sh` (bash equivalent exists)

7. **scripts/create-jenkins-pipeline.ps1** - Removed
   - **Alternative**: Use `./scripts/create-jenkins-pipeline.sh` or `./scripts/create-jenkins-pipeline.py` (bash/Python equivalents exist)

## Updated Documentation

The following documentation files were updated to remove references to deleted scripts:

1. **docs/deployment/JAVA21_SETUP.md**
   - Removed reference to `build-with-java21.sh`
   - Updated to recommend using `source set-java21.sh` directly

2. **docs/deployment/DEPLOYMENT_CHECKLIST.md**
   - Removed references to `.ps1` files
   - Updated to only mention bash scripts

3. **docs/realms/REALM_UPDATE_SOLUTION.md**
   - Removed PowerShell examples
   - Updated to only show bash script usage

4. **docs/infrastructure/JENKINS_AUTOMATION_SUMMARY.md**
   - Removed PowerShell script references
   - Updated to show bash script as alternative

## Verification

### Scripts Still Available (Bash)
- ✅ `start.sh` - Main startup script
- ✅ `fresh-start.sh` - Fresh start with cleanup
- ✅ `setup-env.sh` - Environment setup
- ✅ `update-realm-config.sh` - Realm configuration update
- ✅ `scripts/generate-realm-configs.sh` - Realm config generation
- ✅ `scripts/create-jenkins-pipeline.sh` - Jenkins pipeline creation
- ✅ `scripts/create-jenkins-pipeline.py` - Python alternative (cross-platform)

### Functionality Preserved
All functionality is preserved through:
- Bash script equivalents for all PowerShell scripts
- `start.sh` includes all features (including `--theme-only` flag)
- Python scripts available for cross-platform use where needed

## Migration Notes

If you were using any of the removed scripts:

1. **BUILD_THEME_ONLY.sh** → Use `./start.sh --theme-only`
2. **build-with-java21.sh** → Use `source set-java21.sh` then run Maven directly
3. **Any .ps1 file** → Use the corresponding `.sh` file

## Date
Cleanup completed: 2024-12-19
