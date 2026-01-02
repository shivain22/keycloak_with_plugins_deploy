# Fix Theme JAR Size Mismatch Issue

## Problem
The theme JAR in the container (2.3MB) is smaller than the locally built JAR (4MB), indicating the container is using an older/different build.

## Root Cause
The `build-artifacts.sh` script clones the theme from GitHub and builds it inside the container. If:
1. The GitHub repo has an older version
2. The build process creates a different JAR
3. The locally built JAR was copied after Keycloak started

Then the container will have a different JAR than your local build.

## Solutions

### Option 1: Copy Your Local JAR After Build (Recommended)
After the build script runs, manually copy your locally built JAR:

```bash
# On your server, copy the locally built JAR
cp /path/to/local/keycloak-theme-for-kc-26.2-and-above.jar ~/Shiva/Workspace/keycloak_with_plugins_deploy/providers/

# Verify the size
ls -lh ~/Shiva/Workspace/keycloak_with_plugins_deploy/providers/keycloak-theme-for-kc-26.2-and-above.jar

# Restart Keycloak to pick up the new JAR
docker compose -f docker-compose.yml restart keycloak
```

### Option 2: Update Build Script to Use Local Theme
Modify `docker/builder/build-artifacts.sh` to use a local theme directory instead of cloning from GitHub.

### Option 3: Ensure Build Script Uses Latest Code
Make sure the GitHub repository has the latest code, or update `THEME_BRANCH` in your `.env` file.

## Verification Steps

1. **Check JAR size on server:**
```bash
ls -lh ~/Shiva/Workspace/keycloak_with_plugins_deploy/providers/keycloak-theme-for-kc-26.2-and-above.jar
```

2. **Check JAR size in container:**
```bash
docker compose -f docker-compose.yml exec keycloak ls -lh /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar
```

3. **Verify theme registration:**
```bash
docker compose -f docker-compose.yml exec keycloak sh -c "cd /tmp && jar -xf /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar META-INF/keycloak-themes.json && cat META-INF/keycloak-themes.json"
```

4. **After copying and restarting, check if theme loads:**
```bash
docker compose -f docker-compose.yml logs keycloak | grep -i "rms-auth-theme-plugin"
```

## Quick Fix Command

If you have the 4MB JAR locally, copy it to the server and restart:

```bash
# On your local machine, copy to server (adjust paths)
scp C:\Users\shiva\eclipse-workspace\rms-auth-theme-plugin\dist_keycloak\keycloak-theme-for-kc-26.2-and-above.jar user@server:~/Shiva/Workspace/keycloak_with_plugins_deploy/providers/

# On server, restart Keycloak
cd ~/Shiva/Workspace/keycloak_with_plugins_deploy
docker compose -f docker-compose.yml restart keycloak
```

