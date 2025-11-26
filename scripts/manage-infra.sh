#!/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -e <env> -a <action>
  -e <env>      Target environment: dev|qa|staging|prod
  -a <action>   Action to perform: create|delete
Environment variables (optional):
  SUBSCRIPTION_NAME (default: Founder-HUB-Microsoft Azure Sponsorship)
  RESOURCE_GROUP    (default: exr-dvo-intern-inc)
  LOCATION          (default: centralindia)
EOF
  exit 1
}

ENV=""
ACTION=""

while getopts ":e:a:" opt; do
  case "${opt}" in
    e) ENV="${OPTARG}" ;;
    a) ACTION="${OPTARG}" ;;
    *) usage ;;
  esac
done

if [[ -z "$ENV" || -z "$ACTION" ]]; then
  usage
fi

# normalize env lower
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

# ---------------------- CONFIGURATION ----------------------
SUBSCRIPTION_NAME="${SUBSCRIPTION_NAME:-Founder-HUB-Microsoft Azure Sponsorship}"
RESOURCE_GROUP="${RESOURCE_GROUP:-exr-dvo-intern-inc}"
LOCATION="${LOCATION:-centralindia}"
UNIQUE_SUFFIX="susmitha"
ACR_NAME="messageappacr${ENV}${UNIQUE_SUFFIX}"
CONTAINER_APP_ENV="messageapp-env-${ENV}-${UNIQUE_SUFFIX}"
LOG_WORKSPACE="workspace-${ENV}-${UNIQUE_SUFFIX}"

echo ""
echo "========================================"
echo "   Azure Infrastructure Script (env=$ENV, action=$ACTION)"
echo "========================================"
echo ""

if [[ "$ACTION" == "delete" ]]; then
    echo "[DELETE] Removing Azure resources for env='$ENV' (not deleting RG)..."

    # Delete Container App Environment
    if az containerapp env show --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo "Deleting Container App Environment '$CONTAINER_APP_ENV'..."
        az containerapp env delete --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" --yes
    else
        echo "Container App Environment not found (skipped)"
    fi

    # Delete ACR
    if az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &> /dev/null; then
        echo "Deleting ACR '$ACR_NAME'..."
        az acr delete --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --yes
    else
        echo "ACR not found (skipped)"
    fi

    # Delete Log Analytics Workspace
    if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null; then
        echo "Deleting Log Analytics workspace '$LOG_WORKSPACE'..."
        az monitor log-analytics workspace delete -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --yes
    else
        echo "Log Analytics workspace not found (skipped)"
    fi

    echo ""
    echo "----------------------------------------"
    echo " DELETE completed successfully for env='$ENV'!"
    echo "----------------------------------------"
    exit 0
fi

# ---------------------- CREATE RESOURCES ----------------------
if [[ "$ACTION" != "create" ]]; then
  echo "Unknown action: $ACTION"
  usage
fi

echo "[INFO] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

# --- Resource Group (shared across envs) ---
echo "[INFO] Verifying Resource Group..."
if az group show -n "$RESOURCE_GROUP" &> /dev/null; then
    echo "[INFO] Resource Group '$RESOURCE_GROUP' already exists."
else
    echo "[ACTION] Creating Resource Group '$RESOURCE_GROUP'..."
    az group create -n "$RESOURCE_GROUP" -l "$LOCATION" >/dev/null
fi

# --- Log Analytics Workspace (per-env) ---
echo "[INFO] Verifying Log Analytics Workspace ($LOG_WORKSPACE)..."
if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null; then
    echo "[INFO] Log Analytics Workspace '$LOG_WORKSPACE' already exists."
else
    echo "[ACTION] Creating Log Analytics Workspace '$LOG_WORKSPACE'..."
    az monitor log-analytics workspace create -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --location "$LOCATION" >/dev/null
fi

# --- Azure Container Registry (per-env) ---
echo "[INFO] Verifying Azure Container Registry ($ACR_NAME)..."
if az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &> /dev/null; then
    echo "[INFO] ACR '$ACR_NAME' already exists. Skipping creation."
else
    echo "[ACTION] Creating ACR '$ACR_NAME'..."
    az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic --admin-enabled true --location "$LOCATION" >/dev/null
fi

# --- Container Apps Environment (per-env) ---
echo "[INFO] Verifying Container Apps Environment ($CONTAINER_APP_ENV)..."
if az containerapp env show --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo "[INFO] Container Apps Environment '$CONTAINER_APP_ENV' already exists. Skipping creation."
else
    echo "[ACTION] Creating Container Apps Environment '$CONTAINER_APP_ENV'..."

    WORKSPACE_ID=$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query customerId -o tsv)
    WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query primarySharedKey -o tsv)

    az containerapp env create \
        --name "$CONTAINER_APP_ENV" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --logs-workspace-id "$WORKSPACE_ID" \
        --logs-workspace-key "$WORKSPACE_KEY" >/dev/null
fi

echo ""
echo "----------------------------------------"
echo " Resource creation completed successfully for env='$ENV'!"
echo "----------------------------------------"
