#!/bin/bash

# This single script is responsible for CREATING or DESTROYING the core Azure infrastructure.
# It does NOT delete the resource group itself.

set -e # Exit immediately if a command fails

# --- The action (create or destroy) must be passed as the first argument ---
ACTION=$1

if [[ "$ACTION" != "create" && "$ACTION" != "destroy" ]]; then
  echo "Error: Invalid action specified. Usage: $0 <create|destroy>"
  exit 1
fi

# --- Configuration (from environment variables) ---
: "${SUBSCRIPTION_NAME?SUBSCRIPTION_NAME is not set. Please provide it as an environment variable.}"
: "${RESOURCE_GROUP?RESOURCE_GROUP is not set. Please provide it as an environment variable.}"
: "${LOCATION?LOCATION is not set. Please provide it as an environment variable.}"
: "${ACR_NAME?ACR_NAME is not set. Please provide it as an environment variable.}"

# --- Common Tag for Resource Identification ---
MANAGED_BY_TAG="managed-by=github-actions"

echo "
###########################################################
###   Azure Infrastructure Management
###
###   Action:         $ACTION
###   Subscription:   $SUBSCRIPTION_NAME
###   Resource Group: $RESOURCE_GROUP
###########################################################
"
echo "--> Setting active Azure Subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"
echo "OK: Subscription set."

# --- FIX: Clear any default resource group configuration to prevent CLI conflicts ---
echo "--> Clearing any default resource group configuration..."
az configure --defaults group=""
echo "OK: Default group cleared."

echo "==================================================================================="


# --- Main Logic: Execute action based on the input argument ---

case "$ACTION" in
  create)
    # --- NO CHANGES IN THE CREATE BLOCK ---
    echo "Starting resource creation..."
    echo "--> Verifying Resource Group '$RESOURCE_GROUP'..."
    if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
        echo "INFO: Resource Group '$RESOURCE_GROUP' already exists."
    else
        echo "ACTION: Creating Resource Group '$RESOURCE_GROUP' in '$LOCATION'..."
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        echo "OK: Resource Group created."
    fi
    echo "-----------------------------------------------------------"
    echo "--> Verifying Azure Container Registry '$ACR_NAME'..."
    if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        echo "INFO: ACR '$ACR_NAME' already exists."
    else
        echo "ACTION: Creating ACR '$ACR_NAME' and tagging it..."
        az acr create \
          --resource-group "$RESOURCE_GROUP" \
          --name "$ACR_NAME" \
          --sku Basic \
          --admin-enabled true \
          --tags "$MANAGED_BY_TAG"
        echo "OK: ACR created."
    fi
    echo "
###########################################################
###   Infrastructure creation is complete.
###########################################################
"
    ;;

  destroy)
    # --- THIS IS THE UPDATED DESTROY BLOCK ---
    echo "Starting resource destruction..."
    echo "--> Finding all resources in '$RESOURCE_GROUP' with tag '$MANAGED_BY_TAG'..."
    RESOURCE_IDS=$(az resource list --resource-group "$RESOURCE_GROUP" --query "[?tags.\"managed-by\" == 'github-actions'].id" -o tsv)

    if [ -z "$RESOURCE_IDS" ]; then
        echo "INFO: No resources found with the tag '$MANAGED_BY_TAG'. Nothing to delete."
    else
        echo "ACTION: The following resources will be deleted:"
        az resource list --resource-group "$RESOURCE_GROUP" --query "[?tags.\"managed-by\" == 'github-actions'].name" -o tsv | xargs -I {} echo "  - {}"

        echo "Proceeding with deletion..."
        # THE FIX IS HERE: Removed the '--yes' argument from the line below.
        az resource delete --ids $RESOURCE_IDS
        echo "OK: Deletion of tagged resources is complete."
    fi
    echo "
###########################################################
###   Resource destruction is complete. The resource group '$RESOURCE_GROUP' was NOT deleted.
###########################################################
"
    ;;
esac