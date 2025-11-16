#!/bin/bash

# ==============================================================================
# Final Lifecycle Deployment Script for the Message Application
#
# Usage:
#   ./deploy.sh       (Creates/Updates the entire Azure deployment)
#   ./deploy.sh -d    (Deletes the entire Resource Group)
# ==============================================================================

# --- Script Configuration ---
set -e

SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="centralindia"
ACR_NAME="messageappacr"
ACA_ENV_NAME="message-app-environment" # This will create a new env
BACKEND_APP_NAME="message-app-backend"
FRONTEND_APP_NAME="message-app-frontend"

IMAGE_VERSION="v1.3" # Incremented version for the final backend fix


# --- Function to Create/Update the Full Deployment ---
perform_deployment() {
    echo "
###########################################################
Azure Deployment (Create/Update Mode)
###########################################################
"

    # Steps 1-5 remain the same...
    echo "--> Setting active Azure Subscription..."
    az account set --subscription "$SUBSCRIPTION_NAME"
    echo "OK: Subscription set."
    echo "==================================================================================="
    echo "--> Verifying Resource Group '$RESOURCE_GROUP'..."
    if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
        echo "ACTION: Creating Resource Group '$RESOURCE_GROUP' in '$LOCATION'..."
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    fi
    echo "OK: Resource Group is ready."
    echo "==================================================================================="
    echo "--> Verifying Azure Container Registry '$ACR_NAME'..."
    if ! az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        echo "ACTION: Creating ACR '$ACR_NAME'..."
        az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic --admin-enabled true
    fi
    ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query "loginServer" -o tsv)
    echo "OK: ACR is ready at '$ACR_LOGIN_SERVER'."
    echo "==================================================================================="
    echo "--> Building and Pushing Docker Images..."
    az acr login --name "$ACR_NAME"
    docker build -t "$BACKEND_APP_NAME" ./backend
    docker tag "$BACKEND_APP_NAME" "$ACR_LOGIN_SERVER/$BACKEND_APP_NAME:$IMAGE_VERSION"
    docker push "$ACR_LOGIN_SERVER/$BACKEND_APP_NAME:$IMAGE_VERSION"
    docker build -t "$FRONTEND_APP_NAME" ./frontend
    docker tag "$FRONTEND_APP_NAME" "$ACR_LOGIN_SERVER/$FRONTEND_APP_NAME:$IMAGE_VERSION"
    docker push "$ACR_LOGIN_SERVER/$FRONTEND_APP_NAME:$IMAGE_VERSION"
    echo "OK: All images pushed successfully."
    echo "==================================================================================="
    echo "--> Verifying Container App Environment '$ACA_ENV_NAME'..."
    if ! az containerapp env show --name "$ACA_ENV_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        echo "ACTION: Creating Container App Environment '$ACA_ENV_NAME'..."
        az containerapp env create --name "$ACA_ENV_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION"
    fi
    echo "OK: Container App Environment is ready."
    echo "==================================================================================="

    # Step 6: Deploy Backend App (Create then Update)
    echo "--> Deploying Backend App '$BACKEND_APP_NAME'..."
    if az containerapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
       echo "INFO: Backend app exists. Updating image..."
       az containerapp update --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" \
        --image "$ACR_LOGIN_SERVER/$BACKEND_APP_NAME:$IMAGE_VERSION"
    else
        echo "ACTION: Creating backend app..."
        az containerapp create \
          --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --environment "$ACA_ENV_NAME" \
          --image "$ACR_LOGIN_SERVER/$BACKEND_APP_NAME:$IMAGE_VERSION" --registry-server "$ACR_LOGIN_SERVER" \
          --target-port 8080 --ingress internal
    fi
    az containerapp update --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" \
        --set-env-vars JAVA_TOOL_OPTIONS=-Duser.timezone=Asia/Calcutta
 
    BACKEND_URL=$(az containerapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv)
    echo "OK: Backend is deployed. Internal URL is https://$BACKEND_URL" # Changed for clarity
    echo "==================================================================================="
    
    # Step 7 remains the same...
    echo "--> Deploying Frontend App '$FRONTEND_APP_NAME'..."
    if az containerapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        echo "INFO: Frontend app exists. Updating to new image and setting backend URL..."
        az containerapp update --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" \
          --image "$ACR_LOGIN_SERVER/$FRONTEND_APP_NAME:$IMAGE_VERSION" \
          --set-env-vars "BACKEND_URL=https://$BACKEND_URL"
    else
        echo "ACTION: Creating frontend app..."
        az containerapp create --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --environment "$ACA_ENV_NAME" \
          --image "$ACR_LOGIN_SERVER/$FRONTEND_APP_NAME:$IMAGE_VERSION" --registry-server "$ACR_LOGIN_SERVER" \
          --target-port 80 --ingress external
        
        echo "ACTION: Configuring frontend to connect to backend..."
        az containerapp update --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" \
          --set-env-vars "BACKEND_URL=https://$BACKEND_URL"
    fi
    FRONTEND_URL=$(az containerapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv)
    echo "OK: Frontend deployed successfully."
    echo "==================================================================================="

    echo "
###########################################################
###      DEPLOYMENT SCRIPT COMPLETED
###########################################################
"
    echo "Your application is accessible at:"
    echo "  https://$FRONTEND_URL"
    echo ""
}

# --- Deletion function remains the same ---
perform_deletion() {
    echo "
###########################################################
Azure Resource Cleanup (Delete Mode)
###########################################################
"
    echo "WARNING: This will delete the ENTIRE resource group '$RESOURCE_GROUP' and all deployed resources within it."
    echo "This action is irreversible."
    echo ""
    read -p "Are you sure you want to delete all resources? Type 'yes' to confirm: " response
    if [[ "$response" == "yes" ]]; then
        echo "ACTION: Deleting Resource Group '$RESOURCE_GROUP'..."
        az group delete --name "$RESOURCE_GROUP" --yes --no-wait
        echo "OK: Deletion initiated. It may take several minutes to complete in Azure."
    else
        echo "INFO: Deletion cancelled."
    fi
    echo "======================================================================================"
}

# --- Main Logic remains the same ---
if [[ "$1" == "-d" ]]; then
    perform_deletion
else
    perform_deployment
fi