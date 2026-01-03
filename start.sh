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
BUILD_GATEWAY_ONLY=0
BUILD_SERVICE_ONLY=0
PUSH_GATEWAY_ONLY=0
PUSH_SERVICE_ONLY=0
PULL_GATEWAY_ONLY=0
PULL_SERVICE_ONLY=0
STOP_ONLY=0
PUSH_ONLY=0
PULL_ONLY=0
REMOVE_IMAGES=0

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
    --build-gateway) BUILD_GATEWAY_ONLY=1; FORCE_BUILD=1 ;;
    --build-service) BUILD_SERVICE_ONLY=1; FORCE_BUILD=1 ;;
    --push-gateway) PUSH_GATEWAY_ONLY=1 ;;
    --push-service) PUSH_SERVICE_ONLY=1 ;;
    --pull-gateway) PULL_GATEWAY_ONLY=1 ;;
    --pull-service) PULL_SERVICE_ONLY=1 ;;
    --stop-only) STOP_ONLY=1 ;;
    --push-only) PUSH_ONLY=1 ;;
    --pull-only) PULL_ONLY=1 ;;
    --remove-images) REMOVE_IMAGES=1 ;;
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
      echo "Selective build/push/pull options:"
      echo "  --build-gateway      Build and push only gateway image"
      echo "  --build-service      Build and push only service image"
      echo "  --push-gateway       Push only gateway image (must exist locally)"
      echo "  --push-service       Push only service image (must exist locally)"
      echo "  --pull-gateway       Pull only gateway image from Docker Hub"
      echo "  --pull-service      Pull only service image from Docker Hub"
      echo "  --stop-only          Stop containers only (no build/start)"
      echo "  --push-only          Push images only (no build/start)"
      echo "  --pull-only          Pull images only (no build/start)"
      echo "  --remove-images      Remove gateway/service images after stopping (prevents cache use)"
      echo ""
      echo "Service options:"
      echo "  --runtime            Use runtime compose (no builders)"
      echo "  --clean              Remove volumes AND images (deletes database data and cached images)"
      echo "  --setup-env          Run setup-env.sh interactively"
      echo "  --logs               Tail logs after start"
      echo ""
      echo "Examples:"
      echo "  $0 --build-gateway           # Build and push only gateway"
      echo "  $0 --build-service           # Build and push only service"
      echo "  $0 --stop-only               # Stop all containers"
      echo "  $0 --stop-only --remove-images # Stop containers and remove images"
      echo "  $0 --clean                   # Stop, remove volumes AND images (full clean)"
      echo "  $0 --pull-gateway            # Pull only gateway image"
      echo "  $0 --push-service            # Push only service image"
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

# Stop containers based on mode
if [ "${BUILD_GATEWAY_ONLY}" = "1" ]; then
  echo "==> Stopping Gateway container only ..."
  docker compose -f "${COMPOSE_FILE}" stop gateway 2>/dev/null || true
  docker compose -f "${COMPOSE_FILE}" rm -f gateway 2>/dev/null || true
elif [ "${BUILD_SERVICE_ONLY}" = "1" ]; then
  echo "==> Stopping Service container only ..."
  docker compose -f "${COMPOSE_FILE}" stop service 2>/dev/null || true
  docker compose -f "${COMPOSE_FILE}" rm -f service 2>/dev/null || true
elif [ "${CLEAN_VOLUMES}" = "1" ]; then
  echo "==> Stopping all containers and removing volumes (this will delete all database data) ..."
  # Stop and remove containers first
  docker compose -f "${COMPOSE_FILE}" down 2>/dev/null || true
  
  # Get the project name (directory name or from COMPOSE_PROJECT_NAME)
  PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$(basename "$(pwd)")}"
  PROJECT_NAME="${PROJECT_NAME//-/_}"  # Replace hyphens with underscores
  
  # Remove volumes explicitly by name (Docker Compose prefixes volumes with project name)
  echo "  Removing Keycloak database volume (postgres_data) ..."
  docker volume rm "${PROJECT_NAME}_postgres_data" 2>/dev/null || \
  docker volume rm "postgres_data" 2>/dev/null || \
  echo "    (Volume not found or already removed)"
  
  echo "  Removing RMS database volume (rms_postgres_data) ..."
  docker volume rm "${PROJECT_NAME}_rms_postgres_data" 2>/dev/null || \
  docker volume rm "rms_postgres_data" 2>/dev/null || \
  echo "    (Volume not found or already removed)"
  
  echo "  Removing Maven cache volume (m2_cache) ..."
  docker volume rm "${PROJECT_NAME}_m2_cache" 2>/dev/null || \
  docker volume rm "m2_cache" 2>/dev/null || \
  echo "    (Volume not found or already removed)"
  
  # Also try docker compose down -v as a fallback
  docker compose -f "${COMPOSE_FILE}" down -v 2>/dev/null || true
  
  echo "✅ Volumes removed. Database will be recreated on next start."
else
  echo "==> Stopping existing containers (if any) ..."
  docker compose -f "${COMPOSE_FILE}" down 2>/dev/null || true
fi

# Remove images if requested (after stopping containers)
if [ "${REMOVE_IMAGES}" = "1" ] || [ "${CLEAN_VOLUMES}" = "1" ] || [ "${BUILD_GATEWAY_ONLY}" = "1" ] || [ "${BUILD_SERVICE_ONLY}" = "1" ]; then
  source .env 2>/dev/null || true
  GATEWAY_IMAGE="${GATEWAY_IMAGE:-shivain22/rms-gateway}"
  SERVICE_IMAGE="${SERVICE_IMAGE:-shivain22/rms-service}"
  GATEWAY_VERSION="${GATEWAY_VERSION:-latest}"
  SERVICE_VERSION="${SERVICE_VERSION:-latest}"
  
  if [ "${BUILD_GATEWAY_ONLY}" = "1" ]; then
    # Remove only gateway image
    echo "==> Removing Gateway Docker image to prevent cache usage ..."
    echo "  Removing Gateway image: ${GATEWAY_IMAGE}:${GATEWAY_VERSION} ..."
    docker rmi "${GATEWAY_IMAGE}:${GATEWAY_VERSION}" 2>/dev/null || echo "    (Image not found or already removed)"
    echo "  Cleaning up dangling Gateway images ..."
    docker images "${GATEWAY_IMAGE}" --format "{{.ID}}" | xargs -r docker rmi 2>/dev/null || true
    echo "✅ Gateway image removed. Fresh image will be built on next start."
  elif [ "${BUILD_SERVICE_ONLY}" = "1" ]; then
    # Remove only service image
    echo "==> Removing Service Docker image to prevent cache usage ..."
    echo "  Removing Service image: ${SERVICE_IMAGE}:${SERVICE_VERSION} ..."
    docker rmi "${SERVICE_IMAGE}:${SERVICE_VERSION}" 2>/dev/null || echo "    (Image not found or already removed)"
    echo "  Cleaning up dangling Service images ..."
    docker images "${SERVICE_IMAGE}" --format "{{.ID}}" | xargs -r docker rmi 2>/dev/null || true
    echo "✅ Service image removed. Fresh image will be built on next start."
  else
    # Remove both images (for --clean or --remove-images)
    echo "==> Removing Gateway and Service Docker images to prevent cache usage ..."
    echo "  Removing Gateway image: ${GATEWAY_IMAGE}:${GATEWAY_VERSION} ..."
    docker rmi "${GATEWAY_IMAGE}:${GATEWAY_VERSION}" 2>/dev/null || echo "    (Image not found or already removed)"
    echo "  Removing Service image: ${SERVICE_IMAGE}:${SERVICE_VERSION} ..."
    docker rmi "${SERVICE_IMAGE}:${SERVICE_VERSION}" 2>/dev/null || echo "    (Image not found or already removed)"
    echo "  Cleaning up dangling Gateway images ..."
    docker images "${GATEWAY_IMAGE}" --format "{{.ID}}" | xargs -r docker rmi 2>/dev/null || true
    echo "  Cleaning up dangling Service images ..."
    docker images "${SERVICE_IMAGE}" --format "{{.ID}}" | xargs -r docker rmi 2>/dev/null || true
    echo "✅ Images removed. Fresh images will be built/pulled on next start."
  fi
fi

# Handle stop-only mode
if [ "${STOP_ONLY}" = "1" ]; then
  echo "==> Stop-only mode: containers stopped."
  if [ "${REMOVE_IMAGES}" = "1" ]; then
    echo "==> Images removed. Exiting."
  else
    echo "==> Exiting."
  fi
  exit 0
fi

# Load environment variables
source .env 2>/dev/null || true
GATEWAY_IMAGE="${GATEWAY_IMAGE:-shivain22/rms-gateway}"
SERVICE_IMAGE="${SERVICE_IMAGE:-shivain22/rms-service}"
GATEWAY_VERSION="${GATEWAY_VERSION:-latest}"
SERVICE_VERSION="${SERVICE_VERSION:-latest}"
DOCKER_USERNAME="${DOCKER_USERNAME:-shivain22}"
DOCKER_PASSWORD="${DOCKER_PASSWORD:-Asd!@#123}"

# Function to push a single image
push_image() {
  local image="$1"
  local version="$2"
  local name="$3"
  
  echo "==> Pushing ${name} image: ${image}:${version} ..."
  docker push "${image}:${version}" || {
    echo "ERROR: Failed to push ${name} image!" >&2
    exit 1
  }
  echo "✅ ${name} image pushed successfully"
}

# Function to pull a single image
pull_image() {
  local image="$1"
  local version="$2"
  local name="$3"
  
  echo "==> Removing old local ${name} image: ${image}:${version} ..."
  docker rmi "${image}:${version}" 2>/dev/null || echo "  (No existing image to remove)"
  
  echo "==> Cleaning up dangling images for ${image} ..."
  docker images "${image}" --format "{{.ID}}" | xargs -r docker rmi 2>/dev/null || true
  
  echo "==> Pulling ${name} image: ${image}:${version} ..."
  docker pull "${image}:${version}" || {
    echo "ERROR: Failed to pull ${name} image!" >&2
    exit 1
  }
  echo "✅ ${name} image pulled successfully"
}

# Handle push-only mode
if [ "${PUSH_ONLY}" = "1" ]; then
  if [ "${PUSH_GATEWAY_ONLY}" = "1" ]; then
    push_image "${GATEWAY_IMAGE}" "${GATEWAY_VERSION}" "Gateway"
  elif [ "${PUSH_SERVICE_ONLY}" = "1" ]; then
    push_image "${SERVICE_IMAGE}" "${SERVICE_VERSION}" "Service"
  else
    push_image "${GATEWAY_IMAGE}" "${GATEWAY_VERSION}" "Gateway"
    push_image "${SERVICE_IMAGE}" "${SERVICE_VERSION}" "Service"
  fi
  echo "==> Push-only mode: images pushed. Exiting."
  exit 0
fi

# Handle pull-only mode
if [ "${PULL_ONLY}" = "1" ]; then
  if [ "${PULL_GATEWAY_ONLY}" = "1" ]; then
    pull_image "${GATEWAY_IMAGE}" "${GATEWAY_VERSION}" "Gateway"
  elif [ "${PULL_SERVICE_ONLY}" = "1" ]; then
    pull_image "${SERVICE_IMAGE}" "${SERVICE_VERSION}" "Service"
  else
    pull_image "${GATEWAY_IMAGE}" "${GATEWAY_VERSION}" "Gateway"
    pull_image "${SERVICE_IMAGE}" "${SERVICE_VERSION}" "Service"
  fi
  echo "==> Pull-only mode: images pulled. Exiting."
  exit 0
fi

# Handle individual push operations
if [ "${PUSH_GATEWAY_ONLY}" = "1" ]; then
  push_image "${GATEWAY_IMAGE}" "${GATEWAY_VERSION}" "Gateway"
  echo "==> Gateway image pushed. Exiting."
  exit 0
fi

if [ "${PUSH_SERVICE_ONLY}" = "1" ]; then
  push_image "${SERVICE_IMAGE}" "${SERVICE_VERSION}" "Service"
  echo "==> Service image pushed. Exiting."
  exit 0
fi

# Handle individual pull operations
if [ "${PULL_GATEWAY_ONLY}" = "1" ]; then
  pull_image "${GATEWAY_IMAGE}" "${GATEWAY_VERSION}" "Gateway"
  echo "==> Gateway image pulled. Exiting."
  exit 0
fi

if [ "${PULL_SERVICE_ONLY}" = "1" ]; then
  pull_image "${SERVICE_IMAGE}" "${SERVICE_VERSION}" "Service"
  echo "==> Service image pulled. Exiting."
  exit 0
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
    if [ "${PULL_GATEWAY_ONLY}" = "1" ]; then
      pull_image "${GATEWAY_IMAGE}" "${GATEWAY_VERSION}" "Gateway"
    elif [ "${PULL_SERVICE_ONLY}" = "1" ]; then
      pull_image "${SERVICE_IMAGE}" "${SERVICE_VERSION}" "Service"
    else
      pull_image "${GATEWAY_IMAGE}" "${GATEWAY_VERSION}" "Gateway"
      pull_image "${SERVICE_IMAGE}" "${SERVICE_VERSION}" "Service"
    fi
    echo "✅ Images pulled successfully"
  elif [ "${NEED_BUILD}" = "1" ]; then
    # For selective builds, images are already removed above
    # For regular builds, remove old local images before building to ensure fresh builds
    if [ "${BUILD_GATEWAY_ONLY}" != "1" ] && [ "${BUILD_SERVICE_ONLY}" != "1" ]; then
      source .env 2>/dev/null || true
      GATEWAY_IMAGE="${GATEWAY_IMAGE:-shivain22/rms-gateway}"
      SERVICE_IMAGE="${SERVICE_IMAGE:-shivain22/rms-service}"
      GATEWAY_VERSION="${GATEWAY_VERSION:-latest}"
      SERVICE_VERSION="${SERVICE_VERSION:-latest}"
      
      echo "==> Removing old local Gateway image: ${GATEWAY_IMAGE}:${GATEWAY_VERSION} ..."
      docker rmi "${GATEWAY_IMAGE}:${GATEWAY_VERSION}" 2>/dev/null || echo "  (No existing image to remove)"
      
      echo "==> Removing old local Service image: ${SERVICE_IMAGE}:${SERVICE_VERSION} ..."
      docker rmi "${SERVICE_IMAGE}:${SERVICE_VERSION}" 2>/dev/null || echo "  (No existing image to remove)"
      
      # Also remove any dangling images with the same name (without tag)
      echo "==> Cleaning up dangling images for ${GATEWAY_IMAGE} ..."
      docker images "${GATEWAY_IMAGE}" --format "{{.ID}}" | xargs -r docker rmi 2>/dev/null || true
      
      echo "==> Cleaning up dangling images for ${SERVICE_IMAGE} ..."
      docker images "${SERVICE_IMAGE}" --format "{{.ID}}" | xargs -r docker rmi 2>/dev/null || true
    fi
    
    # Skip artifacts build for selective builds (only needed for Keycloak, not for app images)
    if [ "${BUILD_GATEWAY_ONLY}" != "1" ] && [ "${BUILD_SERVICE_ONLY}" != "1" ]; then
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
    fi

    # Handle selective builds
    if [ "${BUILD_GATEWAY_ONLY}" = "1" ]; then
      echo "==> Building and pushing Gateway Docker image only ..."
      docker compose build apps-builder
      docker compose run --rm -e BUILD_GATEWAY_ONLY=1 apps-builder || {
        echo "ERROR: Gateway build failed!" >&2
        exit 1
      }
    elif [ "${BUILD_SERVICE_ONLY}" = "1" ]; then
      echo "==> Building and pushing Service Docker image only ..."
      docker compose build apps-builder
      docker compose run --rm -e BUILD_SERVICE_ONLY=1 apps-builder || {
        echo "ERROR: Service build failed!" >&2
        exit 1
      }
    else
      echo "==> Building and pushing Gateway and Service Docker images ..."
      docker compose build apps-builder
      docker compose run --rm apps-builder || {
        echo "ERROR: Apps build failed!" >&2
        exit 1
      }
    fi
  fi
fi

# Handle selective builds - start only the specific container
if [ "${BUILD_GATEWAY_ONLY}" = "1" ]; then
  echo "==> Starting Gateway container only (other services should already be running) ..."
  docker compose -f "${COMPOSE_FILE}" up -d --no-deps gateway || {
    echo "ERROR: Failed to start Gateway container!" >&2
    exit 1
  }
  echo "✅ Gateway container started (not waiting for startup - other services are available)"
  echo ""
  echo "Gateway is starting. Check status with:"
  echo "  docker compose -f ${COMPOSE_FILE} ps gateway"
  echo ""
  echo "View logs with:"
  echo "  docker compose -f ${COMPOSE_FILE} logs -f gateway"
  exit 0
elif [ "${BUILD_SERVICE_ONLY}" = "1" ]; then
  echo "==> Starting Service container only (other services should already be running) ..."
  docker compose -f "${COMPOSE_FILE}" up -d --no-deps service || {
    echo "ERROR: Failed to start Service container!" >&2
    exit 1
  }
  echo "✅ Service container started (not waiting for startup - other services are available)"
  echo ""
  echo "Service is starting. Check status with:"
  echo "  docker compose -f ${COMPOSE_FILE} ps service"
  echo ""
  echo "View logs with:"
  echo "  docker compose -f ${COMPOSE_FILE} logs -f service"
  exit 0
fi

echo "==> Starting services ..."
docker compose -f "${COMPOSE_FILE}" up -d --remove-orphans

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
