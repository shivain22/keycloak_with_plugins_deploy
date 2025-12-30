#!/usr/bin/env bash
set -euo pipefail

# One-shot build container that:
# - cleans /work/providers
# - clones and builds keycloak-phone-provider (maven)
# - clones and builds rms-keycloakify-theme (npm/yarn/pnpm + keycloakify which shells out to mvn)
# - copies required jars into /work/providers
#
# Expected volume mounts:
# - /work/providers  -> bind mount to repo ./providers (shared with keycloak)
# - /m2             -> optional maven cache volume (improves reliability/speed)

PROVIDERS_DIR="${PROVIDERS_DIR:-/work/providers}"
M2_DIR="${M2_DIR:-/m2}"

PHONE_PROVIDER_REPO_URL="${PHONE_PROVIDER_REPO_URL:-https://github.com/shivain22/keycloak-phone-provider.git}"
PHONE_PROVIDER_BRANCH="${PHONE_PROVIDER_BRANCH:-master}"

THEME_REPO_URL="${THEME_REPO_URL:-https://github.com/shivain22/rms-keycloakify-theme.git}"
THEME_BRANCH="${THEME_BRANCH:-main}"
THEME_JAR_NAME="${THEME_JAR_NAME:-keycloak-theme-for-kc-all-other-versions.jar}"

# Optional: for private repos / corporate GitHub setups, provide a token.
# - Pass via compose env: GITHUB_TOKEN=...
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

echo "=== Build container starting ==="
echo "PROVIDERS_DIR=${PROVIDERS_DIR}"
echo "PHONE_PROVIDER_REPO_URL=${PHONE_PROVIDER_REPO_URL} (branch=${PHONE_PROVIDER_BRANCH})"
echo "THEME_REPO_URL=${THEME_REPO_URL} (branch=${THEME_BRANCH})"
echo "THEME_JAR_NAME=${THEME_JAR_NAME}"

mkdir -p "${PROVIDERS_DIR}"

echo "Cleaning providers dir..."
rm -rf "${PROVIDERS_DIR:?}/"*

# Use a persistent maven repo to reduce flaky downloads / corruption.
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

echo "=== Building keycloak-phone-provider ==="
pp_dir="${tmp}/keycloak-phone-provider"
git_clone "${PHONE_PROVIDER_REPO_URL}" "${PHONE_PROVIDER_BRANCH}" "${pp_dir}"
pushd "${pp_dir}" >/dev/null
mvn -B -ntp clean install -DskipTests
popd >/dev/null

if [[ ! -f "${pp_dir}/target/providers/keycloak-phone-provider.jar" ]]; then
  echo "ERROR: Missing keycloak-phone-provider.jar in ${pp_dir}/target/providers" >&2
  exit 1
fi
if [[ ! -f "${pp_dir}/target/providers/keycloak-phone-provider-msg91.jar" ]]; then
  echo "ERROR: Missing keycloak-phone-provider-msg91.jar in ${pp_dir}/target/providers" >&2
  exit 1
fi

cp -f "${pp_dir}/target/providers/keycloak-phone-provider.jar" "${PROVIDERS_DIR}/"
cp -f "${pp_dir}/target/providers/keycloak-phone-provider-msg91.jar" "${PROVIDERS_DIR}/"

echo "=== Building rms-keycloakify-theme (Keycloakify theme) ==="
theme_dir="${tmp}/rms-keycloakify-theme"
git_clone "${THEME_REPO_URL}" "${THEME_BRANCH}" "${theme_dir}"
pushd "${theme_dir}" >/dev/null

# Detect and use appropriate package manager
if [[ -f pnpm-lock.yaml ]] && command -v pnpm >/dev/null 2>&1; then
  echo "Using pnpm..."
  pnpm install --no-frozen-lockfile || npm install --no-fund --no-audit
elif [[ -f yarn.lock ]] && command -v yarn >/dev/null 2>&1; then
  echo "Using yarn..."
  yarn install --no-frozen-lockfile || npm install --no-fund --no-audit
elif [[ -f package-lock.json ]]; then
  echo "Using npm (package-lock.json found)..."
  npm ci --no-fund --no-audit
else
  echo "Using npm (default)..."
  npm install --no-fund --no-audit
fi

# Build keycloak theme jars
npm run build-keycloak-theme

# Check if specific theme jar exists, otherwise copy all theme jars
if [[ -f "dist_keycloak/${THEME_JAR_NAME}" ]]; then
  echo "Found specific theme jar: ${THEME_JAR_NAME}"
  cp -f "dist_keycloak/${THEME_JAR_NAME}" "${PROVIDERS_DIR}/"
else
  echo "WARNING: Expected theme jar '${THEME_JAR_NAME}' not found. Copying all theme jars..."
  echo "Available theme jars in dist_keycloak:"
  ls -1 dist_keycloak/*.jar 2>/dev/null || true
  
  # Copy all theme jars (Keycloakify generates multiple jars for different versions)
  if ls dist_keycloak/*.jar 1> /dev/null 2>&1; then
    cp -f dist_keycloak/*.jar "${PROVIDERS_DIR}/"
    echo "✅ Copied all theme jars to providers directory"
  else
    echo "ERROR: No theme jars found in dist_keycloak/" >&2
    exit 1
  fi
fi
popd >/dev/null

echo "=== Verifying required files in providers ==="
ls -1 "${PROVIDERS_DIR}" || true
test -f "${PROVIDERS_DIR}/keycloak-phone-provider.jar"
test -f "${PROVIDERS_DIR}/keycloak-phone-provider-msg91.jar"

# Verify at least one theme jar exists (may be different name than expected)
if ! ls "${PROVIDERS_DIR}"/keycloak-theme-*.jar 1> /dev/null 2>&1; then
  echo "ERROR: No theme jar found in providers directory" >&2
  exit 1
fi
echo "✅ Theme jar(s) found in providers directory"

echo "=== Build container done ==="


