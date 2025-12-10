#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -e <env> [-t <image_tag>]
  -e <env>       Target environment: dev|qa|staging|prod
  -t <image_tag> Image tag to deploy (default: latest)
Environment variables required:
  RESOURCE_GROUP            (default: exr-dvo-intern-inc if not set)
  ACR_LOGIN_SERVER          (e.g. messageappacr-dev-susmitha.azurecr.io)
  ACR_USERNAME
  ACR_PASSWORD
Optional (if you want to create containerapp envs with logs):
  LOG_WORKSPACE_ID
  LOG_WORKSPACE_KEY
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
  echo "ERROR: target env required"
  usage
fi

# normalize env
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

# defaults (override with env vars if needed)
RESOURCE_GROUP="${RESOURCE_GROUP:-exr-dvo-intern-inc}"
LOCATION="${LOCATION:-centralindia}"
ACR="${ACR_LOGIN_SERVER:-}"

if [[ -z "$ACR" || -z "${ACR_USERNAME:-}" || -z "${ACR_PASSWORD:-}" ]]; then
  echo "ERROR: set ACR_LOGIN_SERVER, ACR_USERNAME and ACR_PASSWORD in env"
  exit 2
fi

ACA_ENV="messageapp-env-${ENV}-susmitha"
BACKEND_APP="message-app-backend-${ENV}"
FRONTEND_APP="message-app-frontend-${ENV}"
BACKEND_IMAGE="${ACR}/backend-app-susmitha:${TAG}"
FRONTEND_IMAGE="${ACR}/frontend-app-susmitha:${TAG}"

echo "Deploying to env=$ENV (RG=$RESOURCE_GROUP) tag=$TAG"
echo "ACA env name: $ACA_ENV"
echo "Backend image: $BACKEND_IMAGE"
echo "Frontend image: $FRONTEND_IMAGE"

# Ensure ACA environment exists (create if missing). If you want log workspace linkage, set LOG_WORKSPACE_ID and LOG_WORKSPACE_KEY env variables.
if ! az containerapp env show -n "$ACA_ENV" -g "$RESOURCE_GROUP" &>/dev/null; then
  echo "Creating Container Apps environment: $ACA_ENV"
  if [[ -n "${LOG_WORKSPACE_ID:-}" && -n "${LOG_WORKSPACE_KEY:-}" ]]; then
    az containerapp env create \
      --name "$ACA_ENV" \
      --resource-group "$RESOURCE_GROUP" \
      --location "$LOCATION" \
      --logs-workspace-id "$LOG_WORKSPACE_ID" \
      --logs-workspace-key "$LOG_WORKSPACE_KEY"
  else
    az containerapp env create \
      --name "$ACA_ENV" \
      --resource-group "$RESOURCE_GROUP" \
      --location "$LOCATION"
  fi
else
  echo "ACA environment $ACA_ENV already exists"
fi

# Create/update backend (internal)
if az containerapp show -n "$BACKEND_APP" -g "$RESOURCE_GROUP" &>/dev/null; then
  echo "Updating backend $BACKEND_APP -> $BACKEND_IMAGE"
  # Only update the image on existing app. Do not pass registry flags to `update`.
  az containerapp update \
    --name "$BACKEND_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$BACKEND_IMAGE"
else
  echo "Creating backend $BACKEND_APP (internal)"
  az containerapp create \
    --name "$BACKEND_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ACA_ENV" \
    --image "$BACKEND_IMAGE" \
    --registry-server "$ACR" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --target-port 8080 \
    --ingress internal \
    --env-vars JAVA_TOOL_OPTIONS="-Duser.timezone=Asia/Kolkata"
fi

# Ensure JAVA_TOOL_OPTIONS set idempotently (will not fail if already set)
az containerapp update --name "$BACKEND_APP" --resource-group "$RESOURCE_GROUP" --set-env-vars "JAVA_TOOL_OPTIONS=-Duser.timezone=Asia/Kolkata" || true

# Get backend fqdn if any (internal likely empty)
BACKEND_FQDN=$(az containerapp show -n "$BACKEND_APP" -g "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv || true)
if [[ -n "$BACKEND_FQDN" ]]; then
  BACKEND_URL="https://$BACKEND_FQDN"
else
  BACKEND_URL=""
fi
echo "Computed BACKEND_URL='$BACKEND_URL'"

# Create/update frontend (external)
if az containerapp show -n "$FRONTEND_APP" -g "$RESOURCE_GROUP" &>/dev/null; then
  echo "Updating frontend $FRONTEND_APP -> $FRONTEND_IMAGE"
  # Only update the image and env var on existing app. Do not pass registry flags to `update`.
  az containerapp update \
    --name "$FRONTEND_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$FRONTEND_IMAGE" \
    --set-env-vars "BACKEND_URL=$BACKEND_URL"
else
  echo "Creating frontend $FRONTEND_APP (external)"
  az containerapp create \
    --name "$FRONTEND_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ACA_ENV" \
    --image "$FRONTEND_IMAGE" \
    --registry-server "$ACR" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --target-port 80 \
    --ingress external

  # After create, ensure BACKEND_URL env is set
  az containerapp update --name "$FRONTEND_APP" --resource-group "$RESOURCE_GROUP" --set-env-vars "BACKEND_URL=$BACKEND_URL"
fi

FRONTEND_FQDN=$(az containerapp show -n "$FRONTEND_APP" -g "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv || true)
if [[ -n "$FRONTEND_FQDN" ]]; then
  echo "Frontend URL: https://$FRONTEND_FQDN"
else
  echo "Frontend has no public ingress FQDN yet (check ingress setting or creation logs)."
fi

echo "Deployment completed."
