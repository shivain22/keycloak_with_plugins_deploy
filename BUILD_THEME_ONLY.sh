#!/bin/bash
# Quick script to build only the theme
# Usage: ./BUILD_THEME_ONLY.sh

set -e

echo "Building theme only..."
docker compose build artifacts
docker compose run --rm artifacts --theme-only 2>&1 | tee theme-build.log

echo ""
echo "Build complete. Check theme-build.log for details."
echo "JAR location: ./providers/keycloak-theme-for-kc-26.2-and-above.jar"
ls -lh ./providers/keycloak-theme-for-kc-26.2-and-above.jar 2>/dev/null || echo "JAR not found!"

