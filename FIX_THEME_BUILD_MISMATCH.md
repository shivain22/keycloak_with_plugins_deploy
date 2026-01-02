# Fix: Theme Build Mismatch Between Local and Container

## Problem
The container build produces different results than local build:
- **Theme name**: Container shows `"keycloakify-starter"` instead of `"rms-auth-theme-plugin"`
- **JAR versions**: Container generates `keycloak-theme-for-kc-22-to-25.jar` instead of `keycloak-theme-for-kc-26.2-and-above.jar`
- **Size**: Container JAR is 2.2MB vs local 4MB

## Root Cause
The GitHub repository (`rms-keycloakify-theme`) is outdated and doesn't match your local code:
1. Missing `keycloakVersionTargets: ["26.2"]` in `vite.config.ts`
2. Theme name might be set to default `keycloakify-starter`
3. Different build configuration

## Solution Applied

### 1. Auto-Patch vite.config.ts
The build script now:
- Checks if `keycloakVersionTargets` is missing
- Adds/updates it to `["26.2"]` to generate the correct JAR
- Backs up original file

### 2. Verify Theme Name
- Checks `src/kc.gen.tsx` for correct theme name
- Warns if theme name doesn't match `rms-auth-theme-plugin`

## What This Fixes

After this patch:
- ✅ JAR will be named `keycloak-theme-for-kc-26.2-and-above.jar`
- ✅ Theme name will be `rms-auth-theme-plugin` (if kc.gen.tsx is correct)
- ✅ Build will match your local environment

## Next Steps

### Option 1: Update GitHub Repo (Recommended)
Push your local changes to the GitHub repo:
```bash
cd C:\Users\shiva\eclipse-workspace\rms-auth-theme-plugin
git add .
git commit -m "Update for Keycloak 26.2+ and correct theme name"
git push origin main
```

### Option 2: Use Local Directory (Alternative)
Modify the build script to use a local directory mount instead of cloning from GitHub.

### Option 3: Keep Auto-Patching
The current solution will auto-patch the repo during build, but it's better to have the repo up-to-date.

## Verification

After running the build, check:
1. JAR name should be `keycloak-theme-for-kc-26.2-and-above.jar`
2. Theme name in JAR should be `rms-auth-theme-plugin`
3. JAR size should be closer to 4MB (if all files are included)

```bash
./start.sh --theme-only
# Then check:
jar -xf providers/keycloak-theme-for-kc-26.2-and-above.jar META-INF/keycloak-themes.json
cat META-INF/keycloak-themes.json
```

