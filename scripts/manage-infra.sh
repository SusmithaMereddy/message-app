#!/bin/bash
set -euo pipefail
 
ACTION=${1:-create}   # default = create
 
# ---------------------- CONFIGURATION ----------------------
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
ACR_NAME="messageappacr"
CONTAINER_APP_ENV="messageapp-env"
LOG_WORKSPACE="workspace-${RESOURCE_GROUP}"
 
echo ""
echo "========================================"
echo "   Azure Infrastructure Script ($ACTION)"
echo "========================================"
echo ""
 
# ---------------------- DELETE RESOURCES ----------------------
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
 
# ---------------------- CREATE RESOURCES ----------------------
echo "[INFO] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"
 
echo "[INFO] Checking Resource Group..."
az group show -n "$RESOURCE_GROUP" &> /dev/null || {
    az group create -n "$RESOURCE_GROUP" -l "$LOCATION"
}
 
echo "[INFO] Checking Log Analytics Workspace..."
az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null || {
    az monitor log-analytics workspace create -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --location "$LOCATION"
}
 
echo "[INFO] Checking ACR..."
az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &> /dev/null || {
    az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic --admin-enabled true --location "$LOCATION"
}
 
echo "[INFO] Checking Container Apps Environment..."
az containerapp env show --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" &> /dev/null || {
   
    WORKSPACE_ID=$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query customerId -o tsv)
    WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query primarySharedKey -o tsv)
 
    az containerapp env create \
        --name "$CONTAINER_APP_ENV" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --logs-workspace-id "$WORKSPACE_ID" \
        --logs-workspace-key "$WORKSPACE_KEY"
}
 
echo ""
echo "----------------------------------------"
echo " CREATE completed successfully!"
echo "----------------------------------------"