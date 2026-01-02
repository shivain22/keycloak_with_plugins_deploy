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

# Patch parent pom.xml - use a more reliable approach
if [[ -f "pom.xml" ]]; then
  cp pom.xml pom.xml.backup
  echo "Patching parent pom.xml..."
  
  # Create a temporary file with the plugin configuration
  cat > /tmp/maven-compiler-plugin.xml << 'PLUGIN_XML'
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.13.0</version>
                <configuration>
                    <release>21</release>
                </configuration>
            </plugin>
PLUGIN_XML
  
  # Update Java version properties
  sed -i 's/<maven\.compiler\.source>17<\/maven\.compiler\.source>/<maven.compiler.release>21<\/maven.compiler.release>\n        <maven.compiler.source>21<\/maven.compiler.source>/g' pom.xml
  sed -i 's/<maven\.compiler\.target>17<\/maven\.compiler\.target>/<maven.compiler.target>21<\/maven.compiler.target>/g' pom.xml
  sed -i 's/<java\.version>17<\/java\.version>/<java.version>21<\/java.version>/g' pom.xml
  
  # Add maven-compiler-plugin version property
  if ! grep -q "maven.compiler-plugin.version" pom.xml; then
    sed -i '/<java\.version>/a\        <maven.compiler-plugin.version>3.13.0<\/maven.compiler-plugin.version>' pom.xml
  else
    sed -i 's/\(<maven\.compiler\.plugin\.version>\)[0-9.]\+\(<\/maven\.compiler\.plugin\.version>\)/\13.13.0\2/g' pom.xml
  fi
  
  # Replace ALL occurrences of version 3.1 with 3.13.0 (handle whitespace variations)
  # This is safe because 3.1 is very old and only used by maven-compiler-plugin in this project
  sed -i 's/<version>3\.1<\/version>/<version>3.13.0<\/version>/g' pom.xml
  sed -i 's/<version>3\.1<\/version>/<version>3.13.0<\/version>/g' pom.xml  # Handle different whitespace
  sed -i 's/<version>3\.1<\/version>/<version>3.13.0<\/version>/g' pom.xml  # Handle tabs
  
  # Also replace in child modules (exclude backup files)
  find . -name "pom.xml" -type f ! -name "*.backup" -exec sed -i 's/<version>3\.1<\/version>/<version>3.13.0<\/version>/g' {} \;
  find . -name "pom.xml" -type f ! -name "*.backup" -exec sed -i 's/<version>3\.1<\/version>/<version>3.13.0<\/version>/g' {} \;
  
  # Ensure maven-compiler-plugin is in build/plugins section (overrides parent)
  if ! grep -A 20 "<build>" pom.xml | grep -q "maven-compiler-plugin"; then
    echo "Adding maven-compiler-plugin to build/plugins section..."
    # Find the <plugins> tag in <build> section and insert after it
    awk '/<build>/,/<\/build>/ {
      if (/<plugins>/) {
        print
        while ((getline line < "/tmp/maven-compiler-plugin.xml") > 0) print line
        close("/tmp/maven-compiler-plugin.xml")
        next
      }
    }
    { print }' pom.xml > pom.xml.tmp && mv pom.xml.tmp pom.xml
  else
    # Update existing maven-compiler-plugin version
    sed -i '/<artifactId>maven-compiler-plugin<\/artifactId>/,/<version>/s/<version>[0-9.]\+<\/version>/<version>3.13.0<\/version>/' pom.xml
  fi
  
  rm -f /tmp/maven-compiler-plugin.xml
  
  # Verify the patch - check what version is now in the file
  echo "Verifying patch..."
  if grep -q "maven-compiler-plugin" pom.xml; then
    echo "maven-compiler-plugin configuration found:"
    grep -A 5 "maven-compiler-plugin" pom.xml | head -10 || true
  fi
  
  # Double-check: if version 3.1 still exists anywhere, replace it
  if grep -q "<version>3\.1</version>" pom.xml; then
    echo "WARNING: Version 3.1 still found, doing final replacement..." >&2
    sed -i 's/<version>3\.1<\/version>/<version>3.13.0<\/version>/g' pom.xml
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

# Create .mvn/maven.config to force plugin version (most reliable override)
# Note: This might not work for plugin versions, but helps with compiler settings
mkdir -p .mvn
echo "-Dmaven.compiler.release=21" > .mvn/maven.config

# Create toolchains.xml to satisfy maven-toolchains-plugin requirement
# The parent POM has a profile that activates when this file exists
mkdir -p ~/.m2
TOOLCHAINS_HOME="${JAVA_HOME}"
if [[ -z "$TOOLCHAINS_HOME" ]] || [[ ! -d "$TOOLCHAINS_HOME" ]]; then
  # Try to find Java 21 installation
  TOOLCHAINS_HOME=$(ls -d /usr/lib/jvm/temurin-21-jdk-* 2>/dev/null | head -1)
  if [[ -z "$TOOLCHAINS_HOME" ]] || [[ ! -d "$TOOLCHAINS_HOME" ]]; then
    TOOLCHAINS_HOME="/usr/lib/jvm/temurin-21-jdk-amd64"
  fi
fi

# Verify Java 21 exists
if [[ ! -d "$TOOLCHAINS_HOME" ]]; then
  echo "ERROR: Java 21 installation not found at: ${TOOLCHAINS_HOME}" >&2
  echo "Available Java installations:" >&2
  ls -d /usr/lib/jvm/* 2>/dev/null | head -5 >&2 || echo "  (none found)" >&2
  exit 1
fi

# Create toolchains.xml with actual resolved path
cat > ~/.m2/toolchains.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<toolchains>
    <toolchain>
        <type>jdk</type>
        <provides>
            <version>21</version>
        </provides>
        <configuration>
            <jdkHome>${TOOLCHAINS_HOME}</jdkHome>
        </configuration>
    </toolchain>
</toolchains>
EOF
echo "Created toolchains.xml pointing to: ${TOOLCHAINS_HOME}"

# Before building, verify the patch worked
echo "Checking pom.xml for maven-compiler-plugin version..."
if grep -q "maven-compiler-plugin" pom.xml; then
  VERSION_FOUND=$(grep -A 3 "maven-compiler-plugin" pom.xml | grep "<version>" | head -1 | sed 's/.*<version>\([^<]*\)<\/version>.*/\1/')
  echo "Found maven-compiler-plugin version: ${VERSION_FOUND:-not found}"
  if [[ "$VERSION_FOUND" == "3.1" ]]; then
    echo "ERROR: Version 3.1 still present after patching! Attempting emergency fix..." >&2
    # Emergency: replace ALL 3.1 in version tags
    sed -i 's/\(<version>\)3\.1\(<\/version>\)/\13.13.0\2/g' pom.xml
    # Also in child modules
    find . -name "pom.xml" -exec sed -i 's/\(<version>\)3\.1\(<\/version>\)/\13.13.0\2/g' {} \;
  fi
fi

# Build with Java 21 - override compiler settings
# Use explicit plugin version override in the command
# Redirect stderr to filter broken pipe errors, but keep stdout for build output
BUILD_SUCCESS=false
if mvn -B -ntp clean install -DskipTests \
  -Dmaven.compiler.release=21 \
  -Dmaven.compiler.source=21 \
  -Dmaven.compiler.target=21 \
  -Dmaven.compiler-plugin.version=3.13.0 \
  -Dplugin.version=3.13.0 \
  -Dorg.apache.maven.plugins.compiler.version=3.13.0 \
  -Djansi.passthrough=true \
  -Dmaven.color=false \
  -Dorg.apache.maven.plugins:maven-compiler-plugin:version=3.13.0 2>&1 | grep -v -E "(Broken pipe|java.io.IOError|Exception in thread)"; then
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

# Note: keycloakify may generate different JAR names based on version detection
# We'll handle this by using the appropriate JAR that works for Keycloak 26.2+

# Build keycloak theme jars (keycloakify uses Maven with Java 21)
# Ensure Maven uses Java 21 compiler settings
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.compiler.release=21"

# Verify Node and npm versions
echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"

# Verify Java 21 is being used
echo "Java version: $(java -version 2>&1 | head -1)"
echo "JAVA_HOME: ${JAVA_HOME}"

echo "Building keycloak theme with keycloakify..."
if ! npm run build-keycloak-theme; then
  echo "ERROR: Theme build failed!" >&2
  exit 1
fi

# Restore vite.config.ts if we patched it
if [[ -f "vite.config.ts.backup" ]]; then
  mv vite.config.ts.backup vite.config.ts
fi

# Check what JARs were generated
echo "Generated theme JARs in dist_keycloak:"
ls -lh dist_keycloak/*.jar 2>/dev/null || {
  echo "ERROR: No JAR files found in dist_keycloak/" >&2
  exit 1
}

# Check if the expected JAR exists
if [[ -f "dist_keycloak/${THEME_JAR_NAME}" ]]; then
  JAR_SIZE=$(stat -f%z "dist_keycloak/${THEME_JAR_NAME}" 2>/dev/null || stat -c%s "dist_keycloak/${THEME_JAR_NAME}" 2>/dev/null || echo "unknown")
  echo "Found expected theme jar: ${THEME_JAR_NAME} (size: ${JAR_SIZE} bytes)"
  
  # Verify JAR contains required files before copying
  echo "Verifying JAR structure..."
  if ! jar -tf "dist_keycloak/${THEME_JAR_NAME}" | grep -q "META-INF/keycloak-themes.json"; then
    echo "ERROR: JAR missing keycloak-themes.json!" >&2
    exit 1
  fi
  if ! jar -tf "dist_keycloak/${THEME_JAR_NAME}" | grep -q "login.ftl"; then
    echo "ERROR: JAR missing login.ftl template!" >&2
    exit 1
  fi
  
  # Copy to providers directory
  cp -f "dist_keycloak/${THEME_JAR_NAME}" "${PROVIDERS_DIR}/"
  
  # Verify copy succeeded and check size
  if [[ -f "${PROVIDERS_DIR}/${THEME_JAR_NAME}" ]]; then
    COPIED_SIZE=$(stat -f%z "${PROVIDERS_DIR}/${THEME_JAR_NAME}" 2>/dev/null || stat -c%s "${PROVIDERS_DIR}/${THEME_JAR_NAME}" 2>/dev/null || echo "unknown")
    echo "✓ Copied ${THEME_JAR_NAME} to providers (size: ${COPIED_SIZE} bytes)"
    if [[ "$JAR_SIZE" != "unknown" ]] && [[ "$COPIED_SIZE" != "unknown" ]] && [[ "$JAR_SIZE" != "$COPIED_SIZE" ]]; then
      echo "WARNING: JAR size mismatch! Original: ${JAR_SIZE}, Copied: ${COPIED_SIZE}" >&2
    fi
  else
    echo "ERROR: Failed to copy JAR to providers directory!" >&2
    exit 1
  fi
else
  echo "WARNING: Expected theme jar '${THEME_JAR_NAME}' not found."
  echo "Available JARs:"
  ls -lh dist_keycloak/*.jar
  
  # Keycloakify generates different JARs based on environment/version detection
  # Priority: 26.2-and-above > all-other-versions > any other JAR
  # The "all-other-versions" jar works for Keycloak 26.2+ and is a safe fallback
  THEME_JAR_TO_USE=""
  
  if [[ -f "dist_keycloak/keycloak-theme-for-kc-26.2-and-above.jar" ]]; then
    THEME_JAR_TO_USE="dist_keycloak/keycloak-theme-for-kc-26.2-and-above.jar"
    echo "Found keycloak-theme-for-kc-26.2-and-above.jar"
  elif [[ -f "dist_keycloak/keycloak-theme-for-kc-all-other-versions.jar" ]]; then
    THEME_JAR_TO_USE="dist_keycloak/keycloak-theme-for-kc-all-other-versions.jar"
    echo "Using keycloak-theme-for-kc-all-other-versions.jar (compatible with KC 26.2+)"
  else
    # Use the first available JAR
    THEME_JAR_TO_USE=$(ls -1 dist_keycloak/*.jar | head -1)
    if [[ -n "$THEME_JAR_TO_USE" ]]; then
      echo "Using available JAR: $(basename "$THEME_JAR_TO_USE")"
    else
      echo "ERROR: No theme JAR files found in dist_keycloak/" >&2
      exit 1
    fi
  fi
  
  # Verify JAR before copying
  if [[ -n "$THEME_JAR_TO_USE" ]] && [[ -f "$THEME_JAR_TO_USE" ]]; then
    JAR_SIZE=$(stat -f%z "$THEME_JAR_TO_USE" 2>/dev/null || stat -c%s "$THEME_JAR_TO_USE" 2>/dev/null || echo "unknown")
    echo "Verifying JAR structure for $(basename "$THEME_JAR_TO_USE") (size: ${JAR_SIZE} bytes)..."
    
    if ! jar -tf "$THEME_JAR_TO_USE" | grep -q "META-INF/keycloak-themes.json"; then
      echo "ERROR: JAR missing keycloak-themes.json!" >&2
      exit 1
    fi
    if ! jar -tf "$THEME_JAR_TO_USE" | grep -q "login.ftl"; then
      echo "ERROR: JAR missing login.ftl template!" >&2
      exit 1
    fi
    
    # Copy the selected JAR with the expected name
    cp -f "$THEME_JAR_TO_USE" "${PROVIDERS_DIR}/${THEME_JAR_NAME}"
    
    # Verify copy
    if [[ -f "${PROVIDERS_DIR}/${THEME_JAR_NAME}" ]]; then
      COPIED_SIZE=$(stat -f%z "${PROVIDERS_DIR}/${THEME_JAR_NAME}" 2>/dev/null || stat -c%s "${PROVIDERS_DIR}/${THEME_JAR_NAME}" 2>/dev/null || echo "unknown")
      echo "✓ Copied $(basename "$THEME_JAR_TO_USE") as ${THEME_JAR_NAME} (size: ${COPIED_SIZE} bytes)"
      if [[ "$JAR_SIZE" != "unknown" ]] && [[ "$COPIED_SIZE" != "unknown" ]] && [[ "$JAR_SIZE" != "$COPIED_SIZE" ]]; then
        echo "WARNING: JAR size mismatch! Original: ${JAR_SIZE}, Copied: ${COPIED_SIZE}" >&2
      fi
    else
      echo "ERROR: Failed to copy JAR to providers directory!" >&2
      exit 1
    fi
  else
    echo "ERROR: Selected theme JAR not found: ${THEME_JAR_TO_USE}" >&2
    exit 1
  fi
fi
popd >/dev/null

echo "=== Verifying required files in providers ==="
ls -lh "${PROVIDERS_DIR}" || true
test -f "${PROVIDERS_DIR}/keycloak-phone-provider.jar"
test -f "${PROVIDERS_DIR}/keycloak-phone-provider-msg91.jar"
test -f "${PROVIDERS_DIR}/${THEME_JAR_NAME}"

# Final verification: Check theme JAR structure in providers directory
echo "=== Verifying theme JAR structure in providers ==="
if [[ -f "${PROVIDERS_DIR}/${THEME_JAR_NAME}" ]]; then
  FINAL_SIZE=$(stat -f%z "${PROVIDERS_DIR}/${THEME_JAR_NAME}" 2>/dev/null || stat -c%s "${PROVIDERS_DIR}/${THEME_JAR_NAME}" 2>/dev/null || echo "unknown")
  echo "Theme JAR size: ${FINAL_SIZE} bytes"
  
  # Verify key files exist in the JAR
  if jar -tf "${PROVIDERS_DIR}/${THEME_JAR_NAME}" | grep -q "META-INF/keycloak-themes.json"; then
    echo "✓ JAR contains keycloak-themes.json"
    # Extract and show theme name
    jar -xf "${PROVIDERS_DIR}/${THEME_JAR_NAME}" META-INF/keycloak-themes.json 2>/dev/null || true
    if [[ -f "META-INF/keycloak-themes.json" ]]; then
      echo "Theme registration:"
      cat META-INF/keycloak-themes.json | grep -A 3 "\"name\"" || cat META-INF/keycloak-themes.json
      rm -rf META-INF 2>/dev/null || true
    fi
  else
    echo "ERROR: JAR missing keycloak-themes.json!" >&2
    exit 1
  fi
  
  if jar -tf "${PROVIDERS_DIR}/${THEME_JAR_NAME}" | grep -q "login.ftl"; then
    echo "✓ JAR contains login.ftl template"
  else
    echo "ERROR: JAR missing login.ftl template!" >&2
    exit 1
  fi
  
  echo "✓ Theme JAR verification passed"
else
  echo "ERROR: Theme JAR not found in providers directory!" >&2
  exit 1
fi

echo "=== Build container done ==="


