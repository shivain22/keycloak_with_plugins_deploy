#!/usr/bin/env bash
set -euo pipefail

# One-command bootstrap for this repo.
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

COMPOSE_BUILD_FLAG=""
if [[ "${REBUILD}" == "1" ]]; then
  COMPOSE_BUILD_FLAG="--build"
fi

echo "==> Building artifacts (providers) ..."
docker compose up ${COMPOSE_BUILD_FLAG} --abort-on-container-exit artifacts

echo "==> Starting Postgres + Keycloak ..."
docker compose up ${COMPOSE_BUILD_FLAG} -d

echo "==> Done."
echo "Keycloak should be available at: http://localhost:8080"

if [[ "${TAIL_LOGS}" == "1" ]]; then
  echo "==> Tailing Keycloak logs (Ctrl+C to stop) ..."
  docker compose logs -f --tail 200 keycloak
fi


