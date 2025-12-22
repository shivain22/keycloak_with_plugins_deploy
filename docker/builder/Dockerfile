FROM node:20-bookworm-slim

# Install build dependencies: git, Java 17, Maven
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    openjdk-17-jdk-headless \
    maven \
    bash \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work

# Copy build script into image
COPY build-artifacts.sh /usr/local/bin/build-artifacts.sh
RUN chmod +x /usr/local/bin/build-artifacts.sh

ENTRYPOINT ["/usr/local/bin/build-artifacts.sh"]


