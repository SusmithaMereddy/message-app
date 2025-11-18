#!/bin/bash

# This script is responsible for creating the core Azure infrastructure.
# It does NOT deploy any application code.

set -e # Exit immediately if a command fails

# --- Configuration ---
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="centralindia"
ACR_NAME="messageappacr"

echo "
###########################################################
###   Azure Infrastructure Setup
###########################################################
"
echo "--> Setting active Azure Subscription..."
    az account set --subscription "$SUBSCRIPTION_NAME"
    echo "OK: Subscription set."
    echo "==================================================================================="
echo "--> Verifying Resource Group '$RESOURCE_GROUP'..."
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "INFO: Resource Group '$RESOURCE_GROUP' already exists."
else
    echo "ACTION: Creating Resource Group '$RESOURCE_GROUP' in '$LOCATION'..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo "OK: Resource Group created."
fi
echo "==========================================================="

echo "--> Verifying Azure Container Registry '$ACR_NAME'..."
if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "INFO: ACR '$ACR_NAME' already exists."
else
    echo "ACTION: Creating ACR '$ACR_NAME'..."
    az acr create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$ACR_NAME" \
      --sku Basic \
      --admin-enabled true
    echo "OK: ACR created."
fi
echo "==========================================================="

echo "
###########################################################
###   Infrastructure setup is complete.
###########################################################
"