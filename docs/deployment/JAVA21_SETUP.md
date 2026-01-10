# Java 21 Setup for Maven Builds

## Problem
If you encounter the error:
```
[ERROR] Fatal error compiling: error: release version 21 not supported
```

This means Maven is using a Java version other than Java 21, but your project requires Java 21.

## Solution

### Option 1: Source the setup script manually (Recommended)
Before running Maven commands, source the setup script:

```bash
source set-java21.sh
# or
. set-java21.sh

# Then run your Maven commands normally
mvn clean package
```

### Option 2: Set JAVA_HOME manually
If the automatic detection doesn't work, set JAVA_HOME manually:

```bash
# For SDKMAN installations:
export JAVA_HOME="$HOME/.sdkman/candidates/java/21.0.9-tem"

# For system installations (Ubuntu/Debian):
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"

# Update PATH
export PATH="$JAVA_HOME/bin:$PATH"

# Verify
java -version
mvn -version
```

## Verification

After setting up Java 21, verify it's working:

```bash
# Check Java version
java -version
# Should show: openjdk version "21.x.x"

# Check Maven is using Java 21
mvn -version
# Should show: Java version: 21.x.x
```

## Docker Builds

For Docker builds, the Dockerfile has been updated to use Java 21. Rebuild the Docker image:

```bash
docker compose build apps-builder
```

## Troubleshooting

### Java 21 not found
If the script can't find Java 21, install it:

**Using SDKMAN (recommended for developers):**
```bash
sdk install java 21.0.9-tem
sdk use java 21.0.9-tem
```

**Using apt (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install openjdk-21-jdk
```

### Maven still using wrong Java version
1. Check `JAVA_HOME` is set correctly: `echo $JAVA_HOME`
2. Check Maven's Java: `mvn -version`
3. Ensure `JAVA_HOME/bin` is in your PATH: `echo $PATH`
4. Try sourcing the script again: `source set-java21.sh`

