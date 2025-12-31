#!/usr/bin/env bash
set -euo pipefail

# One-shot build container that:
# - clones gateway repo (https://github.com/shivain22/rms.git)
# - clones service repo (https://github.com/shivain22/rms-service.git)
# - builds Docker images using mvnw clean package jib:build
# - pushes images to Docker Hub
#
# Expected environment variables:
# - GATEWAY_REPO_URL (default: https://github.com/shivain22/rms.git)
# - GATEWAY_BRANCH (default: master)
# - SERVICE_REPO_URL (default: https://github.com/shivain22/rms-service.git)
# - SERVICE_BRANCH (default: master)
# - DOCKER_USERNAME (required for pushing to Docker Hub)
# - DOCKER_PASSWORD (required for pushing to Docker Hub)
# - GITHUB_TOKEN (optional, for private repos)

GATEWAY_REPO_URL="${GATEWAY_REPO_URL:-https://github.com/shivain22/rms.git}"
GATEWAY_BRANCH="${GATEWAY_BRANCH:-master}"
SERVICE_REPO_URL="${SERVICE_REPO_URL:-https://github.com/shivain22/rms-service.git}"
SERVICE_BRANCH="${SERVICE_BRANCH:-master}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
DOCKER_PASSWORD="${DOCKER_PASSWORD:-Asd!@#123}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

echo "=== Apps build container starting ==="
echo "GATEWAY_REPO_URL=${GATEWAY_REPO_URL} (branch=${GATEWAY_BRANCH})"
echo "SERVICE_REPO_URL=${SERVICE_REPO_URL} (branch=${SERVICE_BRANCH})"
echo "DOCKER_USERNAME=${DOCKER_USERNAME}"

if [[ -z "${DOCKER_USERNAME}" ]]; then
  echo "WARNING: DOCKER_USERNAME not set. Images will be built but may not be pushed." >&2
fi

# Use a persistent maven repo to reduce flaky downloads / corruption.
M2_DIR="${M2_DIR:-/m2}"
mkdir -p "${M2_DIR}/repository"
export MAVEN_OPTS="${MAVEN_OPTS:-} -Dmaven.repo.local=${M2_DIR}/repository"

# Also ensure any tool that passes its own -Dmaven.repo.local still ends up using our stable one.
mkdir -p /work/bin
REAL_MVN="$(command -v mvn)"
cat > /work/bin/mvn <<EOF
#!/usr/bin/env bash
set -euo pipefail
args=()
for a in "\$@"; do
  case "\$a" in
    -Dmaven.repo.local=*) ;;
    *) args+=("\$a") ;;
  esac
done
exec "${REAL_MVN}" "\${args[@]}" -Dmaven.repo.local="${M2_DIR}/repository"
EOF
chmod +x /work/bin/mvn
export PATH="/work/bin:${PATH}"

tmp="$(mktemp -d)"
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

git_clone() {
  # Usage: git_clone <repo_url> <branch> <dest_dir>
  local url="$1"
  local branch="$2"
  local dest="$3"

  local args=(clone --depth 1 --branch "${branch}" "${url}" "${dest}")

  # Disable interactive prompts inside the container.
  export GIT_TERMINAL_PROMPT=0

  if [[ -n "${GITHUB_TOKEN}" && "${url}" == https://github.com/* ]]; then
    # Use auth header (preferred over embedding token in URL).
    git -c http.extraHeader="AUTHORIZATION: bearer ${GITHUB_TOKEN}" "${args[@]}"
  else
    git "${args[@]}"
  fi
}

# Note: Jib handles Docker Hub authentication via -Ddocker.password
# No need to run docker login separately

# Build Gateway
echo "=== Building Gateway (rms) ==="
gateway_dir="${tmp}/rms"
git_clone "${GATEWAY_REPO_URL}" "${GATEWAY_BRANCH}" "${gateway_dir}"
pushd "${gateway_dir}" >/dev/null

# Determine Maven wrapper command
MVN_CMD="mvn"
if [[ -f "./mvnw" ]]; then
  chmod +x ./mvnw
  MVN_CMD="./mvnw"
elif [[ -f "./mvnw.cmd" ]]; then
  # Windows wrapper, but we're in Linux container, use mvn
  MVN_CMD="mvn"
fi

# Build and push Docker image
echo "Building and pushing gateway Docker image..."
# Override maven-compiler-plugin version to ensure Java 21 support (3.11.0+ supports Java 21)
# Also set compiler properties explicitly
if [[ -n "${DOCKER_USERNAME}" ]]; then
  ${MVN_CMD} clean package jib:build \
    -Dmaven.compiler.release=21 \
    -Dmaven.compiler.source=21 \
    -Dmaven.compiler.target=21 \
    -Dmaven.compiler-plugin.version=3.13.0 \
    -Ddocker.username="${DOCKER_USERNAME}" \
    -Ddocker.password="${DOCKER_PASSWORD}"
else
  ${MVN_CMD} clean package jib:build \
    -Dmaven.compiler.release=21 \
    -Dmaven.compiler.source=21 \
    -Dmaven.compiler.target=21 \
    -Dmaven.compiler-plugin.version=3.13.0 \
    -Ddocker.password="${DOCKER_PASSWORD}"
fi

if [[ $? -ne 0 ]]; then
  echo "ERROR: Gateway build failed!" >&2
  exit 1
fi

echo "Gateway image built and pushed successfully"
popd >/dev/null

# Build Service
echo "=== Building Service (rms-service) ==="
service_dir="${tmp}/rms-service"
git_clone "${SERVICE_REPO_URL}" "${SERVICE_BRANCH}" "${service_dir}"
pushd "${service_dir}" >/dev/null

# Determine Maven wrapper command
MVN_CMD="mvn"
if [[ -f "./mvnw" ]]; then
  chmod +x ./mvnw
  MVN_CMD="./mvnw"
elif [[ -f "./mvnw.cmd" ]]; then
  # Windows wrapper, but we're in Linux container, use mvn
  MVN_CMD="mvn"
fi

# Build and push Docker image
echo "Building and pushing service Docker image..."
# Override maven-compiler-plugin version to ensure Java 21 support (3.11.0+ supports Java 21)
# Also set compiler properties explicitly
if [[ -n "${DOCKER_USERNAME}" ]]; then
  ${MVN_CMD} clean package jib:build \
    -Dmaven.compiler.release=21 \
    -Dmaven.compiler.source=21 \
    -Dmaven.compiler.target=21 \
    -Dmaven.compiler-plugin.version=3.13.0 \
    -Ddocker.username="${DOCKER_USERNAME}" \
    -Ddocker.password="${DOCKER_PASSWORD}"
else
  ${MVN_CMD} clean package jib:build \
    -Dmaven.compiler.release=21 \
    -Dmaven.compiler.source=21 \
    -Dmaven.compiler.target=21 \
    -Dmaven.compiler-plugin.version=3.13.0 \
    -Ddocker.password="${DOCKER_PASSWORD}"
fi

if [[ $? -ne 0 ]]; then
  echo "ERROR: Service build failed!" >&2
  exit 1
fi

echo "Service image built and pushed successfully"
popd >/dev/null

echo "=== Apps build container done ==="

