#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -e <env> [-t <image_tag>]
  -e <env>       Target environment: dev|qa|staging|prod
  -t <image_tag> Image tag to deploy (default: latest)

Environment variables required (set these as GitHub Environment secrets per env):
  ACR_LOGIN_SERVER   (e.g. messageappacrdevsusmitha.azurecr.io)
  ACR_USERNAME       (username for the ACR; optional if using RBAC)
  ACR_PASSWORD       (password for the ACR; optional if using RBAC)
  RESOURCE_GROUP     (default: exr-dvo-intern-inc)

Optional:
  LOG_WORKSPACE_ID
  LOG_WORKSPACE_KEY

This script will:
 - create or update backend and frontend container apps in the specified ACA environment
 - configure registry credentials with az containerapp registry set (required)
EOF
  exit 1
}

ENV=""
TAG="latest"

while getopts ":e:t:" opt; do
  case "${opt}" in
    e) ENV="${OPTARG}" ;;
    t) TAG="${OPTARG}" ;;
    *) usage ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "ERROR: -e <env> is required"
  usage
fi

RESOURCE_GROUP="${RESOURCE_GROUP:-exr-dvo-intern-inc}"
LOCATION="${LOCATION:-centralindia}"

# Derive names (adjust if your naming differs)
BACKEND_APP_NAME="message-app-backend-${ENV}"
FRONTEND_APP_NAME="message-app-frontend-${ENV}"
ACA_ENV_NAME="messageapp-env-${ENV}"

# Read ACR info from env (set these as GitHub Environment secrets for each env)
ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-}"
ACR_USERNAME="${ACR_USERNAME:-}"
ACR_PASSWORD="${ACR_PASSWORD:-}"

# images
BACKEND_IMAGE_NAME="backend-app-susmitha"
FRONTEND_IMAGE_NAME="frontend-app-susmitha"
BACKEND_IMAGE="${ACR_LOGIN_SERVER}/${BACKEND_IMAGE_NAME}:${TAG}"
FRONTEND_IMAGE="${ACR_LOGIN_SERVER}/${FRONTEND_IMAGE_NAME}:${TAG}"

echo "Deploying env=${ENV} image_tag=${TAG}"
echo "RESOURCE_GROUP=${RESOURCE_GROUP}"
echo "ACA_ENV_NAME=${ACA_ENV_NAME}"
echo "BACKEND_APP_NAME=${BACKEND_APP_NAME}"
echo "FRONTEND_APP_NAME=${FRONTEND_APP_NAME}"
echo "ACR_LOGIN_SERVER=${ACR_LOGIN_SERVER}"
if [[ -n "$ACR_USERNAME" ]]; then
  echo "ACR_USERNAME is set: YES"
else
  echo "ACR_USERNAME is set: NO"
fi
echo "Note: ACR_PASSWORD will not be printed for security."

# Basic validation
if [[ -z "$ACR_LOGIN_SERVER" ]]; then
  echo "ERROR: ACR_LOGIN_SERVER environment variable is required (set as environment secret for '$ENV')."
  exit 2
fi

# Ensure containerapp extension exists (the workflow already installs; safe here)
az extension add --name containerapp --yes >/dev/null 2>&1 || az extension update --name containerapp >/dev/null 2>&1 || true

# Helper: ensure ACA environment exists (create if missing)
if ! az containerapp env show --name "$ACA_ENV_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "ACA environment $ACA_ENV_NAME does not exist. Creating..."
  if [[ -n "${LOG_WORKSPACE_ID:-}" && -n "${LOG_WORKSPACE_KEY:-}" ]]; then
    az containerapp env create --name "$ACA_ENV_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
      --logs-workspace-id "$LOG_WORKSPACE_ID" --logs-workspace-key "$LOG_WORKSPACE_KEY"
  else
    az containerapp env create --name "$ACA_ENV_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION"
  fi
else
  echo "ACA environment $ACA_ENV_NAME exists."
fi

# Function: configure registry credentials for a container app
set_registry_creds() {
  local appname="$1"

  if [[ -z "$ACR_USERNAME" || -z "$ACR_PASSWORD" ]]; then
    echo "INFO: ACR_USERNAME/ACR_PASSWORD not provided. Skipping az containerapp registry set."
    echo "      Ensure the deploy SP has AcrPull on the ACR or configure credentials if required."
    return 0
  fi

  echo "Setting registry credentials for $appname (server: $ACR_LOGIN_SERVER)"
  az containerapp registry set \
    --name "$appname" \
    --resource-group "$RESOURCE_GROUP" \
    --server "$ACR_LOGIN_SERVER" \
    --username "$ACR_USERNAME" \
    --password "$ACR_PASSWORD"
}

# Deploy/Update Backend
echo ">>> Deploying backend: $BACKEND_IMAGE"

if az containerapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "Backend exists — updating image..."
  az containerapp update \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$BACKEND_IMAGE"
else
  echo "Backend does not exist — creating..."
  az containerapp create \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ACA_ENV_NAME" \
    --image "$BACKEND_IMAGE" \
    --target-port 8080 \
    --ingress internal
fi

# Ensure registry creds are set so ACA can pull the private image
set_registry_creds "$BACKEND_APP_NAME"

# Deploy/Update Frontend (external ingress)
echo ">>> Deploying frontend: $FRONTEND_IMAGE"

if az containerapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "Frontend exists — updating image..."
  az containerapp update \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$FRONTEND_IMAGE"
else
  echo "Frontend does not exist — creating..."
  az containerapp create \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ACA_ENV_NAME" \
    --image "$FRONTEND_IMAGE" \
    --target-port 80 \
    --ingress external
fi

set_registry_creds "$FRONTEND_APP_NAME"

# Print resulting FQDNs
BACKEND_FQDN=$(az containerapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv || echo "")
FRONTEND_FQDN=$(az containerapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv || echo "")

echo "Deployment completed."
if [[ -n "$FRONTEND_FQDN" ]]; then
  echo "Frontend URL: https://$FRONTEND_FQDN"
else
  echo "Frontend FQDN unavailable (may take a moment)."
fi
if [[ -n "$BACKEND_FQDN" ]]; then
  echo "Backend FQDN: $BACKEND_FQDN"
else
  echo "Backend FQDN unavailable (internal ingress)."
fi

# Show containerapp registry config for verification
echo ""
echo ">>> Registry configuration for backend:"
az containerapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.configuration.registries" -o json || true
echo ""
echo ">>> Registry configuration for frontend:"
az containerapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.configuration.registries" -o json || true
