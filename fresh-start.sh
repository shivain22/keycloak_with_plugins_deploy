#!/usr/bin/env bash
set -euo pipefail

# Ensure script is run with bash (not sh)
if [ -z "${BASH_VERSION:-}" ]; then
  echo "ERROR: This script requires bash. Please run: bash $0" >&2
  exit 1
fi

# Fresh start script - deletes all volumes and starts from scratch
# - Stops any existing containers
# - Removes all volumes (postgres_data, m2_cache)
# - Builds & runs the "artifacts" one-shot container (produces ./providers/*.jar)
# - Starts Postgres + Keycloak
#
# Usage:
#   ./fresh-start.sh
#
# Optional:
#   ./fresh-start.sh --logs      # tail keycloak logs after start
#   ./fresh-start.sh --rebuild   # force rebuild of the artifacts image

# Get script directory (compatible with both bash and sh)
if [ -n "${BASH_SOURCE:-}" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
fi
cd "${REPO_ROOT}"

REBUILD=0
TAIL_LOGS=0

for arg in "$@"; do
  case "${arg}" in
    --rebuild) REBUILD=1 ;;
    --logs) TAIL_LOGS=1 ;;
    *) echo "Unknown arg: ${arg}" >&2; exit 2 ;;
  esac
done

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found on PATH" >&2; exit 1; }

# Setup .env file if it doesn't exist
if [ ! -f ".env" ]; then
  echo "==> Creating .env file from env.example ..."
  cp env.example .env
  echo "✅ Created .env file. Review and update if needed."
fi

echo "==> Stopping existing containers (if any) ..."
docker compose down 2>/dev/null || true

echo "==> Removing all volumes (postgres_data, m2_cache) ..."
# Remove volumes if they exist
docker volume rm keycloak_with_plugins_deploy_postgres_data 2>/dev/null || \
docker volume rm postgres_data 2>/dev/null || true
docker volume rm keycloak_with_plugins_deploy_m2_cache 2>/dev/null || \
docker volume rm m2_cache 2>/dev/null || true

# Also try removing with docker compose (more reliable)
docker compose down -v 2>/dev/null || true

echo "==> Generating realm configurations ..."
ENV_VAR="${ENVIRONMENT:-local}"
bash scripts/generate-realm-configs.sh "${ENV_VAR}"
if [ $? -ne 0 ]; then
  echo "ERROR: Realm config generation failed!" >&2
  exit 1
fi

echo "==> Building artifacts (providers) ..."
# Build the image first if --rebuild was requested
if [ "${REBUILD}" = "1" ]; then
  echo "  (rebuilding artifacts image...)"
  docker compose build artifacts
fi

# Use 'docker compose run' for one-shot containers (properly handles exit codes)
if ! docker compose run --rm artifacts; then
  echo "ERROR: Artifacts build failed!" >&2
  exit 1
fi

echo "==> Building and pushing Gateway and Service Docker images ..."
# Build the apps-builder image first if --rebuild was requested
if [ "${REBUILD}" = "1" ]; then
  echo "  (rebuilding apps-builder image...)"
  docker compose build apps-builder
fi

# Build and push gateway and service images
if ! docker compose run --rm apps-builder; then
  echo "ERROR: Apps build failed!" >&2
  exit 1
fi

echo "==> Starting Postgres + Keycloak + Gateway + Service ..."
COMPOSE_BUILD_FLAG=""
if [ "${REBUILD}" = "1" ]; then
  COMPOSE_BUILD_FLAG="--build"
fi
docker compose up ${COMPOSE_BUILD_FLAG} -d --remove-orphans

echo "==> Done."
# Read KEYCLOAK_HTTP_PORT from .env file (docker compose reads it automatically)
KEYCLOAK_PORT="9292"
if [ -f .env ]; then
  ENV_PORT=$(grep -E "^KEYCLOAK_HTTP_PORT=" .env 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo "")
  if [ -n "${ENV_PORT}" ]; then
    KEYCLOAK_PORT="${ENV_PORT}"
  fi
fi
echo "Keycloak should be available at: http://localhost:${KEYCLOAK_PORT}"

if [ "${TAIL_LOGS}" = "1" ]; then
  echo "==> Tailing Keycloak logs (Ctrl+C to stop) ..."
  docker compose logs -f --tail 200 keycloak
fi

