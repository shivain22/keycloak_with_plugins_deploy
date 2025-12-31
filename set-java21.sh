#!/bin/bash
# Script to set Java 21 for Maven builds on Ubuntu/Linux
# Usage: 
#   source set-java21.sh    (to set in current shell)
#   . set-java21.sh          (alternative syntax)
#   bash set-java21.sh       (to just check/validate)

# Find Java 21 installation
JAVA_21_HOME=""

# Method 1: Check SDKMAN (common for developers)
if [ -d "$HOME/.sdkman/candidates/java" ]; then
    # Find latest Java 21 in SDKMAN
    JAVA_21_CANDIDATE=$(ls -d "$HOME/.sdkman/candidates/java"/21* 2>/dev/null | sort -V | tail -1)
    if [ -n "$JAVA_21_CANDIDATE" ] && [ -d "$JAVA_21_CANDIDATE" ]; then
        JAVA_21_HOME="$JAVA_21_CANDIDATE"
    fi
fi

# Method 2: Check system Java 21 installations (Ubuntu/Debian)
if [ -z "$JAVA_21_HOME" ]; then
    for jdk_path in /usr/lib/jvm/java-21-openjdk-amd64 /usr/lib/jvm/java-21-openjdk /usr/lib/jvm/java-21; do
        if [ -d "$jdk_path" ]; then
            JAVA_21_HOME="$jdk_path"
            break
        fi
    done
fi

# Method 3: Use update-alternatives to find Java 21
if [ -z "$JAVA_21_HOME" ] && command -v update-alternatives >/dev/null 2>&1; then
    JAVA_21_PATH=$(update-alternatives --list java 2>/dev/null | grep -i "21" | head -1)
    if [ -n "$JAVA_21_PATH" ] && [ -f "$JAVA_21_PATH" ]; then
        JAVA_21_HOME=$(dirname "$(dirname "$JAVA_21_PATH")")
        if [ ! -d "$JAVA_21_HOME" ]; then
            JAVA_21_HOME=""
        fi
    fi
fi

# Method 4: Check JAVA_HOME if it points to Java 21
if [ -z "$JAVA_21_HOME" ] && [ -n "${JAVA_HOME:-}" ]; then
    if [ -d "$JAVA_HOME" ] && "$JAVA_HOME/bin/java" -version 2>&1 | grep -q "version \"21"; then
        JAVA_21_HOME="$JAVA_HOME"
    fi
fi

# Method 5: Try to find java binary and check version
if [ -z "$JAVA_21_HOME" ]; then
    JAVA_BIN=$(command -v java 2>/dev/null)
    if [ -n "$JAVA_BIN" ] && "$JAVA_BIN" -version 2>&1 | grep -q "version \"21"; then
        # Resolve symlinks to find actual Java home
        if command -v readlink >/dev/null 2>&1; then
            JAVA_REAL=$(readlink -f "$JAVA_BIN" 2>/dev/null || readlink "$JAVA_BIN" 2>/dev/null || echo "$JAVA_BIN")
            JAVA_21_HOME=$(dirname "$(dirname "$JAVA_REAL")")
            if [ ! -d "$JAVA_21_HOME" ]; then
                JAVA_21_HOME=""
            fi
        fi
    fi
fi

# Validate Java 21 installation
if [ -z "$JAVA_21_HOME" ] || [ ! -d "$JAVA_21_HOME" ]; then
    echo "ERROR: Java 21 not found!" >&2
    echo "" >&2
    echo "Please install Java 21 using one of these methods:" >&2
    echo "  1. SDKMAN: sdk install java 21.0.9-tem" >&2
    echo "  2. Ubuntu: sudo apt-get install openjdk-21-jdk" >&2
    echo "  3. Or set JAVA_HOME manually to your Java 21 installation" >&2
    echo "" >&2
    echo "Current JAVA_HOME: ${JAVA_HOME:-not set}" >&2
    [ "${BASH_SOURCE[0]}" != "${0}" ] && return 1 || exit 1
fi

# Verify it's actually Java 21
JAVA_VERSION=$("$JAVA_21_HOME/bin/java" -version 2>&1 | head -1)
if ! echo "$JAVA_VERSION" | grep -q "version \"21"; then
    echo "ERROR: Found Java installation at $JAVA_21_HOME but it's not Java 21!" >&2
    echo "Version: $JAVA_VERSION" >&2
    [ "${BASH_SOURCE[0]}" != "${0}" ] && return 1 || exit 1
fi

# Export JAVA_HOME and update PATH
export JAVA_HOME="$JAVA_21_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

# Only print if sourced (not if run directly)
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    echo "✅ Set JAVA_HOME to: $JAVA_HOME"
    echo "Java version:"
    java -version 2>&1 | head -1
    echo ""
    echo "Maven will now use Java 21. Run your Maven command."
fi

