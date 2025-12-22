#!/usr/bin/env bash
set -euo pipefail

# One-command bootstrap for this repo.
# - Stops any existing containers
# - Builds & runs the "artifacts" one-shot container (produces ./providers/*.jar)
# - Starts Postgres + Keycloak
#
# Usage:
#   ./start.sh
#
# Optional:
#   ./start.sh --logs      # tail keycloak logs after start
#   ./start.sh --rebuild   # force rebuild of the artifacts image

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

echo "==> Stopping existing containers (if any) ..."
docker compose down 2>/dev/null || true

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

echo "==> Starting Postgres + Keycloak ..."
COMPOSE_BUILD_FLAG=""
if [ "${REBUILD}" = "1" ]; then
  COMPOSE_BUILD_FLAG="--build"
fi
docker compose up ${COMPOSE_BUILD_FLAG} -d

echo "==> Done."
# Read KEYCLOAK_HTTP_PORT from .env file (docker compose reads it automatically)
KEYCLOAK_PORT="8080"
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


