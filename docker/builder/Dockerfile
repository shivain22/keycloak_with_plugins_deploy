FROM node:20-bookworm-slim

# Install build dependencies: git, Java 21, Maven
# All projects (keycloak-phone-provider and rms-auth-theme-plugin) now support Java 21
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    openjdk-21-jdk-headless \
    maven \
    bash \
  && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME to Java 21
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

WORKDIR /work

# Copy build script into image
COPY build-artifacts.sh /usr/local/bin/build-artifacts.sh
RUN chmod +x /usr/local/bin/build-artifacts.sh

ENTRYPOINT ["/usr/local/bin/build-artifacts.sh"]


