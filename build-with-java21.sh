#!/bin/bash
# Wrapper script to ensure Java 21 is used for Maven builds
# Usage: ./build-with-java21.sh [maven-command-and-args]
# Example: ./build-with-java21.sh clean package

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the Java 21 setup script
if [ -f "${SCRIPT_DIR}/set-java21.sh" ]; then
    source "${SCRIPT_DIR}/set-java21.sh"
else
    echo "ERROR: set-java21.sh not found in ${SCRIPT_DIR}" >&2
    exit 1
fi

# Verify Maven will use Java 21
echo "Verifying Maven Java version..."
mvn -version | head -3

# Run Maven with all passed arguments
echo ""
echo "Running: mvn $*"
echo ""
mvn "$@"

