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
BUILD_GATEWAY_ONLY="${BUILD_GATEWAY_ONLY:-0}"
BUILD_SERVICE_ONLY="${BUILD_SERVICE_ONLY:-0}"

echo "=== Apps build container starting ==="
echo "GATEWAY_REPO_URL=${GATEWAY_REPO_URL} (branch=${GATEWAY_BRANCH})"
echo "SERVICE_REPO_URL=${SERVICE_REPO_URL} (branch=${SERVICE_BRANCH})"
echo "DOCKER_USERNAME=${DOCKER_USERNAME}"
if [ "${BUILD_GATEWAY_ONLY}" = "1" ]; then
  echo "BUILD MODE: Gateway only"
elif [ "${BUILD_SERVICE_ONLY}" = "1" ]; then
  echo "BUILD MODE: Service only"
else
  echo "BUILD MODE: Both Gateway and Service"
fi

if [[ -z "${DOCKER_USERNAME}" ]]; then
  echo "WARNING: DOCKER_USERNAME not set. Images will be built but may not be pushed." >&2
fi

# Ensure JAVA_HOME is set correctly (in case profile wasn't sourced)
if [ -z "${JAVA_HOME:-}" ] || [ ! -d "${JAVA_HOME}" ]; then
  JAVA_21_HOME=$(update-alternatives --list java 2>/dev/null | grep -i "21" | head -1 | sed 's|/bin/java||')
  if [ -z "$JAVA_21_HOME" ]; then
    JAVA_21_HOME=$(ls -d /usr/lib/jvm/temurin-21-jdk-* 2>/dev/null | head -1)
  fi
  if [ -n "$JAVA_21_HOME" ] && [ -d "$JAVA_21_HOME" ]; then
    export JAVA_HOME="$JAVA_21_HOME"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

# Verify Java 21 is available
echo "Verifying Java 21 installation:"
echo "JAVA_HOME=${JAVA_HOME}"
java -version
# Suppress broken pipe errors from Maven version check (happens in non-interactive environments)
(mvn -version 2>&1 | head -3 | grep -v -E "(Broken pipe|java.io.IOError|Exception in thread)" || true) || true

# Use a persistent maven repo to reduce flaky downloads / corruption.
M2_DIR="${M2_DIR:-/m2}"
mkdir -p "${M2_DIR}/repository"
# Disable ANSI colors and jansi to avoid broken pipe errors in non-interactive environments
export MAVEN_OPTS="${MAVEN_OPTS:-} -Dmaven.repo.local=${M2_DIR}/repository -Dmaven.color=false -Djansi.passthrough=true -Djansi.force=true"

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

  # Clone with full history to get proper git commit info for versioning
  # Use --depth 50 as a compromise between speed and having enough history for versioning
  local args=(clone --depth 50 --branch "${branch}" "${url}" "${dest}")

  # Disable interactive prompts inside the container.
  export GIT_TERMINAL_PROMPT=0

  if [[ -n "${GITHUB_TOKEN}" && "${url}" == https://github.com/* ]]; then
    # Use auth header (preferred over embedding token in URL).
    git -c http.extraHeader="AUTHORIZATION: bearer ${GITHUB_TOKEN}" "${args[@]}"
  else
    git "${args[@]}"
  fi
}

# Generate version from git commit info
generate_version() {
  # Usage: generate_version <repo_dir>
  local repo_dir="$1"
  pushd "${repo_dir}" >/dev/null
  
  # Get git commit hash (short)
  local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  
  # Get git commit count (for version incrementing)
  local commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
  
  # Get branch name
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  
  # Get timestamp
  local timestamp=$(date +%Y%m%d%H%M%S)
  
  # Get commit date
  local commit_date=$(git log -1 --format=%cd --date=format:%Y%m%d 2>/dev/null || echo "$(date +%Y%m%d)")
  
  # Generate version: base-version.commit-count.commit-hash.timestamp
  # Example: 0.0.1.123.abc1234.20260104120000
  local base_version="0.0.1"
  local version="${base_version}.${commit_count}.${commit_hash}.${timestamp}"
  
  # Also create a shorter version for display
  local short_version="${base_version}.${commit_count}-${commit_hash}"
  
  # Export variables for use in parent scope
  export GIT_VERSION="${version}"
  export GIT_SHORT_VERSION="${short_version}"
  export GIT_COMMIT_HASH="${commit_hash}"
  export GIT_COMMIT_COUNT="${commit_count}"
  export GIT_BRANCH="${branch}"
  export GIT_COMMIT_DATE="${commit_date}"
  export BUILD_TIMESTAMP="${timestamp}"
  
  echo "GIT_VERSION=${version}"
  echo "GIT_SHORT_VERSION=${short_version}"
  echo "GIT_COMMIT_HASH=${commit_hash}"
  echo "GIT_COMMIT_COUNT=${commit_count}"
  echo "GIT_BRANCH=${branch}"
  echo "GIT_COMMIT_DATE=${commit_date}"
  echo "BUILD_TIMESTAMP=${timestamp}"
  
  popd >/dev/null
}

# Note: Jib handles Docker Hub authentication via -Ddocker.password
# No need to run docker login separately

# Build Gateway (if not service-only)
if [[ "${BUILD_SERVICE_ONLY}" != "1" ]]; then
  echo "=== Building Gateway (rms) ==="
  gateway_dir="${tmp}/rms"
  git_clone "${GATEWAY_REPO_URL}" "${GATEWAY_BRANCH}" "${gateway_dir}"
  
  # Generate version info from git
  echo "=== Generating Gateway Version Info ==="
  eval $(generate_version "${gateway_dir}")
  echo "Gateway Version: ${GIT_SHORT_VERSION}"
  echo "Gateway Full Version: ${GIT_VERSION}"
  echo "Gateway Commit: ${GIT_COMMIT_HASH} (${GIT_COMMIT_COUNT} commits)"
  echo "Gateway Branch: ${GIT_BRANCH}"
  echo "Gateway Commit Date: ${GIT_COMMIT_DATE}"
  
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
  echo "Building and pushing gateway Docker image with version ${GIT_SHORT_VERSION}..."
  # Override maven-compiler-plugin version to ensure Java 21 support (3.11.0+ supports Java 21)
  # Also set compiler properties explicitly
  # Pass git version info as Maven properties for use in application
  # Filter broken pipe errors from output
  set +e
  if [[ -n "${DOCKER_USERNAME}" ]]; then
    ${MVN_CMD} clean package jib:build \
      -Dmaven.compiler.release=21 \
      -Dmaven.compiler.source=21 \
      -Dmaven.compiler.target=21 \
      -Dmaven.compiler-plugin.version=3.13.0 \
      -Djansi.passthrough=true \
      -Dmaven.color=false \
      -Dbuild.version="${GIT_VERSION}" \
      -Dbuild.short.version="${GIT_SHORT_VERSION}" \
      -Dbuild.commit.hash="${GIT_COMMIT_HASH}" \
      -Dbuild.commit.count="${GIT_COMMIT_COUNT}" \
      -Dbuild.branch="${GIT_BRANCH}" \
      -Dbuild.timestamp="${BUILD_TIMESTAMP}" \
      -Ddocker.username="${DOCKER_USERNAME}" \
      -Ddocker.password="${DOCKER_PASSWORD}" 2>&1 | grep -v -E "(Broken pipe|java.io.IOError|Exception in thread)" || true
    MVN_EXIT_CODE=${PIPESTATUS[0]}
  else
    ${MVN_CMD} clean package jib:build \
      -Dmaven.compiler.release=21 \
      -Dmaven.compiler.source=21 \
      -Dmaven.compiler.target=21 \
      -Dmaven.compiler-plugin.version=3.13.0 \
      -Djansi.passthrough=true \
      -Dmaven.color=false \
      -Dbuild.version="${GIT_VERSION}" \
      -Dbuild.short.version="${GIT_SHORT_VERSION}" \
      -Dbuild.commit.hash="${GIT_COMMIT_HASH}" \
      -Dbuild.commit.count="${GIT_COMMIT_COUNT}" \
      -Dbuild.branch="${GIT_BRANCH}" \
      -Dbuild.timestamp="${BUILD_TIMESTAMP}" \
      -Ddocker.password="${DOCKER_PASSWORD}" 2>&1 | grep -v -E "(Broken pipe|java.io.IOError|Exception in thread)" || true
    MVN_EXIT_CODE=${PIPESTATUS[0]}
  fi
  set -e

  # Check if build actually succeeded (ignore broken pipe errors)
  if [[ $MVN_EXIT_CODE -ne 0 ]]; then
    echo "ERROR: Gateway build failed (exit code: $MVN_EXIT_CODE)!" >&2
    exit 1
  fi

  echo "Gateway image built and pushed successfully"
  popd >/dev/null
fi

# Build Service (if not gateway-only)
if [[ "${BUILD_GATEWAY_ONLY}" != "1" ]]; then
  echo "=== Building Service (rms-service) ==="
  service_dir="${tmp}/rms-service"
  git_clone "${SERVICE_REPO_URL}" "${SERVICE_BRANCH}" "${service_dir}"
  
  # Generate version info from git
  echo "=== Generating Service Version Info ==="
  eval $(generate_version "${service_dir}")
  echo "Service Version: ${GIT_SHORT_VERSION}"
  echo "Service Full Version: ${GIT_VERSION}"
  echo "Service Commit: ${GIT_COMMIT_HASH} (${GIT_COMMIT_COUNT} commits)"
  echo "Service Branch: ${GIT_BRANCH}"
  echo "Service Commit Date: ${GIT_COMMIT_DATE}"
  
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
  echo "Building and pushing service Docker image with version ${GIT_SHORT_VERSION}..."
  # Override maven-compiler-plugin version to ensure Java 21 support (3.11.0+ supports Java 21)
  # Also set compiler properties explicitly
  # Pass git version info as Maven properties for use in application
  # Filter broken pipe errors from output
  set +e
  if [[ -n "${DOCKER_USERNAME}" ]]; then
    ${MVN_CMD} clean package jib:build \
      -Dmaven.compiler.release=21 \
      -Dmaven.compiler.source=21 \
      -Dmaven.compiler.target=21 \
      -Dmaven.compiler-plugin.version=3.13.0 \
      -Djansi.passthrough=true \
      -Dmaven.color=false \
      -Dbuild.version="${GIT_VERSION}" \
      -Dbuild.short.version="${GIT_SHORT_VERSION}" \
      -Dbuild.commit.hash="${GIT_COMMIT_HASH}" \
      -Dbuild.commit.count="${GIT_COMMIT_COUNT}" \
      -Dbuild.branch="${GIT_BRANCH}" \
      -Dbuild.timestamp="${BUILD_TIMESTAMP}" \
      -Ddocker.username="${DOCKER_USERNAME}" \
      -Ddocker.password="${DOCKER_PASSWORD}" 2>&1 | grep -v -E "(Broken pipe|java.io.IOError|Exception in thread)" || true
    MVN_EXIT_CODE=${PIPESTATUS[0]}
  else
    ${MVN_CMD} clean package jib:build \
      -Dmaven.compiler.release=21 \
      -Dmaven.compiler.source=21 \
      -Dmaven.compiler.target=21 \
      -Dmaven.compiler-plugin.version=3.13.0 \
      -Djansi.passthrough=true \
      -Dmaven.color=false \
      -Dbuild.version="${GIT_VERSION}" \
      -Dbuild.short.version="${GIT_SHORT_VERSION}" \
      -Dbuild.commit.hash="${GIT_COMMIT_HASH}" \
      -Dbuild.commit.count="${GIT_COMMIT_COUNT}" \
      -Dbuild.branch="${GIT_BRANCH}" \
      -Dbuild.timestamp="${BUILD_TIMESTAMP}" \
      -Ddocker.password="${DOCKER_PASSWORD}" 2>&1 | grep -v -E "(Broken pipe|java.io.IOError|Exception in thread)" || true
    MVN_EXIT_CODE=${PIPESTATUS[0]}
  fi
  set -e

  # Check if build actually succeeded (ignore broken pipe errors)
  if [[ $MVN_EXIT_CODE -ne 0 ]]; then
    echo "ERROR: Service build failed (exit code: $MVN_EXIT_CODE)!" >&2
    exit 1
  fi

  echo "Service image built and pushed successfully"
  popd >/dev/null
fi

echo "=== Apps build container done ==="

