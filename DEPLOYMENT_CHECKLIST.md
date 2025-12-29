# Deployment Checklist for Remote Server

This document verifies that all scripts and configurations are ready for deployment on a remote server.

## ✅ Verified Components

### 1. Scripts
- ✅ `start.sh` - Bash script for Linux/macOS/WSL
- ✅ `start.ps1` - PowerShell script for Windows
- ✅ `fresh-start.sh` - Fresh start with volume cleanup (Bash)
- ✅ `fresh-start.ps1` - Fresh start with volume cleanup (PowerShell)
- ✅ All scripts check for Docker availability
- ✅ All scripts use relative paths (no hardcoded absolute paths)
- ✅ All scripts handle errors gracefully

### 2. Docker Configuration
- ✅ `docker-compose.yml` - Properly configured with:
  - Artifacts builder service
  - PostgreSQL database with health checks
  - Keycloak service with proper dependencies
  - Volume mounts for providers and realm import
- ✅ No hardcoded localhost references (works on remote servers)
- ✅ All environment variables use defaults with override capability

### 3. Build Configuration
- ✅ `docker/builder/Dockerfile` - Uses official Node.js image with Java 17 and Maven
- ✅ `docker/builder/build-artifacts.sh` - Builds both phone provider and theme
- ✅ Theme repository URL updated to: `https://github.com/shivain22/rms-keycloakify-theme.git`
- ✅ Phone provider repository: `https://github.com/shivain22/keycloak-phone-provider.git`
- ✅ Build script handles GitHub token authentication for private repos

### 4. Keycloak Configuration
- ✅ `docker/keycloak-entrypoint.sh` - Handles debug logging configuration
- ✅ Realm import configured: `realm-import/gateway-realm.json`
- ✅ Realm import configured: `realm-import/rms-service-realm.json`
- ✅ Default admin user `gwadmin` with `ROLE_ADMIN` configured in gateway realm
- ✅ Default admin user `rmsadmin` with `ROLE_ADMIN` configured in rms-service realm
- ✅ Realms will be auto-imported on first start

### 5. Environment Files
- ✅ `env.template` - Template with all configuration options
- ✅ `env.example` - Example configuration
- ✅ Theme repository URL updated in `env.template`

## 📋 Pre-Deployment Steps

### On Remote Server (Linux):

1. **Prerequisites:**
   ```bash
   # Ensure Docker and Docker Compose are installed
   docker --version
   docker compose version
   ```

2. **Clone/Copy the repository:**
   ```bash
   # If using git
   git clone <your-repo-url>
   cd keycloak_with_plugins_deploy
   
   # Or copy files via SCP/rsync
   ```

3. **Create `.env` file:**
   ```bash
   cp env.template .env
   # Edit .env with your specific values:
   # - KEYCLOAK_ADMIN_PASSWORD (change from default)
   # - KC_DB_PASSWORD (change from default)
   # - MSG91_AUTH_KEY and MSG91_TEMPLATE_ID (if using MSG91)
   # - KEYCLOAK_HTTP_PORT (if different from 8080)
   # - KC_HOSTNAME (if behind reverse proxy)
   ```

4. **Make scripts executable:**
   ```bash
   chmod +x start.sh fresh-start.sh
   chmod +x docker/builder/build-artifacts.sh
   chmod +x docker/keycloak-entrypoint.sh
   ```

5. **Run the setup:**
   ```bash
   # For fresh start (removes all volumes)
   ./fresh-start.sh
   
   # Or regular start
   ./start.sh
   
   # With logs
   ./start.sh --logs
   ```

## 🔍 Verification Points

### After Deployment:

1. **Check containers are running:**
   ```bash
   docker compose ps
   ```
   Should show: `keycloak-artifacts-builder` (exited), `keycloak-db` (running), `keycloak` (running)

2. **Check Keycloak is accessible:**
   ```bash
   curl http://localhost:8080/health
   # Or visit in browser: http://<server-ip>:8080
   ```

3. **Check providers were built:**
   ```bash
   ls -la providers/
   ```
   Should contain:
   - `keycloak-phone-provider.jar`
   - `keycloak-phone-provider-msg91.jar`
   - `keycloak-theme-for-kc-26.2-and-above.jar`

4. **Check realms were imported:**
   - Login to Keycloak admin console: `http://<server-ip>:8080/admin`
   - Username: `admin` (from KEYCLOAK_ADMIN)
   - Password: (from KEYCLOAK_ADMIN_PASSWORD)
   - Verify "gateway" realm exists
   - Verify "rms-service" realm exists
   - Verify `gwadmin` user exists in gateway realm
   - Verify `rmsadmin` user exists in rms-service realm

5. **Test default admin users:**
   - **Gateway realm:** Login to `http://<server-ip>:8080/realms/gateway/account`
     - Username: `gwadmin`
     - Password: `gwadmin`
     - Should have ROLE_ADMIN and skip SMS verification
   - **RMS Service realm:** Login to `http://<server-ip>:8080/realms/rms-service/account`
     - Username: `rmsadmin`
     - Password: `rmsadmin`
     - Should have ROLE_ADMIN and skip SMS verification

## ⚠️ Potential Issues & Solutions

### Issue 1: Build fails with "Missing theme jar"
**Solution:** Check that the theme repository has the correct branch and the build script produces the expected JAR name. Verify `THEME_JAR_NAME` in `.env` matches what the theme repo builds.

### Issue 2: Port conflicts
**Solution:** Change `KEYCLOAK_HTTP_PORT` and/or `POSTGRES_PORT` in `.env` if ports are already in use.

### Issue 3: Permission denied on scripts
**Solution:** Run `chmod +x` on all `.sh` scripts.

### Issue 4: Private repositories
**Solution:** Set `GITHUB_TOKEN` in `.env` with a token that has read access to the repositories.

### Issue 5: Network issues (can't pull images)
**Solution:** Ensure the server has internet access or configure Docker to use a proxy/mirror.

### Issue 6: Volume cleanup issues
**Solution:** If `fresh-start.sh` doesn't clean volumes properly, manually run:
```bash
docker compose down -v
docker volume prune -f
```

## 🔐 Security Recommendations

1. **Change default passwords** in `.env`:
   - `KEYCLOAK_ADMIN_PASSWORD`
   - `KC_DB_PASSWORD`

2. **Use strong passwords** for production

3. **Configure firewall** to restrict access to Keycloak port

4. **Set up reverse proxy** with HTTPS (nginx, Traefik, etc.)

5. **Do NOT commit `.env` file** to version control

## 📝 Notes

- The build process may take 5-10 minutes on first run (downloading dependencies)
- Subsequent runs will be faster due to Maven cache volume (`m2_cache`)
- The `artifacts` container runs once and exits after building providers
- Keycloak will auto-import all realms on first start (via `--import-realm` flag)
- Default admin users (`gwadmin` and `rmsadmin`) are configured to skip SMS verification

## ✅ All Systems Ready

All scripts and configurations have been verified and are ready for remote server deployment.

