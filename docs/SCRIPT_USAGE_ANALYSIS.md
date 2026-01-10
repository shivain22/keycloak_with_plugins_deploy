# Script and Docker Compose File Usage Analysis

## Summary
All scripts and docker-compose files are either actively used or serve as useful utilities/documentation.

## ✅ Scripts Used by start.sh

### Directly Called:
1. **setup-env.sh** - Called when `--setup-env` flag is used
2. **scripts/generate-realm-configs.sh** - Called during startup to generate realm configs

### Referenced:
3. **docker-compose.yml** - Default compose file
4. **docker-compose-runtime.yml** - Used when `--runtime` flag is specified

## ✅ Scripts Used by fresh-start.sh

1. **scripts/generate-realm-configs.sh** - Called to generate realm configs

## ✅ Utility Scripts (Standalone, Not Called by start.sh)

These are useful utilities that can be run independently:

1. **update-realm-config.sh** - Updates Keycloak realm via Admin API
   - **Usage**: `./update-realm-config.sh realm-import/gateway-realm.json`
   - **Documented in**: `docs/realms/REALM_UPDATE_SOLUTION.md`

2. **set-java21.sh** - Sets Java 21 for Maven builds
   - **Usage**: `source set-java21.sh`
   - **Documented in**: `docs/deployment/JAVA21_SETUP.md`

3. **fix-permissions.sh** - Fixes execute permissions on scripts
   - **Usage**: `./fix-permissions.sh`
   - **Purpose**: One-time setup utility

4. **clean-docker-images.sh** - Cleans Docker images and containers
   - **Usage**: `./clean-docker-images.sh`
   - **Purpose**: Cleanup utility for build artifacts

5. **scripts/create-jenkins-pipeline.sh** - Creates Jenkins pipeline
   - **Usage**: `./scripts/create-jenkins-pipeline.sh`
   - **Documented in**: `docs/infrastructure/JENKINS_AUTOMATION_SUMMARY.md`

6. **scripts/setup-jenkins-pipeline.sh** - Interactive Jenkins pipeline setup
   - **Usage**: `./scripts/setup-jenkins-pipeline.sh`
   - **Documented in**: `docs/infrastructure/JENKINS_AUTOMATION_SUMMARY.md`

## ✅ Docker Compose Files

1. **docker-compose.yml** - Main compose file
   - **Used by**: `start.sh` (default)
   - **Purpose**: Full setup with builders

2. **docker-compose-runtime.yml** - Runtime-only compose file
   - **Used by**: `start.sh` (with `--runtime` flag)
   - **Purpose**: Runtime services only (no builders)

3. **docker-compose-secure.yml** - Secure compose file (localhost binding)
   - **Used by**: Manual execution (not by start.sh)
   - **Documented in**: 
     - `docs/architecture/SECURE_INFRASTRUCTURE_PLAN.md`
     - `docs/deployment/SECURE_SETUP.md`
     - `docs/deployment/LOCAL_DEVELOPMENT.md`
   - **Purpose**: Secure configuration with services bound to localhost only
   - **Status**: ✅ Keep - Valid alternative configuration

## ✅ Docker Builder Scripts (Used by Docker Compose)

These are called by Docker containers during build:

1. **docker/builder/build-artifacts.sh** - Builds Keycloak providers/theme
   - **Used by**: `artifacts` service in docker-compose.yml

2. **docker/builder/build-apps.sh** - Builds Gateway and Service apps
   - **Used by**: `apps-builder` service in docker-compose.yml

3. **docker/keycloak-entrypoint.sh** - Keycloak entrypoint script
   - **Used by**: `keycloak` service in docker-compose.yml

4. **docker/postgres/01-init-gateway-db.sh** - PostgreSQL init script
   - **Used by**: `rms-postgresql` service in docker-compose.yml

## 📊 Usage Matrix

| Script/File | Used by start.sh | Used by fresh-start.sh | Standalone Utility | Docker Compose | Status |
|-------------|------------------|------------------------|-------------------|----------------|--------|
| start.sh | N/A | No | Yes | No | ✅ Keep |
| fresh-start.sh | No | N/A | Yes | No | ✅ Keep |
| setup-env.sh | Yes (--setup-env) | No | Yes | No | ✅ Keep |
| scripts/generate-realm-configs.sh | Yes | Yes | Yes | No | ✅ Keep |
| update-realm-config.sh | No | No | Yes | No | ✅ Keep |
| set-java21.sh | No | No | Yes | No | ✅ Keep |
| fix-permissions.sh | No | No | Yes | No | ✅ Keep |
| clean-docker-images.sh | No | No | Yes | No | ✅ Keep |
| scripts/create-jenkins-pipeline.sh | No | No | Yes | No | ✅ Keep |
| scripts/setup-jenkins-pipeline.sh | No | No | Yes | No | ✅ Keep |
| docker-compose.yml | Yes (default) | Yes | Yes | N/A | ✅ Keep |
| docker-compose-runtime.yml | Yes (--runtime) | No | Yes | N/A | ✅ Keep |
| docker-compose-secure.yml | No | No | Yes | N/A | ✅ Keep |
| docker/builder/build-artifacts.sh | No | No | No | Yes | ✅ Keep |
| docker/builder/build-apps.sh | No | No | No | Yes | ✅ Keep |
| docker/keycloak-entrypoint.sh | No | No | No | Yes | ✅ Keep |
| docker/postgres/01-init-gateway-db.sh | No | No | No | Yes | ✅ Keep |

## 🎯 Conclusion

**All scripts and docker-compose files are either:**
1. ✅ Actively used by start.sh or fresh-start.sh
2. ✅ Useful standalone utilities (documented or commonly needed)
3. ✅ Required by Docker Compose services
4. ✅ Valid alternative configurations (docker-compose-secure.yml)

**No cleanup needed** - All files serve a purpose.

## 📝 Recommendations

1. **Keep all files** - They all serve valid purposes
2. **docker-compose-secure.yml** - Consider adding a flag to start.sh to use it (e.g., `--secure`)
3. **Utility scripts** - These are useful for manual operations and troubleshooting
