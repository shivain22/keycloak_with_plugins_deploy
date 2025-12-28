#!/bin/bash
# Entrypoint script for Keycloak that handles debug logging configuration
# Debug logging is enabled by default (KC_LOG_LEVEL=DEBUG)
# Set KEYCLOAK_DISABLE_DEBUG=true to disable debug logging (sets log level to INFO)

set -e

# If KEYCLOAK_DISABLE_DEBUG is set to "true", change log level to INFO
if [ "${KEYCLOAK_DISABLE_DEBUG}" = "true" ]; then
    export KC_LOG_LEVEL="INFO"
    echo "[Keycloak Entrypoint] Debug logging disabled (KEYCLOAK_DISABLE_DEBUG=true). Setting KC_LOG_LEVEL=INFO"
else
    # Default to DEBUG if not explicitly set
    export KC_LOG_LEVEL="${KC_LOG_LEVEL:-DEBUG}"
    echo "[Keycloak Entrypoint] Debug logging enabled. KC_LOG_LEVEL=${KC_LOG_LEVEL}"
fi

# Find the Keycloak script (try common locations)
KC_SCRIPT="/opt/keycloak/bin/kc.sh"
if [ ! -f "$KC_SCRIPT" ]; then
    # Try alternative location
    KC_SCRIPT="/opt/keycloak/bin/kc.sh"
    if [ ! -f "$KC_SCRIPT" ]; then
        echo "ERROR: Keycloak script not found at /opt/keycloak/bin/kc.sh" >&2
        exit 1
    fi
fi

# Execute the original Keycloak command with all arguments
exec "$KC_SCRIPT" "$@"

