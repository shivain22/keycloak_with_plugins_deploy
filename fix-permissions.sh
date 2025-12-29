#!/usr/bin/env bash
# Quick script to fix permissions on shell scripts

chmod +x fresh-start.sh
chmod +x start.sh
chmod +x scripts/generate-realm-configs.sh

echo "Permissions fixed! Now you can run:"
echo "  ./fresh-start.sh --rebuild"
echo "or"
echo "  bash fresh-start.sh --rebuild"

