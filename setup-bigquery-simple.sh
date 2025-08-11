#!/bin/bash

# Simple BigQuery Setup with Pre-encrypted Credit Cards
# This uses known encrypted values from our Cloud Function

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
PROJECT_ID=${PROJECT_ID:-"hc-5c7132af39e94c9ea03d2710265"}
DATASET_NAME="fraud_detection"
TABLE_NAME="transactions"

print_status "🗃️  Setting up BigQuery with encrypted credit card data"

# First get a few encrypted values from our Cloud Function
print_status "Getting encrypted credit card values from Cloud Function..."

encrypt_card() {
    local card="$1"
    gcloud functions call vault-transform-function \
        --region=australia-southeast1 \
        --data="{\"calls\":[[\"$card\"]]}" \
        --format="value(result)" 2>/dev/null | \
        sed -n 's/.*"replies":\["\([^"]*\)"\].*/\1/p'
}

# Get encrypted values for our test cards
CARD1_ENCRYPTED=$(encrypt_card "4111111111111111")
CARD2_ENCRYPTED=$(encrypt_card "5555555555554444") 
CARD3_ENCRYPTED=$(encrypt_card "4222222222222222")

print_success "Encrypted card values:"
print_success "4111****1111 -> $CARD1_ENCRYPTED"
print_success "5555****4444 -> $CARD2_ENCRYPTED"
print_success "4222****2222 -> $CARD3_ENCRYPTED"

# Create the dataset (remove if exists)
print_status "Creating BigQuery dataset..."
bq rm -r -f ${PROJECT_ID}:${DATASET_NAME} 2>/dev/null || true

bq mk --dataset \
    --description="Fraud detection with encrypted credit cards" \
    --location=US \
    ${PROJECT_ID}:${DATASET_NAME}

print_success "Created dataset: $DATASET_NAME"

# Create table with schema
print_status "Creating transactions table..."

bq mk --table \
    --description="Credit card transactions with Vault-encrypted card numbers" \
    ${PROJECT_ID}:${DATASET_NAME}.${TABLE_NAME} \
    transaction_id:STRING,encrypted_credit_card:STRING,amount:NUMERIC,merchant_name:STRING,merchant_category:STRING,transaction_date:TIMESTAMP,location:STRING,is_fraud:BOOLEAN,card_type:STRING,created_at:TIMESTAMP

print_success "Created table: $TABLE_NAME"

# Create sample data file
print_status "Creating sample transaction data..."

cat > /tmp/sample_transactions.json << EOF
{"transaction_id": "TXN001", "encrypted_credit_card": "$CARD1_ENCRYPTED", "amount": 89.99, "merchant_name": "Amazon", "merchant_category": "E-commerce", "transaction_date": "2024-11-01T14:30:00", "location": "Online", "is_fraud": false, "card_type": "Visa", "created_at": "2024-11-11T10:00:00"}
{"transaction_id": "TXN002", "encrypted_credit_card": "$CARD2_ENCRYPTED", "amount": 1299.99, "merchant_name": "Best Buy", "merchant_category": "Electronics", "transaction_date": "2024-11-02T16:45:00", "location": "New York, NY", "is_fraud": false, "card_type": "Mastercard", "created_at": "2024-11-11T10:00:00"}
{"transaction_id": "TXN003", "encrypted_credit_card": "$CARD3_ENCRYPTED", "amount": 45.67, "merchant_name": "Starbucks", "merchant_category": "Food & Beverage", "transaction_date": "2024-11-03T08:15:00", "location": "San Francisco, CA", "is_fraud": false, "card_type": "Visa", "created_at": "2024-11-11T10:00:00"}
{"transaction_id": "TXN004", "encrypted_credit_card": "$CARD1_ENCRYPTED", "amount": 25000.00, "merchant_name": "Suspicious Electronics Store", "merchant_category": "Electronics", "transaction_date": "2024-11-03T23:59:00", "location": "Unknown Location", "is_fraud": true, "card_type": "Visa", "created_at": "2024-11-11T10:00:00"}
{"transaction_id": "TXN005", "encrypted_credit_card": "$CARD2_ENCRYPTED", "amount": 199.99, "merchant_name": "Target", "merchant_category": "Retail", "transaction_date": "2024-11-04T12:30:00", "location": "Chicago, IL", "is_fraud": false, "card_type": "Mastercard", "created_at": "2024-11-11T10:00:00"}
{"transaction_id": "TXN006", "encrypted_credit_card": "$CARD3_ENCRYPTED", "amount": 8999.99, "merchant_name": "Legitimate Jewelry Store", "merchant_category": "Luxury Goods", "transaction_date": "2024-11-05T15:20:00", "location": "Beverly Hills, CA", "is_fraud": false, "card_type": "Visa", "created_at": "2024-11-11T10:00:00"}
{"transaction_id": "TXN007", "encrypted_credit_card": "$CARD1_ENCRYPTED", "amount": 15.99, "merchant_name": "Netflix", "merchant_category": "Subscription", "transaction_date": "2024-11-06T19:30:00", "location": "Online", "is_fraud": false, "card_type": "Visa", "created_at": "2024-11-11T10:00:00"}
{"transaction_id": "TXN008", "encrypted_credit_card": "$CARD2_ENCRYPTED", "amount": 750.00, "merchant_name": "Gas Station", "merchant_category": "Fuel", "transaction_date": "2024-11-07T07:45:00", "location": "Highway Rest Stop", "is_fraud": true, "card_type": "Mastercard", "created_at": "2024-11-11T10:00:00"}
{"transaction_id": "TXN009", "encrypted_credit_card": "$CARD3_ENCRYPTED", "amount": 125.50, "merchant_name": "Grocery Store", "merchant_category": "Grocery", "transaction_date": "2024-11-08T18:20:00", "location": "Local Market", "is_fraud": false, "card_type": "Visa", "created_at": "2024-11-11T10:00:00"}
{"transaction_id": "TXN010", "encrypted_credit_card": "$CARD1_ENCRYPTED", "amount": 3500.00, "merchant_name": "Apple Store", "merchant_category": "Electronics", "transaction_date": "2024-11-09T14:10:00", "location": "Mall Store", "is_fraud": false, "card_type": "Visa", "created_at": "2024-11-11T10:00:00"}
EOF

# Load data into BigQuery
print_status "Loading sample data into BigQuery..."

bq load \
    --source_format=NEWLINE_DELIMITED_JSON \
    ${PROJECT_ID}:${DATASET_NAME}.${TABLE_NAME} \
    /tmp/sample_transactions.json

print_success "Loaded sample transaction data"

# Verify data
print_status "Verifying loaded data..."

echo
echo "📊 Transaction Summary:"
bq query --use_legacy_sql=false --format=table \
    "SELECT 
        card_type,
        COUNT(*) as transaction_count,
        ROUND(SUM(amount), 2) as total_amount,
        ROUND(AVG(amount), 2) as avg_amount
     FROM \`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\`
     GROUP BY card_type
     ORDER BY total_amount DESC"

echo
echo "🚨 Fraud Summary:"
bq query --use_legacy_sql=false --format=table \
    "SELECT 
        is_fraud,
        COUNT(*) as transaction_count,
        ROUND(SUM(amount), 2) as total_amount
     FROM \`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\`
     GROUP BY is_fraud"

# Clean up
rm -f /tmp/sample_transactions.json

print_success "🎉 BigQuery setup complete!"
echo
echo -e "${BLUE}📋 Quick Test Commands:${NC}"
echo
echo "# View all transactions"
echo "bq query --use_legacy_sql=false \"SELECT * FROM \\\`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\\\`\""
echo
echo "# Test decryption (requires remote function setup)"
echo "# First create remote function, then:"
echo "# bq query --use_legacy_sql=false \"SELECT encrypted_credit_card, decrypt_credit_card(encrypted_credit_card) FROM \\\`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\\\` LIMIT 3\""

echo
echo -e "${GREEN}✅ Your BigQuery dataset is ready with encrypted credit card data!${NC}"
