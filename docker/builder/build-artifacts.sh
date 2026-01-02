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
# Suppress broken pipe errors from Maven version check (happens in non-interactive environments)
(mvn -version 2>&1 | head -3 | grep -v -E "(Broken pipe|java.io.IOError|Exception in thread)" || true) || true

mkdir -p "${PROVIDERS_DIR}"

echo "Cleaning providers dir..."
rm -rf "${PROVIDERS_DIR:?}/"*

# Use a persistent maven repo to reduce flaky downloads / corruption.
mkdir -p "${M2_DIR}/repository"
# Disable ANSI colors and jansi completely to avoid broken pipe errors in non-interactive environments
# Use MAVEN_OPTS to disable jansi and colors
export MAVEN_OPTS="${MAVEN_OPTS:-} -Dmaven.repo.local=${M2_DIR}/repository -Dmaven.color=false -Djansi.passthrough=true -Djansi.force=true -Dmaven.wagon.http.ssl.insecure=true"
# Also set as system property for Maven wrapper if used
export _JAVA_OPTIONS="${_JAVA_OPTIONS:-} -Djansi.passthrough=true"

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

# The project uses maven-compiler-plugin:3.1 which doesn't support Java 21
# This is a multi-module project, so we need to patch the parent pom.xml
echo "Patching pom.xml files to use maven-compiler-plugin 3.13.0 for Java 21 support..."

# Patch parent pom.xml
if [[ -f "pom.xml" ]]; then
  cp pom.xml pom.xml.backup
  echo "Patching parent pom.xml..."
  
  # Update Java version properties (handle various formats)
  sed -i 's/<maven\.compiler\.source>17<\/maven\.compiler\.source>/<maven.compiler.release>21<\/maven.compiler.release>\n        <maven.compiler.source>21<\/maven.compiler.source>/g' pom.xml
  sed -i 's/<maven\.compiler\.target>17<\/maven\.compiler\.target>/<maven.compiler.target>21<\/maven.compiler.target>/g' pom.xml
  sed -i 's/<java\.version>17<\/java\.version>/<java.version>21<\/java.version>/g' pom.xml
  
  # Add or update maven-compiler-plugin version property
  if ! grep -q "maven.compiler-plugin.version" pom.xml; then
    # Insert after java.version property
    sed -i '/<java\.version>/a\        <maven.compiler-plugin.version>3.13.0<\/maven.compiler-plugin.version>' pom.xml
  else
    sed -i 's/\(<maven\.compiler\.plugin\.version>\)[0-9.]\+\(<\/maven\.compiler\.plugin\.version>\)/\13.13.0\2/g' pom.xml
  fi
  
  # Replace any maven-compiler-plugin version 3.1 with 3.13.0
  # Handle both pluginManagement and direct plugin declarations
  # First, try to find and replace in the context of maven-compiler-plugin
  sed -i '/<artifactId>maven-compiler-plugin<\/artifactId>/,/<version>/s/<version>3\.1<\/version>/<version>3.13.0<\/version>/' pom.xml
  
  # Also replace any standalone version 3.1 (more aggressive, but should be safe)
  # Only replace if it's in a plugin section with maven-compiler-plugin
  sed -i 's/\(<artifactId>maven-compiler-plugin<\/artifactId>.*<version>\)3\.1\(<\/version>\)/\13.13.0\2/g' pom.xml
  
  # Ensure maven-compiler-plugin is explicitly configured in build/plugins section
  # This overrides any version from parent POMs
  if ! grep -A 10 "<build>" pom.xml | grep -q "maven-compiler-plugin"; then
    echo "Adding maven-compiler-plugin to build/plugins section..."
    # Insert after <plugins> tag in <build> section
    sed -i '/<build>/,/<\/build>/{
      /<plugins>/a\
            <plugin>\
                <groupId>org.apache.maven.plugins</groupId>\
                <artifactId>maven-compiler-plugin</artifactId>\
                <version>3.13.0</version>\
                <configuration>\
                    <release>21</release>\
                </configuration>\
            </plugin>
    }' pom.xml
  fi
  
  echo "Parent pom.xml patched"
fi

# Patch child module pom.xml files
for child_pom in keycloak-phone-provider/pom.xml keycloak-phone-provider-msg91/pom.xml; do
  if [[ -f "$child_pom" ]]; then
    cp "$child_pom" "${child_pom}.backup"
    # Update Java version properties in child modules
    sed -i 's/<maven\.compiler\.source>17<\/maven\.compiler\.source>/<maven.compiler.release>21<\/maven.compiler.release>\n        <maven.compiler.source>21<\/maven.compiler.source>/g' "$child_pom"
    sed -i 's/<maven\.compiler\.target>17<\/maven\.compiler\.target>/<maven.compiler.target>21<\/maven.compiler.target>/g' "$child_pom"
  fi
done

# Build with Java 21 - override compiler settings
# Redirect stderr to filter broken pipe errors, but keep stdout for build output
BUILD_SUCCESS=false
if mvn -B -ntp clean install -DskipTests \
  -Dmaven.compiler.release=21 \
  -Dmaven.compiler.source=21 \
  -Dmaven.compiler.target=21 \
  -Dmaven.compiler-plugin.version=3.13.0 \
  -Djansi.passthrough=true \
  -Dmaven.color=false 2>&1 | grep -v -E "(Broken pipe|java.io.IOError|Exception in thread)"; then
  BUILD_SUCCESS=true
fi

# Check if JAR was actually built (check in the module directory)
if [[ -f "keycloak-phone-provider/target/providers/keycloak-phone-provider.jar" ]] || [[ -f "target/providers/keycloak-phone-provider.jar" ]]; then
  BUILD_SUCCESS=true
fi

# Restore backups
if [[ -f "pom.xml.backup" ]]; then
  mv pom.xml.backup pom.xml
fi
for child_pom in keycloak-phone-provider/pom.xml keycloak-phone-provider-msg91/pom.xml; do
  if [[ -f "${child_pom}.backup" ]]; then
    mv "${child_pom}.backup" "$child_pom"
  fi
done

# Check build result
if [[ "$BUILD_SUCCESS" == "false" ]]; then
  # Check for JAR in both possible locations
  if [[ ! -f "keycloak-phone-provider/target/providers/keycloak-phone-provider.jar" ]] && [[ ! -f "target/providers/keycloak-phone-provider.jar" ]]; then
    echo "ERROR: Maven build failed and no JAR was produced" >&2
    exit 1
  fi
fi

popd >/dev/null

# Check for JARs in possible locations (multi-module project structure)
PHONE_PROVIDER_JAR=""
MSG91_PROVIDER_JAR=""

if [[ -f "${pp_dir}/keycloak-phone-provider/target/providers/keycloak-phone-provider.jar" ]]; then
  PHONE_PROVIDER_JAR="${pp_dir}/keycloak-phone-provider/target/providers/keycloak-phone-provider.jar"
elif [[ -f "${pp_dir}/target/providers/keycloak-phone-provider.jar" ]]; then
  PHONE_PROVIDER_JAR="${pp_dir}/target/providers/keycloak-phone-provider.jar"
fi

if [[ -f "${pp_dir}/keycloak-phone-provider-msg91/target/providers/keycloak-phone-provider-msg91.jar" ]]; then
  MSG91_PROVIDER_JAR="${pp_dir}/keycloak-phone-provider-msg91/target/providers/keycloak-phone-provider-msg91.jar"
elif [[ -f "${pp_dir}/target/providers/keycloak-phone-provider-msg91.jar" ]]; then
  MSG91_PROVIDER_JAR="${pp_dir}/target/providers/keycloak-phone-provider-msg91.jar"
fi

if [[ -z "$PHONE_PROVIDER_JAR" ]] || [[ ! -f "$PHONE_PROVIDER_JAR" ]]; then
  echo "ERROR: Missing keycloak-phone-provider.jar" >&2
  echo "Searched in:" >&2
  echo "  ${pp_dir}/keycloak-phone-provider/target/providers/" >&2
  echo "  ${pp_dir}/target/providers/" >&2
  exit 1
fi

if [[ -z "$MSG91_PROVIDER_JAR" ]] || [[ ! -f "$MSG91_PROVIDER_JAR" ]]; then
  echo "ERROR: Missing keycloak-phone-provider-msg91.jar" >&2
  echo "Searched in:" >&2
  echo "  ${pp_dir}/keycloak-phone-provider-msg91/target/providers/" >&2
  echo "  ${pp_dir}/target/providers/" >&2
  exit 1
fi

cp -f "$PHONE_PROVIDER_JAR" "${PROVIDERS_DIR}/"
cp -f "$MSG91_PROVIDER_JAR" "${PROVIDERS_DIR}/"

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


