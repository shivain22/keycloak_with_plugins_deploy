#!/usr/bin/env bash
set -euo pipefail

# One-shot build container that:
# - cleans /work/providers
# - clones and builds keycloak-phone-provider (maven)
# - clones and builds rms-auth-theme-plugin (npm + keycloakify which shells out to mvn)
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
THEME_JAR_NAME="${THEME_JAR_NAME:-keycloak-theme-for-kc-26.2-and-above.jar}"

# Optional: for private repos / corporate GitHub setups, provide a token.
# - Pass via compose env: GITHUB_TOKEN=...
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

echo "=== Build container starting ==="
echo "PROVIDERS_DIR=${PROVIDERS_DIR}"
echo "PHONE_PROVIDER_REPO_URL=${PHONE_PROVIDER_REPO_URL} (branch=${PHONE_PROVIDER_BRANCH})"
echo "THEME_REPO_URL=${THEME_REPO_URL} (branch=${THEME_BRANCH})"
echo "THEME_JAR_NAME=${THEME_JAR_NAME}"

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
mvn -version | head -3

mkdir -p "${PROVIDERS_DIR}"

echo "Cleaning providers dir..."
rm -rf "${PROVIDERS_DIR:?}/"*

# Use a persistent maven repo to reduce flaky downloads / corruption.
mkdir -p "${M2_DIR}/repository"
# Disable ANSI colors and jansi to avoid broken pipe errors in non-interactive environments
# jansi.passthrough=true makes jansi pass through output without processing, preventing broken pipe errors
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
# Build with Java 21 - override compiler settings if needed
# Capture exit code separately to handle broken pipe errors
set +e
mvn -B -ntp clean install -DskipTests \
  -Dmaven.compiler.release=21 \
  -Dmaven.compiler.source=21 \
  -Dmaven.compiler.target=21 \
  -Dmaven.compiler-plugin.version=3.13.0 2>&1 | grep -v -E "(Broken pipe|java.io.IOError)" || true
MVN_EXIT_CODE=${PIPESTATUS[0]}
set -e

# Check if build actually succeeded (ignore broken pipe errors if JAR exists)
if [[ $MVN_EXIT_CODE -ne 0 ]]; then
  if [[ ! -f "target/providers/keycloak-phone-provider.jar" ]]; then
    echo "ERROR: Maven build failed (exit code: $MVN_EXIT_CODE) and no JAR was produced" >&2
    exit 1
  else
    echo "WARNING: Maven reported exit code $MVN_EXIT_CODE but JAR was built successfully (likely broken pipe error)"
  fi
fi
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

echo "=== Building rms-auth-theme-plugin (Keycloakify theme) ==="
echo "Using Java 21 for theme build (keycloakify will use Maven internally)"
theme_dir="${tmp}/rms-auth-theme-plugin"
git_clone "${THEME_REPO_URL}" "${THEME_BRANCH}" "${theme_dir}"
pushd "${theme_dir}" >/dev/null

if [[ -f package-lock.json ]]; then
  npm ci --no-fund --no-audit
else
  npm install --no-fund --no-audit
fi

# Build keycloak theme jars (keycloakify uses Maven with Java 21)
# Ensure Maven uses Java 21 compiler settings
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.compiler.release=21"
npm run build-keycloak-theme

if [[ ! -f "dist_keycloak/${THEME_JAR_NAME}" ]]; then
  echo "ERROR: Missing theme jar dist_keycloak/${THEME_JAR_NAME}" >&2
  echo "dist_keycloak contents:" >&2
  ls -1 dist_keycloak >&2 || true
  exit 1
fi

cp -f "dist_keycloak/${THEME_JAR_NAME}" "${PROVIDERS_DIR}/"
popd >/dev/null

echo "=== Verifying required files in providers ==="
ls -1 "${PROVIDERS_DIR}" || true
test -f "${PROVIDERS_DIR}/keycloak-phone-provider.jar"
test -f "${PROVIDERS_DIR}/keycloak-phone-provider-msg91.jar"
test -f "${PROVIDERS_DIR}/${THEME_JAR_NAME}"

echo "=== Build container done ==="


