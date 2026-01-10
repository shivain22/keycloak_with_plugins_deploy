#!/usr/bin/env bash
set -euo pipefail

# Ensure script is run with bash (not sh)
if [ -z "${BASH_VERSION:-}" ]; then
  echo "ERROR: This script requires bash. Please run: bash $0" >&2
  exit 1
fi

# Generate realm JSON files from templates with environment variable substitution
# Usage: ./scripts/generate-realm-configs.sh [local|dev|staging|prod]

ENV="${1:-local}"

# Get script directory (compatible with both bash and sh)
if [ -n "${BASH_SOURCE:-}" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
cd "${REPO_ROOT}"

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

# Set defaults based on environment
case "${ENV}" in
  local)
    GATEWAY_URL="${GATEWAY_URL:-http://localhost:${GATEWAY_HTTP_PORT:-9293}}"
    SERVICE_URL="${SERVICE_URL:-http://localhost:${SERVICE_HTTP_PORT:-9294}}"
    FRONTEND_URL="${FRONTEND_URL:-http://localhost:9000}"
    KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:${KEYCLOAK_HTTP_PORT:-9292}}"
    # Production URLs (always include for CORS/redirect URIs)
    GATEWAY_URL_PROD="${GATEWAY_URL_PROD:-https://rmsgateway.atparui.com}"
    SERVICE_URL_PROD="${SERVICE_URL_PROD:-https://rmsservice.atparui.com}"
    DASHBOARD_URL_PROD="${DASHBOARD_URL_PROD:-https://rmsdashboard.atparui.com}"
    ;;
  dev)
    GATEWAY_URL="${GATEWAY_URL:-https://gateway-dev.example.com}"
    SERVICE_URL="${SERVICE_URL:-https://service-dev.example.com}"
    FRONTEND_URL="${FRONTEND_URL:-https://app-dev.example.com}"
    KEYCLOAK_URL="${KEYCLOAK_URL:-https://auth-dev.example.com}"
    GATEWAY_URL_PROD="${GATEWAY_URL_PROD:-https://rmsgateway.atparui.com}"
    SERVICE_URL_PROD="${SERVICE_URL_PROD:-https://rmsservice.atparui.com}"
    DASHBOARD_URL_PROD="${DASHBOARD_URL_PROD:-https://rmsdashboard.atparui.com}"
    ;;
  staging)
    GATEWAY_URL="${GATEWAY_URL:-https://gateway-staging.example.com}"
    SERVICE_URL="${SERVICE_URL:-https://service-staging.example.com}"
    FRONTEND_URL="${FRONTEND_URL:-https://app-staging.example.com}"
    KEYCLOAK_URL="${KEYCLOAK_URL:-https://auth-staging.example.com}"
    GATEWAY_URL_PROD="${GATEWAY_URL_PROD:-https://rmsgateway.atparui.com}"
    SERVICE_URL_PROD="${SERVICE_URL_PROD:-https://rmsservice.atparui.com}"
    DASHBOARD_URL_PROD="${DASHBOARD_URL_PROD:-https://rmsdashboard.atparui.com}"
    ;;
  prod)
    GATEWAY_URL="${GATEWAY_URL:-https://rmsgateway.atparui.com}"
    SERVICE_URL="${SERVICE_URL:-https://rmsservice.atparui.com}"
    FRONTEND_URL="${FRONTEND_URL:-https://rmsdashboard.atparui.com}"
    KEYCLOAK_URL="${KEYCLOAK_URL:-https://auth.atparui.com}"
    GATEWAY_URL_PROD="${GATEWAY_URL_PROD:-https://rmsgateway.atparui.com}"
    SERVICE_URL_PROD="${SERVICE_URL_PROD:-https://rmsservice.atparui.com}"
    DASHBOARD_URL_PROD="${DASHBOARD_URL_PROD:-https://rmsdashboard.atparui.com}"
    ;;
  *)
    echo "Unknown environment: ${ENV}" >&2
    exit 1
    ;;
esac

echo "Generating realm configs for environment: ${ENV}"
echo "Gateway URL: ${GATEWAY_URL}"
echo "Service URL: ${SERVICE_URL}"
echo "Frontend URL: ${FRONTEND_URL}"
echo "Keycloak URL: ${KEYCLOAK_URL}"
echo "Production Gateway URL: ${GATEWAY_URL_PROD}"
echo "Production Service URL: ${SERVICE_URL_PROD}"
echo "Production Dashboard URL: ${DASHBOARD_URL_PROD}"

# Create realm-import directory if it doesn't exist
mkdir -p realm-import

# Function to replace template variables
replace_template() {
  local template_file="$1"
  local output_file="$2"
  sed -e "s|\${GATEWAY_URL}|${GATEWAY_URL}|g" \
      -e "s|\${SERVICE_URL}|${SERVICE_URL}|g" \
      -e "s|\${FRONTEND_URL}|${FRONTEND_URL}|g" \
      -e "s|\${KEYCLOAK_URL}|${KEYCLOAK_URL}|g" \
      -e "s|\${GATEWAY_URL_PROD}|${GATEWAY_URL_PROD}|g" \
      -e "s|\${SERVICE_URL_PROD}|${SERVICE_URL_PROD}|g" \
      -e "s|\${DASHBOARD_URL_PROD}|${DASHBOARD_URL_PROD}|g" \
      "${template_file}" > "${output_file}"
}

# Generate gateway-realm.json
if [ -f "realm-import-templates/gateway-realm.json.template" ]; then
  replace_template "realm-import-templates/gateway-realm.json.template" "realm-import/gateway-realm.json"
else
  echo "WARNING: Template file not found: realm-import-templates/gateway-realm.json.template" >&2
fi

# Generate rms-service-realm.json
if [ -f "realm-import-templates/rms-service-realm.json.template" ]; then
  replace_template "realm-import-templates/rms-service-realm.json.template" "realm-import/rms-service-realm.json"
else
  echo "WARNING: Template file not found: realm-import-templates/rms-service-realm.json.template" >&2
fi

echo "Realm configs generated successfully!"

