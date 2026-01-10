# Fix: Streaming Output from Container Builds

## Problem
npm installation logs and build output were not appearing in real-time in the console because:
1. Output was being piped to `tail -20` (only showing last 20 lines)
2. Build output was captured in a variable, buffering it until completion
3. Docker compose might buffer output in some cases

## Solution Applied

### 1. Removed Output Truncation
- **Before**: `npm install ... 2>&1 | tail -20` (only last 20 lines)
- **After**: `npm install ...` (full output streams)

### 2. Real-time Build Output
- **Before**: `BUILD_OUTPUT=$(npm run build-keycloak-theme 2>&1)` (buffered)
- **After**: `npm run build-keycloak-theme 2>&1 | tee "$BUILD_LOG_FILE"` (streams + captures)

### 3. Error Checking
- Still captures output to a temp file for error pattern matching
- But streams in real-time using `tee`
- Cleans up temp file after checking

## What You'll See Now

When running `./start.sh --theme-only`, you'll see:

1. **npm install output** - Streams in real-time, shows all package installations
2. **Build output** - Streams in real-time as keycloakify/Maven runs
3. **Error detection** - Still checks for errors after streaming

## Benefits

- **Real-time feedback** - See what's happening as it happens
- **Better debugging** - Can see where builds fail immediately
- **Progress visibility** - Know npm is actually working, not hung
- **Error detection** - Still catches Maven/keycloakify errors

## Testing

Run the build and you should see npm output streaming:

```bash
./start.sh --theme-only
```

You should now see:
- npm installing packages in real-time
- Build progress as it happens
- Any errors immediately when they occur

