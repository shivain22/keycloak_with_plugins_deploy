#!/usr/bin/env bash
set -euo pipefail

# Smart startup script with build detection
# Usage:
#   ./start.sh              # Auto-detect if build is needed
#   ./start.sh --build      # Force build
#   ./start.sh --no-build   # Skip build, just start services
#   ./start.sh --runtime    # Use runtime compose (no builders)
#   ./start.sh --logs       # Tail logs after start
#   ./start.sh --clean      # Remove volumes (useful when postgres version changes)

# Ensure script is run with bash
if [ -z "${BASH_VERSION:-}" ]; then
  echo "ERROR: This script requires bash. Please run: bash $0" >&2
  exit 1
fi

# Get script directory
if [ -n "${BASH_SOURCE:-}" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
fi
cd "${REPO_ROOT}"

# Parse arguments
FORCE_BUILD=0
SKIP_BUILD=0
TAIL_LOGS=0
USE_RUNTIME=0
CLEAN_VOLUMES=0

for arg in "$@"; do
  case "${arg}" in
    --build) FORCE_BUILD=1 ;;
    --no-build) SKIP_BUILD=1 ;;
    --logs) TAIL_LOGS=1 ;;
    --runtime) USE_RUNTIME=1 ;;
    --clean) CLEAN_VOLUMES=1 ;;
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

# Determine which compose file to use
COMPOSE_FILE="docker-compose.yml"
if [ "${USE_RUNTIME}" = "1" ]; then
  COMPOSE_FILE="docker-compose-runtime.yml"
fi

# Function to check if git has new commits
check_git_changes() {
  local repo_url="$1"
  local branch="$2"
  local repo_name=$(basename "$repo_url" .git)
  
  # Check if we have a local clone to compare
  if [ -d "/tmp/${repo_name}" ]; then
    cd "/tmp/${repo_name}"
    git fetch origin "${branch}" >/dev/null 2>&1 || return 1
    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "")
    REMOTE=$(git rev-parse "origin/${branch}" 2>/dev/null || echo "")
    cd - >/dev/null
    if [ -n "$LOCAL" ] && [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
      return 0  # Changes detected
    fi
  fi
  return 1  # No changes
}

# Function to check if Docker image exists and is up to date
check_image_exists() {
  local image="$1"
  local tag="$2"
  docker image inspect "${image}:${tag}" >/dev/null 2>&1
}

# Determine if build is needed
NEED_BUILD=0

if [ "${FORCE_BUILD}" = "1" ]; then
  NEED_BUILD=1
  echo "==> Build forced via --build flag"
elif [ "${SKIP_BUILD}" = "1" ]; then
  NEED_BUILD=0
  echo "==> Build skipped via --no-build flag"
else
  # Auto-detect: check if images exist and if there are git changes
  source .env 2>/dev/null || true
  
  GATEWAY_IMAGE="${GATEWAY_IMAGE:-shivain22/rms-gateway}"
  SERVICE_IMAGE="${SERVICE_IMAGE:-shivain22/rms-service}"
  GATEWAY_VERSION="${GATEWAY_VERSION:-latest}"
  SERVICE_VERSION="${SERVICE_VERSION:-latest}"
  
  if ! check_image_exists "${GATEWAY_IMAGE}" "${GATEWAY_VERSION}" || \
     ! check_image_exists "${SERVICE_IMAGE}" "${SERVICE_VERSION}"; then
    NEED_BUILD=1
    echo "==> Docker images not found, build required"
  elif check_git_changes "${GATEWAY_REPO_URL:-}" "${GATEWAY_BRANCH:-master}" || \
       check_git_changes "${SERVICE_REPO_URL:-}" "${SERVICE_BRANCH:-master}"; then
    NEED_BUILD=1
    echo "==> Git changes detected, build required"
  else
    echo "==> No changes detected, skipping build"
  fi
fi

echo "==> Stopping existing containers (if any) ..."
if [ "${CLEAN_VOLUMES}" = "1" ]; then
  echo "==> Removing volumes (this will delete all database data) ..."
  docker compose -f "${COMPOSE_FILE}" down -v 2>/dev/null || true
  echo "✅ Volumes removed. Database will be recreated on next start."
else
  docker compose -f "${COMPOSE_FILE}" down 2>/dev/null || true
fi

if [ "${USE_RUNTIME}" = "0" ]; then
  # Full setup: artifacts + apps builder
  echo "==> Generating realm configurations ..."
  ENV_VAR="${ENVIRONMENT:-prod}"
  bash scripts/generate-realm-configs.sh "${ENV_VAR}" || {
    echo "ERROR: Realm config generation failed!" >&2
    exit 1
  }

  if [ "${NEED_BUILD}" = "1" ]; then
    echo "==> Building Keycloak artifacts (providers) ..."
    docker compose build artifacts
    docker compose run --rm artifacts || {
      echo "ERROR: Artifacts build failed!" >&2
      exit 1
    }

    echo "==> Building and pushing Gateway and Service Docker images ..."
    docker compose build apps-builder
    docker compose run --rm apps-builder || {
      echo "ERROR: Apps build failed!" >&2
      exit 1
    }
  fi
fi

echo "==> Starting services ..."
docker compose -f "${COMPOSE_FILE}" up -d

echo "==> Done."
echo ""
echo "Services are starting. Check status with:"
echo "  docker compose -f ${COMPOSE_FILE} ps"
echo ""
echo "View logs with:"
echo "  docker compose -f ${COMPOSE_FILE} logs -f"

if [ "${TAIL_LOGS}" = "1" ]; then
  echo ""
  echo "==> Tailing logs (Ctrl+C to stop) ..."
  docker compose -f "${COMPOSE_FILE}" logs -f --tail 200
fi
