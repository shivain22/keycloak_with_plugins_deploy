#!/bin/bash
# Script to clean Docker images and containers related to the build process
# Usage: ./clean-docker-images.sh

set -euo pipefail

echo "=== Cleaning Docker images and containers ==="

# Stop and remove containers
echo "Stopping and removing containers..."
docker compose down 2>/dev/null || true
docker stop keycloak-artifacts-builder apps-builder 2>/dev/null || true
docker rm keycloak-artifacts-builder apps-builder 2>/dev/null || true

# Remove build images
echo "Removing build images..."
docker rmi keycloak_with_plugins_deploy-artifacts keycloak_with_plugins_deploy-apps-builder 2>/dev/null || true
docker rmi $(docker images | grep -E "(artifacts|apps-builder)" | awk '{print $3}') 2>/dev/null || true

# Remove dangling images
echo "Removing dangling images..."
docker image prune -f

# Optional: Remove all unused images (commented out by default)
# Uncomment the line below if you want to remove ALL unused images
# docker image prune -a -f

echo "✅ Docker cleanup complete!"
echo ""
echo "You can now rebuild with:"
echo "  docker compose build artifacts"
echo "  docker compose build apps-builder"
echo "  ./start.sh --build"

