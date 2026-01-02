# Selective Build Options

## Problem
- Logs are streaming and hard to read
- Theme JAR is incomplete (2.3MB instead of 4MB)
- Need to build only specific components for debugging

## Solution: Selective Build Flags

You can now build only specific components using command-line flags.

## Usage

### Build Only Theme
```bash
docker compose run --rm artifacts --theme-only
```

### Build Only Phone Provider
```bash
docker compose run --rm artifacts --phone-provider-only
```

### Build Both (default)
```bash
docker compose run --rm artifacts
```

### Save Logs to File
```bash
docker compose run --rm artifacts --theme-only --log-file=/work/build.log
# Logs will be in ./providers/build.log (mapped from /work/providers)
```

### Less Verbose Output
```bash
docker compose run --rm artifacts --theme-only --quiet
```

## Examples

### Debug Theme Build Only
```bash
# Rebuild container
docker compose build artifacts

# Build only theme and save logs
docker compose run --rm -e BUILD_THEME_ONLY=1 artifacts --theme-only --log-file=/work/theme-build.log

# Check the log file
cat providers/theme-build.log | tail -100
```

### Quick Theme Rebuild
```bash
# Just rebuild theme without phone provider
docker compose run --rm artifacts --theme-only
```

### Check Theme Build Output
```bash
# Build theme and capture output
docker compose run --rm artifacts --theme-only 2>&1 | tee theme-build-output.log

# Check for errors
grep -iE "(error|failed|failure)" theme-build-output.log
```

## What Gets Built

- **Default**: Both phone provider and theme
- **--phone-provider-only**: Only phone provider (preserves existing theme JAR)
- **--theme-only**: Only theme (preserves existing phone provider JARs)

## Log File Location

If you use `--log-file=/work/build.log`, the file will appear in:
- Container: `/work/build.log`
- Host: `./providers/build.log` (because `/work/providers` is mounted to `./providers`)

## Troubleshooting Theme Build

1. **Build only theme to focus on the issue:**
   ```bash
   docker compose run --rm artifacts --theme-only 2>&1 | tee theme-debug.log
   ```

2. **Check for Maven errors:**
   ```bash
   grep -iE "(maven.*error|build.*failed|BUILD FAILURE)" theme-debug.log
   ```

3. **Check JAR size:**
   ```bash
   ls -lh providers/keycloak-theme-for-kc-26.2-and-above.jar
   ```

4. **Verify JAR contents:**
   ```bash
   jar -tf providers/keycloak-theme-for-kc-26.2-and-above.jar | head -20
   ```

## Next Steps

If theme build still produces incomplete JAR:
1. Check the build log for Maven errors
2. Compare with local build environment
3. Verify Node/npm versions match
4. Check if keycloakify is using correct Maven settings

