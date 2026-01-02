#!/usr/bin/env bash
set -euo pipefail

# Smart startup script with build detection
# Usage:
#   ./start.sh                      # Auto-detect if build is needed
#   ./start.sh --build              # Force build
#   ./start.sh --no-build           # Skip build, just start services
#   ./start.sh --pull               # Pull latest images from Docker Hub (instead of building)
#   ./start.sh --runtime            # Use runtime compose (no builders)
#   ./start.sh --logs               # Tail logs after start
#   ./start.sh --clean              # Remove volumes (useful when postgres version changes)
#   ./start.sh --setup-env          # Run setup-env.sh to create/update .env file
#   ./start.sh --theme-only         # Build only theme (preserves phone provider JARs)
#   ./start.sh --phone-provider-only # Build only phone provider (preserves theme JAR)
#   ./start.sh --quiet-build        # Less verbose build output
#   ./start.sh --help               # Show full help

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
PULL_IMAGES=0
TAIL_LOGS=0
USE_RUNTIME=0
CLEAN_VOLUMES=0
SETUP_ENV=0
BUILD_THEME_ONLY=0
BUILD_PHONE_PROVIDER_ONLY=0
ARTIFACT_BUILD_ARGS=""

for arg in "$@"; do
  case "${arg}" in
    --build) FORCE_BUILD=1 ;;
    --no-build) SKIP_BUILD=1 ;;
    --pull) PULL_IMAGES=1 ;;
    --logs) TAIL_LOGS=1 ;;
    --runtime) USE_RUNTIME=1 ;;
    --clean) CLEAN_VOLUMES=1 ;;
    --setup-env) SETUP_ENV=1 ;;
    --theme-only) BUILD_THEME_ONLY=1; ARTIFACT_BUILD_ARGS="${ARTIFACT_BUILD_ARGS} --theme-only" ;;
    --phone-provider-only) BUILD_PHONE_PROVIDER_ONLY=1; ARTIFACT_BUILD_ARGS="${ARTIFACT_BUILD_ARGS} --phone-provider-only" ;;
    --quiet-build) ARTIFACT_BUILD_ARGS="${ARTIFACT_BUILD_ARGS} --quiet" ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo ""
      echo "Build options:"
      echo "  --build              Force build of all components"
      echo "  --no-build           Skip build, just start services"
      echo "  --pull               Pull images from Docker Hub instead of building"
      echo "  --theme-only         Build only theme (preserves phone provider JARs)"
      echo "  --phone-provider-only Build only phone provider (preserves theme JAR)"
      echo "  --quiet-build        Less verbose build output"
      echo ""
      echo "Service options:"
      echo "  --runtime            Use runtime compose (no builders)"
      echo "  --clean              Remove volumes (deletes database data)"
      echo "  --setup-env          Run setup-env.sh interactively"
      echo "  --logs               Tail logs after start"
      echo ""
      echo "Examples:"
      echo "  $0 --theme-only              # Build only theme and start"
      echo "  $0 --phone-provider-only     # Build only phone provider and start"
      echo "  $0 --build --theme-only      # Force build, theme only"
      exit 0
      ;;
    *) echo "Unknown arg: ${arg}" >&2; echo "Use --help for usage information" >&2; exit 2 ;;
  esac
done

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found on PATH" >&2; exit 1; }

# Setup .env file - always overwrite/create from env.example
if [ "${SETUP_ENV}" = "1" ]; then
  # Interactive mode: use setup-env.sh which prompts for confirmation
  echo "==> Running setup-env.sh (interactive mode) ..."
  if [ -f "setup-env.sh" ]; then
    bash setup-env.sh
  else
    echo "ERROR: setup-env.sh not found!" >&2
    exit 1
  fi
else
  # Default: always overwrite/create .env from env.example
  if [ -f ".env" ]; then
    echo "==> Overwriting existing .env file from env.example ..."
  else
    echo "==> Creating .env file from env.example ..."
  fi
  cp env.example .env
  echo "✅ .env file created/updated from env.example"
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

if [ "${PULL_IMAGES}" = "1" ]; then
  NEED_BUILD=0
  echo "==> Pull mode: will pull images from Docker Hub instead of building"
elif [ "${FORCE_BUILD}" = "1" ]; then
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

  if [ "${PULL_IMAGES}" = "1" ]; then
    # Pull images from Docker Hub
    source .env 2>/dev/null || true
    GATEWAY_IMAGE="${GATEWAY_IMAGE:-shivain22/rms-gateway}"
    SERVICE_IMAGE="${SERVICE_IMAGE:-shivain22/rms-service}"
    GATEWAY_VERSION="${GATEWAY_VERSION:-latest}"
    SERVICE_VERSION="${SERVICE_VERSION:-latest}"
    
    echo "==> Pulling Gateway image: ${GATEWAY_IMAGE}:${GATEWAY_VERSION} ..."
    docker pull "${GATEWAY_IMAGE}:${GATEWAY_VERSION}" || {
      echo "ERROR: Failed to pull Gateway image!" >&2
      exit 1
    }
    
    echo "==> Pulling Service image: ${SERVICE_IMAGE}:${SERVICE_VERSION} ..."
    docker pull "${SERVICE_IMAGE}:${SERVICE_VERSION}" || {
      echo "ERROR: Failed to pull Service image!" >&2
      exit 1
    }
    
    echo "✅ Images pulled successfully"
  elif [ "${NEED_BUILD}" = "1" ]; then
    echo "==> Building Keycloak artifacts (providers) ..."
    if [ "${BUILD_THEME_ONLY}" = "1" ]; then
      echo "  Building theme only (preserving phone provider JARs)"
    elif [ "${BUILD_PHONE_PROVIDER_ONLY}" = "1" ]; then
      echo "  Building phone provider only (preserving theme JAR)"
    fi
    docker compose build artifacts
    # Run artifacts build - output will stream in real-time
    docker compose run --rm artifacts ${ARTIFACT_BUILD_ARGS} || {
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
