#!/bin/bash

# Setup BigQuery Remote Functions for Vault Transform
# Creates remote functions that can encrypt/decrypt credit cards using our Cloud Function

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
PROJECT_ID=${PROJECT_ID:-"hc-5c7132af39e94c9ea03d2710265"}
REGION=${REGION:-"australia-southeast1"}
DATASET_NAME="fraud_detection"
FUNCTION_NAME="vault-transform-function"
CONNECTION_NAME="vault-transform-connection"

print_status "🔗 Setting up BigQuery Remote Functions for Vault Transform"

# Get Cloud Function URL
FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME \
    --region=$REGION \
    --format="value(serviceConfig.uri)" 2>/dev/null)

if [[ -z "$FUNCTION_URL" ]]; then
    print_error "Could not get Cloud Function URL for $FUNCTION_NAME"
    exit 1
fi

print_success "Found Cloud Function: $FUNCTION_URL"

# Create BigQuery connection for remote functions
print_status "Creating BigQuery connection: $CONNECTION_NAME"

# Check if connection exists
if bq show --connection --project_id=$PROJECT_ID --location=US $CONNECTION_NAME &> /dev/null; then
    print_warning "Connection $CONNECTION_NAME already exists"
else
    bq mk --connection \
        --display_name="Vault Transform Connection for encrypted credit cards" \
        --connection_type=CLOUD_RESOURCE \
        --location=US \
        --project_id=$PROJECT_ID \
        $CONNECTION_NAME
    
    print_success "Created connection: $CONNECTION_NAME"
fi

# Create remote function for encryption
print_status "Creating encrypt_credit_card remote function..."

bq query --use_legacy_sql=false << EOF
CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.${DATASET_NAME}.encrypt_credit_card\`(credit_card_number STRING)
RETURNS STRING
REMOTE WITH CONNECTION \`${PROJECT_ID}.US.${CONNECTION_NAME}\`
OPTIONS (
  endpoint = '${FUNCTION_URL}',
  description = 'Encrypt credit card number using Vault Transform FPE',
  max_batching_rows = 50
);
EOF

print_success "Created encrypt_credit_card function"

# Create remote function for decryption
print_status "Creating decrypt_credit_card remote function..."

bq query --use_legacy_sql=false << EOF
CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.${DATASET_NAME}.decrypt_credit_card\`(encrypted_credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION \`${PROJECT_ID}.US.${CONNECTION_NAME}\`
OPTIONS (
  endpoint = '${FUNCTION_URL}',
  description = 'Decrypt credit card number using Vault Transform FPE',
  max_batching_rows = 50,
  user_defined_context = [('mode', 'decrypt')]
);
EOF

print_success "Created decrypt_credit_card function"

# Test the functions
print_status "Testing remote functions..."

echo
echo "🔐 Testing Encryption Function:"
bq query --use_legacy_sql=false \
    "SELECT 
        '4111111111111111' as original_card,
        \`${PROJECT_ID}.${DATASET_NAME}.encrypt_credit_card\`('4111111111111111') as encrypted_card"

echo
echo "🔓 Testing Decryption Function:"
bq query --use_legacy_sql=false \
    "SELECT 
        encrypted_credit_card,
        \`${PROJECT_ID}.${DATASET_NAME}.decrypt_credit_card\`(encrypted_credit_card) as decrypted_card,
        merchant_name,
        amount
     FROM \`${PROJECT_ID}.${DATASET_NAME}.transactions\`
     LIMIT 3"

echo
echo "🔄 Testing Round-trip (Encrypt then Decrypt):"
bq query --use_legacy_sql=false \
    "SELECT 
        '5555555555554444' as original,
        \`${PROJECT_ID}.${DATASET_NAME}.decrypt_credit_card\`(
            \`${PROJECT_ID}.${DATASET_NAME}.encrypt_credit_card\`('5555555555554444')
        ) as round_trip_result"

print_success "🎉 BigQuery Remote Functions setup complete!"
echo
echo -e "${BLUE}📋 Example Queries:${NC}"
echo
echo "# Decrypt all credit cards for fraud analysis"
echo "bq query --use_legacy_sql=false \"
SELECT 
    \\\`${PROJECT_ID}.${DATASET_NAME}.decrypt_credit_card\\\`(encrypted_credit_card) as credit_card,
    merchant_name,
    amount,
    is_fraud
FROM \\\`${PROJECT_ID}.${DATASET_NAME}.transactions\\\`
WHERE is_fraud = true\""
echo
echo "# Find transactions for a specific credit card"
echo "bq query --use_legacy_sql=false \"
SELECT 
    transaction_id,
    merchant_name,
    amount,
    transaction_date
FROM \\\`${PROJECT_ID}.${DATASET_NAME}.transactions\\\`
WHERE encrypted_credit_card = \\\`${PROJECT_ID}.${DATASET_NAME}.encrypt_credit_card\\\`('4111111111111111')\""

echo
echo -e "${GREEN}✅ You can now query encrypted credit card data using real card numbers!${NC}"
