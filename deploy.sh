#!/bin/bash

# Deploy script for Google Cloud Function
# Make sure you have gcloud CLI installed and authenticated
# This script loads configuration from .env file

set -e

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "❌ .env file not found! Please create it from .env.example"
    exit 1
fi

# Use environment variables or defaults
PROJECT_ID=${PROJECT_ID:-"your-project-id"}
FUNCTION_NAME=${FUNCTION_NAME:-"vault-transform-bigquery"}
REGION=${REGION:-"us-central1"}
MEMORY=${MEMORY:-"512MB"}
TIMEOUT=${TIMEOUT:-"60s"}

# Vault configuration - use production settings if available
VAULT_URL=${PROD_VAULT_URL:-${VAULT_ADDR:-"https://your-vault-instance.com"}}
VAULT_TOKEN=${PROD_VAULT_TOKEN:-${VAULT_TOKEN:-"your-vault-token"}}
VAULT_NAMESPACE=${PROD_VAULT_NAMESPACE:-${VAULT_NAMESPACE:-""}}
VAULT_TRANSFORM_ROLE=${VAULT_TRANSFORM_ROLE:-"creditcard-transform"}

echo "Deploying Google Cloud Function: $FUNCTION_NAME"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Vault URL: $VAULT_URL"

gcloud functions deploy $FUNCTION_NAME \
  --gen2 \
  --runtime=python311 \
  --region=$REGION \
  --source=. \
  --entry-point=vault_transform_bigquery \
  --trigger=http \
  --allow-unauthenticated \
  --memory=$MEMORY \
  --timeout=$TIMEOUT \
  --set-env-vars="VAULT_URL=$VAULT_URL,VAULT_TOKEN=$VAULT_TOKEN,VAULT_NAMESPACE=$VAULT_NAMESPACE,VAULT_TRANSFORM_ROLE=$VAULT_TRANSFORM_ROLE" \
  --project=$PROJECT_ID

echo "Deployment complete!"
echo "Function URL will be displayed above. Use it to create BigQuery remote functions."
