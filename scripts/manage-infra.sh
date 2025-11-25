#!/bin/bash
set -euo pipefail

###############################################
# MANAGE INFRA FOR ALL ENVIRONMENTS (DEV → PROD)
# Single Resource Group (exr-dvo-intern-inc)
# Multiple ACRs + ACA Environments + Log Workspaces
#
# Usage:
#   ./scripts/manage-infra.sh create
#   ./scripts/manage-infra.sh delete
#
# Notes:
# - To automatically assign AcrPull to your deploy service principal,
#   set AZURE_DEPLOY_SP_APPID to the service principal's clientId (appId)
#   before running this script, e.g.:
#     export AZURE_DEPLOY_SP_APPID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#
# - This script expects you have already run 'az login' or that the
#   GitHub Actions runner has authenticated via azure/login@v1.
###############################################

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 <create|delete>"
  exit 1
fi

SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="centralindia"

# Environments to create infra for
ENVS=(dev qa staging prod)

echo ""
echo "=============================================="
echo "     MANAGING INFRASTRUCTURE FOR ALL ENVS"
echo "     Resource Group: $RESOURCE_GROUP"
echo "     ACTION: $ACTION"
echo "=============================================="
echo ""

#######################################
# SET SUBSCRIPTION (requires az login / creds)
#######################################
echo "➡ Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"
echo "✔ Subscription set"

#######################################
# RESOURCE GROUP (create only on create)
#######################################
if [[ "$ACTION" == "create" ]]; then
  echo "➡ Checking Resource Group..."
  if ! az group show -n "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "➡ Creating Resource Group: $RESOURCE_GROUP"
    az group create -n "$RESOURCE_GROUP" -l "$LOCATION"
  else
    echo "✔ Resource Group already exists"
  fi
fi

#######################################
# HANDLE ACTION: create OR delete
#######################################
if [[ "$ACTION" == "delete" ]]; then
  echo ""
  echo "----------------------------------------------"
  echo "     DELETING: ACRs, Log Workspaces, ACA envs"
  echo "     (NOTE: Resource group itself is NOT deleted)"
  echo "----------------------------------------------"

  for ENV in "${ENVS[@]}"; do
    ACR_NAME="messageappacr-${ENV}-susmitha"
    LOG_WS="messageapp-logs-${ENV}"
    ACA_ENV="messageapp-env-${ENV}"

    echo "=> Deleting ACA environment (if exists): $ACA_ENV"
    if az containerapp env show -n "$ACA_ENV" -g "$RESOURCE_GROUP" >/dev/null 2>&1; then
      az containerapp env delete -n "$ACA_ENV" -g "$RESOURCE_GROUP" --yes
      echo "  Deleted: $ACA_ENV"
    else
      echo "  Not found: $ACA_ENV"
    fi

    echo "=> Deleting Log Analytics workspace (if exists): $LOG_WS"
    if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WS" >/dev/null 2>&1; then
      az monitor log-analytics workspace delete -g "$RESOURCE_GROUP" -n "$LOG_WS" --yes
      echo "  Deleted: $LOG_WS"
    else
      echo "  Not found: $LOG_WS"
    fi

    echo "=> Deleting ACR (if exists): $ACR_NAME"
    if az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" >/dev/null 2>&1; then
      az acr delete -n "$ACR_NAME" -g "$RESOURCE_GROUP" --yes
      echo "  Deleted: $ACR_NAME"
    else
      echo "  Not found: $ACR_NAME"
    fi

    echo ""
  done

  echo "----------------------------------------------"
  echo "  DELETE action completed"
  echo "----------------------------------------------"
  exit 0
fi

# If we reach here, ACTION == create
for ENV in "${ENVS[@]}"; do

  echo ""
  echo "----------------------------------------------"
  echo "         ENVIRONMENT: $ENV"
  echo "----------------------------------------------"

  ACR_NAME="messageappacr-${ENV}-susmitha"
  LOG_WS="messageapp-logs-${ENV}"
  ACA_ENV="messageapp-env-${ENV}"

  ###############################
  # CREATE ACR
  ###############################
  echo "➡ Checking ACR: $ACR_NAME"

  if ! az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "➡ Creating ACR: $ACR_NAME"
    az acr create \
      --name "$ACR_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --sku Basic \
      --admin-enabled true \
      --location "$LOCATION"
  else
    echo "✔ ACR already exists"
  fi

  ACR_LOGIN=$(az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query loginServer -o tsv)
  ACR_USERNAME=$(az acr credential show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query username -o tsv)
  ACR_PASSWORD=$(az acr credential show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query passwords[0].value -o tsv)

  echo "➡ ACR Login Server: $ACR_LOGIN"

  ###############################
  # ROLE ASSIGNMENT: AcrPull for deploy SP (optional but recommended)
  ###############################
  # If AZURE_DEPLOY_SP_APPID is provided (the clientId/appId of the SP used by GitHub Actions),
  # convert to the service principal objectId and assign AcrPull role on this ACR resource.
  if [[ -n "${AZURE_DEPLOY_SP_APPID:-}" ]]; then
    echo "➡ Attempting to assign AcrPull role to SP (appId=$AZURE_DEPLOY_SP_APPID) for ACR $ACR_NAME"
    # Try to get service principal object id from appId
    SP_OBJ_ID=$(az ad sp show --id "$AZURE_DEPLOY_SP_APPID" --query objectId -o tsv 2>/dev/null || true)
    if [[ -n "$SP_OBJ_ID" ]]; then
      ACR_ID=$(az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query id -o tsv)
      # assign AcrPull role (ignore if already exists)
      az role assignment create --assignee-object-id "$SP_OBJ_ID" --role AcrPull --scope "$ACR_ID" >/dev/null 2>&1 || \
        echo "  (Note) role assignment may already exist or you may lack permission to create it"
      echo "  Assigned AcrPull to SP (objectId=$SP_OBJ_ID) on $ACR_NAME"
    else
      echo "  Warning: could not find service principal object id for appId $AZURE_DEPLOY_SP_APPID. Skipping role assignment."
    fi
  else
    echo "  Info: AZURE_DEPLOY_SP_APPID not provided; skipping AcrPull role assignment. (You can still use ACR admin creds.)"
  fi

  ###############################
  # CREATE LOG ANALYTICS WORKSPACE
  ###############################
  echo "➡ Checking Log Analytics workspace for $ENV"

  if ! az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WS" >/dev/null 2>&1; then
    echo "➡ Creating Log Analytics workspace: $LOG_WS"
    az monitor log-analytics workspace create \
      -g "$RESOURCE_GROUP" -n "$LOG_WS" --location "$LOCATION"
  else
    echo "✔ Log Analytics already exists"
  fi

  WORKSPACE_ID=$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WS" --query customerId -o tsv)
  WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$RESOURCE_GROUP" -n "$LOG_WS" --query primarySharedKey -o tsv)

  ###############################
  # CREATE ACA ENVIRONMENT
  ###############################
  echo "➡ Checking ACA Environment: $ACA_ENV"

  if ! az containerapp env show -n "$ACA_ENV" -g "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "➡ Creating ACA Environment: $ACA_ENV"
    az containerapp env create \
      --name "$ACA_ENV" \
      --resource-group "$RESOURCE_GROUP" \
      --location "$LOCATION" \
      --logs-workspace-id "$WORKSPACE_ID" \
      --logs-workspace-key "$WORKSPACE_KEY"
  else
    echo "✔ ACA Environment already exists"
  fi

  ###############################
  # PRINT OUTPUT FOR GITHUB SECRETS
  ###############################
  echo ""
  echo "******* SAVE THESE VALUES TO GITHUB ENVIRONMENT: $ENV *******"
  echo "ACR_LOGIN_SERVER   = $ACR_LOGIN"
  echo "ACR_USERNAME       = $ACR_USERNAME"
  echo "ACR_PASSWORD       = $ACR_PASSWORD"
  echo "RESOURCE_GROUP     = $RESOURCE_GROUP"
  echo "LOG_WORKSPACE_ID   = $WORKSPACE_ID"
  echo "LOG_WORKSPACE_KEY  = $WORKSPACE_KEY"
  echo "*************************************************************"
  echo ""

done

echo "=============================================="
echo "  INFRASTRUCTURE SETUP COMPLETED SUCCESSFULLY "
echo "=============================================="
