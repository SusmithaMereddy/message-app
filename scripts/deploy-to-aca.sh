#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -e <env> -t <image_tag>
  -e <env>       Target environment: dev|qa|staging|prod
  -t <image_tag> Image tag to deploy (sha or latest)
EOF
  exit 1
}

ENV=""
TAG=""

while getopts ":e:t:" opt; do
  case "${opt}" in
    e) ENV="${OPTARG}" ;;
    t) TAG="${OPTARG}" ;;
    *) usage ;;
  esac
done

if [[ -z "$ENV" || -z "$TAG" ]]; then
  echo "ERROR: both -e and -t are required"
  usage
fi

RESOURCE_GROUP="${RESOURCE_GROUP:-exr-dvo-intern-inc}"
LOCATION="${LOCATION:-centralindia}"
ACR="${ACR_LOGIN_SERVER}"

ACA_ENV="messageapp-env-${ENV}"
BACKEND_APP="message-app-backend-${ENV}"
FRONTEND_APP="message-app-frontend-${ENV}"

BACKEND_IMAGE="${ACR}/backend-app-susmitha:${TAG}"
FRONTEND_IMAGE="${ACR}/frontend-app-susmitha:${TAG}"

echo "Deploying env=$ENV image_tag=$TAG"

# Create ACA env if needed
if ! az containerapp env show -n "$ACA_ENV" -g "$RESOURCE_GROUP" &>/dev/null; then
  echo "Creating ACA environment: $ACA_ENV"
  az containerapp env create \
    --name "$ACA_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION"
fi

# Backend (internal)
if az containerapp show -n "$BACKEND_APP" -g "$RESOURCE_GROUP" &>/dev/null; then
  az containerapp update \
  --name "$BACKEND_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$ACR_LOGIN_SERVER/backend-app-susmitha:$TAG" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD"

else
  az containerapp create \
  --name "$BACKEND_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ACA_ENV" \
  --image "$ACR_LOGIN_SERVER/backend-app-susmitha:$TAG" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --target-port 8080 \
  --ingress internal

fi

# Backend URL (internal)
BACKEND_FQDN=$(az containerapp show -n "$BACKEND_APP" -g "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv || echo "")
BACKEND_URL=""
[[ -n "$BACKEND_FQDN" ]] && BACKEND_URL="https://$BACKEND_FQDN"

# Frontend (external)
if az containerapp show -n "$FRONTEND_APP" -g "$RESOURCE_GROUP" &>/dev/null; then
  az containerapp update \
      --name "$FRONTEND_APP" \
      --resource-group "$RESOURCE_GROUP" \
      --image "$FRONTEND_IMAGE" \
      --set-env-vars BACKEND_URL="$BACKEND_URL"
else
  az containerapp create \
      --name "$FRONTEND_APP" \
      --resource-group "$RESOURCE_GROUP" \
      --environment "$ACA_ENV" \
      --image "$FRONTEND_IMAGE" \
      --target-port 80 \
      --ingress external
fi

echo "Deployment complete for environment: $ENV"
