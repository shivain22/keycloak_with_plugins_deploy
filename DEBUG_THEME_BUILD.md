# Debug Theme Build Issues

## Problem
Theme JAR built in container is incomplete (smaller size) compared to local build.

## Enhanced Debugging

The build script now includes:
1. **Version verification** - Node, npm, Java versions
2. **Dependency verification** - Checks keycloakify is installed
3. **Build output capture** - Shows last 50 lines of build output
4. **Directory verification** - Checks dist_keycloak exists
5. **JAR structure verification** - Validates JAR contents before copying
6. **Size verification** - Compares sizes before/after copy

## Running the Build

```bash
# Rebuild the container to get latest script changes
docker compose build artifacts

# Run the build and capture full output
docker compose run --rm artifacts 2>&1 | tee build.log

# Check the log for issues
grep -i "error\|warning\|failed" build.log
```

## What to Look For

1. **Build Output**: Check if `npm run build-keycloak-theme` completes successfully
2. **JAR Size**: Compare the size shown in logs with your local build (should be ~4MB)
3. **Structure**: Verify JAR contains `META-INF/keycloak-themes.json` and `login.ftl`
4. **Copy Verification**: Check if size matches after copy

## Common Issues

### Issue: Build completes but JAR is small
- **Cause**: keycloakify might be failing silently or producing incomplete output
- **Check**: Look for errors in the build output, especially Maven/Java errors

### Issue: dist_keycloak directory empty
- **Cause**: Build failed but didn't error out
- **Check**: Look at full build output for npm/Maven errors

### Issue: JAR exists but missing files
- **Cause**: Incomplete build or keycloakify configuration issue
- **Check**: Verify vite.config.ts and package.json match your local setup

## Next Steps if Still Failing

1. **Compare build environments**: Check Node/npm versions match your local
2. **Check keycloakify version**: Ensure same version in package.json
3. **Verify GitHub repo**: Ensure the cloned repo matches your local code
4. **Check Maven output**: keycloakify uses Maven internally - check for Maven errors

