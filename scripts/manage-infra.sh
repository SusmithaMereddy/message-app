#!/bin/bash
set -euo pipefail

ACTION=${1:-create}   # default = create

# ---------------------- CONFIGURATION ----------------------
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
UNIQUE_SUFFIX="susmitha"
ACR_NAME="messageappacr-${UNIQUE_SUFFIX}"
CONTAINER_APP_ENV="messageapp-env-${UNIQUE_SUFFIX}"
LOG_WORKSPACE="workspace-rg-${UNIQUE_SUFFIX}"
echo ""
echo "========================================"
echo "   Azure Infrastructure Script ($ACTION)"
echo "========================================"
echo ""

# ---------------------- DELETE RESOURCES ----------------------
# No changes needed in this section. It is already correct.
if [[ "$ACTION" == "delete" ]]; then
    echo "[DELETE] Removing Azure resources (not deleting RG)..."

    # Delete Container App Environment
    if az containerapp env show --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo "Deleting Container App Environment..."
        az containerapp env delete --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" --yes
    else
        echo "Container App Environment not found (skipped)"
    fi

    # Delete ACR
    if az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &> /dev/null; then
        echo "Deleting ACR..."
        az acr delete --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --yes
    else
        echo "ACR not found (skipped)"
    fi

    # Delete Log Analytics Workspace
    if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null; then
        echo "Deleting Log Analytics workspace..."
        az monitor log-analytics workspace delete -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --yes
    else
        echo "Log Analytics workspace not found (skipped)"
    fi

    echo ""
    echo "----------------------------------------"
    echo " DELETE completed successfully!"
    echo "----------------------------------------"
    exit 0
fi

# ---------------------- CREATE RESOURCES (UPDATED SECTION) ----------------------
echo "[INFO] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

# --- Resource Group ---
echo "[INFO] Verifying Resource Group..."
if az group show -n "$RESOURCE_GROUP" &> /dev/null; then
    echo "[INFO] Resource Group '$RESOURCE_GROUP' already exists."
else
    echo "[ACTION] Creating Resource Group '$RESOURCE_GROUP'..."
    az group create -n "$RESOURCE_GROUP" -l "$LOCATION"
fi

# --- Log Analytics Workspace ---
echo "[INFO] Verifying Log Analytics Workspace..."
if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null; then
    echo "[INFO] Log Analytics Workspace '$LOG_WORKSPACE' already exists."
else
    echo "[ACTION] Creating Log Analytics Workspace '$LOG_WORKSPACE'..."
    az monitor log-analytics workspace create -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --location "$LOCATION"
fi

# --- Azure Container Registry (ACR) ---
echo "[INFO] Verifying Azure Container Registry..."
if az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &> /dev/null; then
    echo "[INFO] ACR '$ACR_NAME' already exists. Skipping creation."
else
    echo "[ACTION] Creating ACR '$ACR_NAME'..."
    az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic --admin-enabled true --location "$LOCATION"
fi

# --- Container Apps Environment ---
echo "[INFO] Verifying Container Apps Environment..."
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
        --logs-workspace-key "$WORKSPACE_KEY"
fi

echo ""
echo "----------------------------------------"
echo " Resource creation completed successfully!"
echo "----------------------------------------"