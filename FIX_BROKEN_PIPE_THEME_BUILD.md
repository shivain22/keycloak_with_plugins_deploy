# Fix: Broken Pipe Errors Hiding Theme Build Failures

## Problem
The broken pipe error filtering that was added for Maven builds might be hiding keycloakify build failures. Since `keycloakify build` uses Maven internally, Maven errors could be getting suppressed.

## Solution Applied

1. **Enhanced error detection** - Now checks for Maven errors even if npm exit code is 0
2. **No broken pipe filtering for theme builds** - We capture all output to see real errors
3. **Maven error pattern matching** - Specifically looks for Maven build failures
4. **keycloakify error detection** - Checks for keycloakify-specific errors

## Changes Made

The theme build section now:
- Captures full build output without filtering
- Checks for Maven errors even if exit code is 0
- Shows last 100 lines (more context)
- Specifically looks for "BUILD FAILURE", compilation errors, etc.
- Checks for keycloakify-specific error patterns

## Testing

Run the build and check for errors:

```bash
docker compose build artifacts
docker compose run --rm artifacts 2>&1 | tee build.log

# Check for Maven errors
grep -iE "(maven.*error|build.*failed|compilation.*error|BUILD FAILURE)" build.log

# Check for keycloakify errors  
grep -iE "(keycloakify.*error|template.*not.*found)" build.log
```

## What This Fixes

Previously, if keycloakify's internal Maven build failed but npm didn't propagate the error correctly, the build would appear to succeed but produce an incomplete JAR. Now we:
1. Check exit codes
2. Scan output for error patterns
3. Verify JAR structure
4. Check file sizes

This should catch silent failures that were being hidden by broken pipe filtering.

