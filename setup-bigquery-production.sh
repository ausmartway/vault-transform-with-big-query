#!/bin/bash

# Production BigQuery Setup Script
# Creates BigQuery dataset with encrypted credit card transaction data
# Uses the deployed Cloud Function for real encryption

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo
    echo -e "${BLUE}==================================="
    echo -e "🗃️  $1"
    echo -e "===================================${NC}"
    echo
}

# Load environment variables
if [[ -f .env ]]; then
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
PROJECT_ID=${PROJECT_ID:-"hc-5c7132af39e94c9ea03d2710265"}
REGION=${REGION:-"australia-southeast1"}
DATASET_NAME="fraud_detection"
TABLE_NAME="transactions"
FUNCTION_NAME="vault-transform-function"

print_header "BigQuery Production Setup"

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check gcloud CLI
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Check bq CLI
    if ! command -v bq &> /dev/null; then
        print_error "bq CLI not found. Please install Google Cloud SDK with BigQuery components."
        exit 1
    fi
    
    # Check authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null; then
        print_error "Not authenticated with gcloud. Run: gcloud auth login"
        exit 1
    fi
    
    # Set project
    if ! gcloud config set project $PROJECT_ID > /dev/null 2>&1; then
        print_error "Failed to set project $PROJECT_ID"
        exit 1
    fi
    
    print_success "Prerequisites verified"
}

# Enable required APIs
enable_apis() {
    print_status "Enabling required Google Cloud APIs..."
    
    local apis=(
        "bigquery.googleapis.com"
        "cloudfunctions.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_status "Enabling $api..."
        if gcloud services enable $api --project=$PROJECT_ID; then
            print_success "Enabled $api"
        else
            print_warning "API $api might already be enabled or failed to enable"
        fi
    done
}

# Encrypt credit card using Cloud Function
encrypt_credit_card() {
    local card_number="$1"
    
    print_status "Encrypting credit card: ${card_number:0:4}****${card_number:(-4)}"
    
    # Call the Cloud Function to encrypt
    local response=$(gcloud functions call $FUNCTION_NAME \
        --region=$REGION \
        --data="{\"calls\":[[\"$card_number\"]]}" \
        --format="value(result)" 2>/dev/null | grep -v '^|')
    
    if [[ -z "$response" ]]; then
        print_error "Failed to encrypt credit card"
        return 1
    fi
    
    # Extract encrypted value from response using jq
    local encrypted
    if command -v jq >/dev/null 2>&1; then
        encrypted=$(echo "$response" | jq -r '.replies[0]' 2>/dev/null)
    else
        # Fallback without jq - extract using sed/grep
        encrypted=$(echo "$response" | sed -n 's/.*"replies":\["\([^"]*\)"\].*/\1/p')
    fi
    
    if [[ "$encrypted" == "null" || -z "$encrypted" ]]; then
        print_error "Invalid encryption response: $response"
        return 1
    fi
    
    echo "$encrypted"
}

# Create BigQuery dataset
create_dataset() {
    print_status "Creating BigQuery dataset: $DATASET_NAME"
    
    # Check if dataset exists
    if bq ls -d ${PROJECT_ID}:${DATASET_NAME} &> /dev/null; then
        print_warning "Dataset $DATASET_NAME already exists - continuing with existing dataset"
        return 0
    fi
    
    # Create dataset
    if bq mk --dataset \
        --description="Production fraud detection dataset with encrypted credit cards" \
        --location=US \
        --default_table_expiration=86400 \
        ${PROJECT_ID}:${DATASET_NAME} 2>/dev/null; then
        print_success "Created dataset: $DATASET_NAME"
    else
        # Check again if it exists (race condition)
        if bq ls -d ${PROJECT_ID}:${DATASET_NAME} &> /dev/null; then
            print_warning "Dataset $DATASET_NAME already exists - continuing"
            return 0
        else
            print_error "Failed to create dataset"
            return 1
        fi
    fi
}

# Create transactions table
create_table() {
    print_status "Creating BigQuery table: $TABLE_NAME"
    
    # Create table schema file
    cat > /tmp/transactions_schema.json << 'EOF'
[
    {
        "name": "transaction_id",
        "type": "STRING",
        "mode": "REQUIRED",
        "description": "Unique identifier for the transaction"
    },
    {
        "name": "encrypted_credit_card",
        "type": "STRING",
        "mode": "REQUIRED",
        "description": "Credit card number encrypted using Vault Transform"
    },
    {
        "name": "amount",
        "type": "NUMERIC",
        "mode": "REQUIRED",
        "description": "Transaction amount in USD"
    },
    {
        "name": "merchant_name",
        "type": "STRING",
        "mode": "REQUIRED",
        "description": "Name of the merchant"
    },
    {
        "name": "merchant_category",
        "type": "STRING",
        "mode": "NULLABLE",
        "description": "Category of the merchant"
    },
    {
        "name": "transaction_date",
        "type": "TIMESTAMP",
        "mode": "REQUIRED",
        "description": "Date and time of the transaction"
    },
    {
        "name": "location",
        "type": "STRING",
        "mode": "NULLABLE",
        "description": "Transaction location"
    },
    {
        "name": "is_fraud",
        "type": "BOOLEAN",
        "mode": "NULLABLE",
        "description": "Whether the transaction is flagged as fraudulent"
    },
    {
        "name": "card_type",
        "type": "STRING",
        "mode": "NULLABLE",
        "description": "Type of credit card (Visa, Mastercard, etc.)"
    },
    {
        "name": "created_at",
        "type": "TIMESTAMP",
        "mode": "REQUIRED",
        "description": "When the record was created"
    }
]
EOF

    # Check if table exists
    if bq show ${PROJECT_ID}:${DATASET_NAME}.${TABLE_NAME} &> /dev/null; then
        print_warning "Table $TABLE_NAME already exists"
        
        # Ask user if they want to recreate
        echo -n "Do you want to delete and recreate the table? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            bq rm -f ${PROJECT_ID}:${DATASET_NAME}.${TABLE_NAME}
            print_status "Deleted existing table"
        else
            print_status "Keeping existing table"
            return 0
        fi
    fi
    
    # Create table
    if bq mk --table \
        --description="Credit card transactions with encrypted card numbers" \
        --schema=/tmp/transactions_schema.json \
        ${PROJECT_ID}:${DATASET_NAME}.${TABLE_NAME}; then
        print_success "Created table: $TABLE_NAME"
    else
        print_error "Failed to create table"
        return 1
    fi
    
    # Clean up
    rm -f /tmp/transactions_schema.json
}

# Generate sample transaction data with real encryption
insert_sample_data() {
    print_status "Generating sample transaction data with real encryption..."
    
    # Sample credit card numbers (test cards)
    local credit_cards=(
        "4111111111111111"  # Visa
        "5555555555554444"  # Mastercard  
        "4222222222222222"  # Visa
        "6011111111111117"  # Discover
        "3782822463100005"  # Amex
        "4000000000000002"  # Visa
    )
    
    # Sample merchants and categories
    local merchants=(
        "Amazon:E-commerce"
        "Starbucks:Food & Beverage"
        "Shell:Gas Station"
        "Target:Retail"
        "Best Buy:Electronics"
        "McDonald's:Fast Food"
        "Walmart:Retail"
        "Apple Store:Electronics"
        "Netflix:Subscription"
        "Uber:Transportation"
        "Hotels.com:Travel"
        "Home Depot:Home Improvement"
    )
    
    # Sample locations
    local locations=(
        "New York, NY"
        "Los Angeles, CA"
        "Chicago, IL"
        "Houston, TX"
        "Phoenix, AZ"
        "Philadelphia, PA"
        "San Antonio, TX"
        "San Diego, CA"
        "Dallas, TX"
        "San Jose, CA"
        "Austin, TX"
        "Jacksonville, FL"
        "Online"
        "Mobile App"
    )
    
    print_status "Encrypting credit card numbers using Cloud Function..."
    
    # Encrypt all credit cards first
    local encrypted_cards=()
    local card_types=()
    
    for card in "${credit_cards[@]}"; do
        local encrypted=$(encrypt_credit_card "$card")
        if [[ $? -eq 0 && -n "$encrypted" ]]; then
            encrypted_cards+=("$encrypted")
            
            # Determine card type
            case "${card:0:1}" in
                "4") card_types+=("Visa") ;;
                "5") card_types+=("Mastercard") ;;
                "3") card_types+=("American Express") ;;
                "6") card_types+=("Discover") ;;
                *) card_types+=("Unknown") ;;
            esac
            
            print_success "Encrypted: ${card:0:4}****${card:(-4)} -> ${encrypted:0:4}****${encrypted:(-4)}"
        else
            print_error "Failed to encrypt card: ${card:0:4}****${card:(-4)}"
            return 1
        fi
    done
    
    print_status "Generating transaction records..."
    
    # Create JSONL file for bulk insert
    local data_file="/tmp/transactions_data.jsonl"
    > "$data_file"  # Clear file
    
    # Generate transactions
    local base_timestamp=$(date -v-30d +%s)
    
    for i in {1..50}; do
        # Random selections
        local card_index=$((RANDOM % ${#encrypted_cards[@]}))
        local merchant_info="${merchants[$((RANDOM % ${#merchants[@]}))]}"
        local merchant_name="${merchant_info%%:*}"
        local merchant_category="${merchant_info##*:}"
        local location="${locations[$((RANDOM % ${#locations[@]}))]}"
        
        # Random transaction details (macOS date format)
        local days_offset=$((RANDOM % 30))
        local hours_offset=$((RANDOM % 24))
        local minutes_offset=$((RANDOM % 60))
        local timestamp=$((base_timestamp + days_offset * 86400 + hours_offset * 3600 + minutes_offset * 60))
        local transaction_date=$(date -r "$timestamp" -u '+%Y-%m-%dT%H:%M:%SZ')
        
        # Random amount (using awk instead of bc)
        local amount_type=$((RANDOM % 100))
        if [[ $amount_type -lt 60 ]]; then
            # Small amounts (60% chance)
            local amount=$(awk "BEGIN {printf \"%.2f\", $((RANDOM % 20000)) / 100}")
        elif [[ $amount_type -lt 85 ]]; then
            # Medium amounts (25% chance)
            local amount=$(awk "BEGIN {printf \"%.2f\", ($((RANDOM % 50000)) + 20000) / 100}")
        else
            # Large amounts (15% chance)
            local amount=$(awk "BEGIN {printf \"%.2f\", ($((RANDOM % 100000)) + 70000) / 100}")
        fi
        
        # Fraud detection logic
        local is_fraud="false"
        if [[ $(awk "BEGIN {print ($amount > 5000) ? 1 : 0}") -eq 1 && $((RANDOM % 100)) -lt 20 ]]; then
            is_fraud="true"  # 20% chance of fraud for amounts > $5000
        elif [[ "$merchant_category" == "Unknown" || "$location" == "Unknown" ]]; then
            is_fraud="true"  # Suspicious unknown merchants/locations
        elif [[ $((RANDOM % 100)) -lt 3 ]]; then
            is_fraud="true"  # 3% random fraud rate
        fi
        
        local current_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
        
        # Create JSON record (properly formatted)
        cat >> "$data_file" << EOF
{"transaction_id": "TXN$(printf "%04d" $i)", "encrypted_credit_card": "${encrypted_cards[$card_index]}", "amount": $amount, "merchant_name": "$merchant_name", "merchant_category": "$merchant_category", "transaction_date": "$transaction_date", "location": "$location", "is_fraud": $is_fraud, "card_type": "${card_types[$card_index]}", "created_at": "$current_timestamp"}
EOF
    done
    
    print_status "Inserting $i transactions into BigQuery..."
    
    # Insert data using bq load
    if bq load \
        --source_format=NEWLINE_DELIMITED_JSON \
        --replace \
        ${PROJECT_ID}:${DATASET_NAME}.${TABLE_NAME} \
        "$data_file"; then
        print_success "Inserted $i transactions successfully"
    else
        print_error "Failed to insert transaction data"
        return 1
    fi
    
    # Clean up
    rm -f "$data_file"
}

# Verify data and run sample queries
verify_data() {
    print_status "Verifying inserted data..."
    
    # Get row count
    local row_count=$(bq query --use_legacy_sql=false --format=csv --max_rows=1 \
        "SELECT COUNT(*) as count FROM \`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\`" | tail -n 1)
    
    print_success "Total transactions: $row_count"
    
    # Sample queries
    print_status "Running sample verification queries..."
    
    echo
    echo "📊 Transaction Summary by Card Type:"
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
            ROUND(SUM(amount), 2) as total_amount,
            ROUND(AVG(amount), 2) as avg_amount
         FROM \`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\`
         GROUP BY is_fraud
         ORDER BY is_fraud DESC"
    
    echo
    echo "🏪 Top Merchants by Volume:"
    bq query --use_legacy_sql=false --format=table --max_rows=10 \
        "SELECT 
            merchant_name,
            merchant_category,
            COUNT(*) as transaction_count,
            ROUND(SUM(amount), 2) as total_amount
         FROM \`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\`
         GROUP BY merchant_name, merchant_category
         ORDER BY total_amount DESC
         LIMIT 10"
}

# Create BigQuery remote function for encryption
create_remote_functions() {
    print_status "Creating BigQuery remote functions..."
    
    # Get Cloud Function URL
    local function_url=$(gcloud functions describe $FUNCTION_NAME \
        --region=$REGION \
        --format="value(serviceConfig.uri)" 2>/dev/null)
    
    if [[ -z "$function_url" ]]; then
        print_error "Could not get Cloud Function URL"
        return 1
    fi
    
    print_status "Using Cloud Function URL: $function_url"
    
    # Create connection if it doesn't exist
    local connection_name="vault-transform-connection"
    
    if ! bq show --connection --project_id=$PROJECT_ID --location=US $connection_name &> /dev/null; then
        print_status "Creating BigQuery connection: $connection_name"
        
        bq mk --connection \
            --display_name="Vault Transform Connection" \
            --connection_type=CLOUD_RESOURCE \
            --location=US \
            --project_id=$PROJECT_ID \
            $connection_name
        
        print_success "Created connection: $connection_name"
    else
        print_warning "Connection $connection_name already exists"
    fi
    
    # Create remote function for encryption
    local encrypt_function_sql="
CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.${DATASET_NAME}.encrypt_credit_card\`(credit_card_number STRING)
RETURNS STRING
REMOTE WITH CONNECTION \`${PROJECT_ID}.US.${connection_name}\`
OPTIONS (
  endpoint = '${function_url}',
  description = 'Encrypt credit card number using Vault Transform',
  max_batching_rows = 100
);
"
    
    # Create remote function for decryption
    local decrypt_function_sql="
CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.${DATASET_NAME}.decrypt_credit_card\`(encrypted_credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION \`${PROJECT_ID}.US.${connection_name}\`
OPTIONS (
  endpoint = '${function_url}',
  description = 'Decrypt credit card number using Vault Transform',
  max_batching_rows = 100,
  user_defined_context = [('mode', 'decrypt')]
);
"
    
    print_status "Creating encrypt_credit_card function..."
    if echo "$encrypt_function_sql" | bq query --use_legacy_sql=false; then
        print_success "Created encrypt_credit_card function"
    else
        print_error "Failed to create encrypt_credit_card function"
    fi
    
    print_status "Creating decrypt_credit_card function..."
    if echo "$decrypt_function_sql" | bq query --use_legacy_sql=false; then
        print_success "Created decrypt_credit_card function"
    else
        print_error "Failed to create decrypt_credit_card function"
    fi
}

# Test remote functions
test_remote_functions() {
    print_status "Testing BigQuery remote functions..."
    
    echo
    echo "🔐 Testing encryption function:"
    bq query --use_legacy_sql=false --format=table \
        "SELECT 
            '4111111111111111' as original_card,
            \`${PROJECT_ID}.${DATASET_NAME}.encrypt_credit_card\`('4111111111111111') as encrypted_card"
    
    echo
    echo "🔓 Testing decryption function with encrypted data from table:"
    bq query --use_legacy_sql=false --format=table --max_rows=3 \
        "SELECT 
            encrypted_credit_card,
            \`${PROJECT_ID}.${DATASET_NAME}.decrypt_credit_card\`(encrypted_credit_card) as decrypted_card,
            merchant_name,
            amount
         FROM \`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\`
         LIMIT 3"
}

# Display summary and next steps
show_summary() {
    print_header "Setup Complete!"
    
    echo -e "${GREEN}✅ BigQuery Dataset Created:${NC} ${PROJECT_ID}.${DATASET_NAME}"
    echo -e "${GREEN}✅ Transactions Table:${NC} ${TABLE_NAME} (with encrypted credit cards)"
    echo -e "${GREEN}✅ Remote Functions:${NC} encrypt_credit_card(), decrypt_credit_card()"
    echo -e "${GREEN}✅ Sample Data:${NC} 50 realistic transactions with Vault-encrypted credit cards"
    
    echo
    echo -e "${BLUE}📊 Quick Access Commands:${NC}"
    echo
    echo "# View all transactions"
    echo "bq query --use_legacy_sql=false \"SELECT * FROM \\\`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\\\` LIMIT 10\""
    echo
    echo "# Test encryption"
    echo "bq query --use_legacy_sql=false \"SELECT \\\`${PROJECT_ID}.${DATASET_NAME}.encrypt_credit_card\\\`('4111111111111111')\""
    echo
    echo "# Test decryption"
    echo "bq query --use_legacy_sql=false \"SELECT encrypted_credit_card, \\\`${PROJECT_ID}.${DATASET_NAME}.decrypt_credit_card\\\`(encrypted_credit_card) FROM \\\`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\\\` LIMIT 5\""
    echo
    echo "# Fraud detection query"
    echo "bq query --use_legacy_sql=false \"SELECT merchant_name, COUNT(*) as fraud_count FROM \\\`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\\\` WHERE is_fraud = true GROUP BY merchant_name\""
    
    echo
    echo -e "${YELLOW}🔗 Next Steps:${NC}"
    echo "1. Explore the data in BigQuery console: https://console.cloud.google.com/bigquery"
    echo "2. Test encryption/decryption with remote functions"
    echo "3. Build fraud detection models using encrypted data"
    echo "4. Create dashboards and alerts"
    
    echo
    echo -e "${GREEN}🎉 Your production BigQuery setup with Vault Transform is ready!${NC}"
}

# Main execution
main() {
    check_prerequisites
    enable_apis
    create_dataset
    create_table
    insert_sample_data
    create_remote_functions
    verify_data
    test_remote_functions
    show_summary
}

# Error handling
trap 'echo -e "\n${RED}❌ Script failed. Check the error above.${NC}"; exit 1' ERR

# Run main function
main "$@"
