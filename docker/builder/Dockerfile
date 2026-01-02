FROM node:20-bookworm-slim

# Install build dependencies: git, Java 21, Maven
# All projects (keycloak-phone-provider and rms-auth-theme-plugin) now support Java 21
# For Debian bookworm, Java 21 is not in default repos, so we install from Eclipse Adoptium (Temurin)
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    wget \
    gnupg \
    maven \
    bash \
  && rm -rf /var/lib/apt/lists/*

# Install Java 21 from Eclipse Adoptium (Temurin) repository
RUN mkdir -p /etc/apt/keyrings \
  && wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list > /dev/null \
  && apt-get update \
  && apt-get install -y --no-install-recommends temurin-21-jdk \
  && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME to Java 21 - detect the actual installation path
RUN JAVA_21_HOME=$(update-alternatives --list java 2>/dev/null | grep -i "21" | head -1 | sed 's|/bin/java||') \
  && if [ -z "$JAVA_21_HOME" ]; then \
       JAVA_21_HOME=$(ls -d /usr/lib/jvm/temurin-21-jdk-* 2>/dev/null | head -1); \
     fi \
  && if [ -z "$JAVA_21_HOME" ]; then \
       JAVA_21_HOME="/usr/lib/jvm/temurin-21-jdk-amd64"; \
     fi \
  && echo "Java 21 found at: $JAVA_21_HOME" \
  && echo "export JAVA_HOME=$JAVA_21_HOME" >> /etc/profile.d/java21.sh \
  && echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java21.sh

# Set JAVA_HOME in environment (default path, will be correct after package install)
ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

WORKDIR /work

# Copy build script into image
COPY build-artifacts.sh /usr/local/bin/build-artifacts.sh
RUN chmod +x /usr/local/bin/build-artifacts.sh

ENTRYPOINT ["/usr/local/bin/build-artifacts.sh"]
