#!/bin/bash

# Generate realistic transaction records with encrypted credit cards
# Uses Vault directly for encryption and creates CSV file
# Usage: ./generate-transactions.sh [number_of_transactions]
# Default: 100 transactions if no parameter provided

set -euo pipefail

# Get number of transactions from parameter or default to 100
NUM_TRANSACTIONS=${1:-100}

# Validate the parameter
if ! [[ "$NUM_TRANSACTIONS" =~ ^[0-9]+$ ]] || [ "$NUM_TRANSACTIONS" -le 0 ]; then
    echo "❌ Error: Please provide a valid positive number of transactions"
    echo "Usage: $0 [number_of_transactions]"
    echo "Example: $0 50"
    echo "Default: $0 (generates 100 transactions)"
    exit 1
fi

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
DATASET_NAME="fraud_detection"
TABLE_NAME="transactions"
REGION="australia-southeast1"
FUNCTION_NAME="vault-transform-function"

print_status "Generating $NUM_TRANSACTIONS transactions..."

# Save current environment variables
CURRENT_VAULT_TOKEN="${VAULT_TOKEN:-}"
CURRENT_CLOUDSDK_PYTHON="${CLOUDSDK_PYTHON:-}"

# Load environment variables from .env (direnv should handle this automatically)
if [[ -f .env ]]; then
    source .env
fi

# Restore important environment variables if they were set before
if [[ -n "$CURRENT_VAULT_TOKEN" ]]; then
    export VAULT_TOKEN="$CURRENT_VAULT_TOKEN"
fi

# Set CLOUDSDK_PYTHON to use system Python to fix gcloud issues
export CLOUDSDK_PYTHON="/opt/homebrew/bin/python3"

# Check Vault connectivity
if ! vault token lookup > /dev/null 2>&1; then
    print_error "Cannot authenticate with Vault. Please check your token."
    exit 1
fi

# Save current environment variables
CURRENT_VAULT_TOKEN="${VAULT_TOKEN:-}"
CURRENT_CLOUDSDK_PYTHON="${CLOUDSDK_PYTHON:-}"

# Load environment variables from .env (direnv should handle this automatically)
if [[ -f .env ]]; then
    source .env
fi

# Restore important environment variables if they were set before
if [[ -n "$CURRENT_VAULT_TOKEN" ]]; then
    export VAULT_TOKEN="$CURRENT_VAULT_TOKEN"
fi

# Set CLOUDSDK_PYTHON to use system Python to fix gcloud issues
export CLOUDSDK_PYTHON="/opt/homebrew/bin/python3"

# Check Vault connectivity
print_status "Checking Vault connectivity..."
if [[ -z "${VAULT_ADDR:-}" ]]; then
    print_error "VAULT_ADDR not set. Please check .env file."
    exit 1
fi

if [[ -z "${VAULT_TOKEN:-}" && -z "${VAULT_CLIENT_TOKEN:-}" ]]; then
    print_error "VAULT_TOKEN or VAULT_CLIENT_TOKEN not set. Please run: export VAULT_TOKEN=<your_token>"
    exit 1
fi

# Use client token if available, otherwise use VAULT_TOKEN
if [[ -n "${VAULT_CLIENT_TOKEN:-}" ]]; then
    export VAULT_TOKEN="$VAULT_CLIENT_TOKEN"
fi

# Test Vault connection
if ! vault token lookup > /dev/null 2>&1; then
    print_error "Cannot authenticate with Vault. Please check your token."
    exit 1
fi

print_success "Vault connection verified"

# Clear existing data - temporarily disabled due to gcloud issues
print_status "Skipping BigQuery operations due to gcloud issues - will generate CSV only..."
# bq query --use_legacy_sql=false "DELETE FROM \`${PROJECT_ID}.${DATASET_NAME}.${TABLE_NAME}\` WHERE TRUE;"

# Credit card test numbers for encryption
declare -a CREDIT_CARDS=(
    "4111111111111111"  # Visa
    "5555555555554444"  # Mastercard
    "4222222222222222"  # Visa
    "6011111111111117"  # Discover
    "3782822463100005"  # American Express
    "4000000000000002"  # Visa
    "5105105105105100"  # Mastercard
    "4012888888881881"  # Visa
    "6011000990139424"  # Discover
    "3714496353984313"  # American Express
)

# Encrypt credit cards using Vault directly
declare -a ENCRYPTED_CARDS=()
declare -a CARD_TYPES=()

for card in "${CREDIT_CARDS[@]}"; do
    # Use Vault Transform API directly
    encrypted_response=$(vault write -field=encoded_value \
        transform/encode/creditcard-transform \
        value="$card" 2>/dev/null)
    
    if [[ -n "$encrypted_response" && "$encrypted_response" != "null" ]]; then
        ENCRYPTED_CARDS+=("$encrypted_response")
        
        # Determine card type
        case "${card:0:1}" in
            "4") CARD_TYPES+=("Visa") ;;
            "5") CARD_TYPES+=("Mastercard") ;;
            "3") CARD_TYPES+=("American Express") ;;
            "6") CARD_TYPES+=("Discover") ;;
            *) CARD_TYPES+=("Unknown") ;;
        esac
    else
        print_error "Failed to encrypt card: ${card:0:4}****${card:(-4)}"
        exit 1
    fi
done

# Merchants and categories
declare -a MERCHANTS=(
    "Amazon:E-commerce"
    "Walmart:Retail"
    "Target:Retail"
    "Best Buy:Electronics"
    "Apple Store:Electronics"
    "Starbucks:Food & Beverage"
    "McDonald's:Fast Food"
    "Subway:Fast Food"
    "Chipotle:Fast Food"
    "Shell:Gas Station"
    "Exxon:Gas Station"
    "Chevron:Gas Station"
    "Netflix:Subscription"
    "Spotify:Subscription"
    "Adobe:Software"
    "Microsoft:Software"
    "Google Play:Digital"
    "App Store:Digital"
    "Uber:Transportation"
    "Lyft:Transportation"
    "Airbnb:Travel"
    "Hotels.com:Travel"
    "Expedia:Travel"
    "Booking.com:Travel"
    "Home Depot:Home Improvement"
    "Lowe's:Home Improvement"
    "Costco:Wholesale"
    "Sam's Club:Wholesale"
    "Whole Foods:Grocery"
    "Kroger:Grocery"
    "Safeway:Grocery"
    "CVS Pharmacy:Healthcare"
    "Walgreens:Healthcare"
    "Nike:Clothing"
    "Adidas:Clothing"
    "Zara:Clothing"
    "H&M:Clothing"
    "Macy's:Department Store"
    "Nordstrom:Department Store"
    "Tiffany & Co:Jewelry"
    "Kay Jewelers:Jewelry"
    "GameStop:Gaming"
    "Steam:Gaming"
    "PlayStation Store:Gaming"
    "Suspicious Electronics:Electronics"
    "Unknown Merchant:Unknown"
    "Cash Advance ATM:ATM"
    "Foreign ATM:ATM"
    "Offshore Gambling:Gambling"
    "Cryptocurrency Exchange:Crypto"
)

# Locations
declare -a LOCATIONS=(
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
    "San Francisco, CA"
    "Columbus, OH"
    "Charlotte, NC"
    "Fort Worth, TX"
    "Indianapolis, IN"
    "Seattle, WA"
    "Denver, CO"
    "Washington, DC"
    "Boston, MA"
    "El Paso, TX"
    "Nashville, TN"
    "Detroit, MI"
    "Oklahoma City, OK"
    "Portland, OR"
    "Las Vegas, NV"
    "Memphis, TN"
    "Louisville, KY"
    "Baltimore, MD"
    "Milwaukee, WI"
    "Albuquerque, NM"
    "Tucson, AZ"
    "Fresno, CA"
    "Sacramento, CA"
    "Mesa, AZ"
    "Kansas City, MO"
    "Atlanta, GA"
    "Long Beach, CA"
    "Colorado Springs, CO"
    "Raleigh, NC"
    "Miami, FL"
    "Virginia Beach, VA"
    "Omaha, NE"
    "Oakland, CA"
    "Minneapolis, MN"
    "Tulsa, OK"
    "Arlington, TX"
    "Online"
    "Mobile App"
    "Unknown Location"
    "Foreign Country"
    "International"
)

# Create CSV file with dynamic naming
csv_file="/tmp/transactions_${NUM_TRANSACTIONS}.csv"

# Write CSV header
echo "transaction_id,encrypted_credit_card,amount,merchant_name,merchant_category,transaction_date,location,is_fraud,card_type,created_at" > "$csv_file"

# Generate base timestamp (30 days ago)
base_timestamp=$(date -v-30d +%s)

# Generate transactions with dynamic count
for i in $(seq 1 $NUM_TRANSACTIONS); do
    # Random selections
    card_index=$((RANDOM % ${#ENCRYPTED_CARDS[@]}))
    merchant_info="${MERCHANTS[$((RANDOM % ${#MERCHANTS[@]}))]}"
    merchant_name="${merchant_info%%:*}"
    merchant_category="${merchant_info##*:}"
    location="${LOCATIONS[$((RANDOM % ${#LOCATIONS[@]}))]}"
    
    # Random transaction details
    days_offset=$((RANDOM % 30))
    hours_offset=$((RANDOM % 24))
    minutes_offset=$((RANDOM % 60))
    timestamp=$((base_timestamp + days_offset * 86400 + hours_offset * 3600 + minutes_offset * 60))
    transaction_date=$(date -r "$timestamp" -u '+%Y-%m-%dT%H:%M:%SZ')
    
    # Random amount with realistic distribution
    amount_type=$((RANDOM % 100))
    if [[ $amount_type -lt 50 ]]; then
        # Small amounts (50% - $1-200)
        amount=$(awk "BEGIN {printf \"%.2f\", ($((RANDOM % 19900)) + 100) / 100}")
    elif [[ $amount_type -lt 75 ]]; then
        # Medium amounts (25% - $200-1000)
        amount=$(awk "BEGIN {printf \"%.2f\", ($((RANDOM % 80000)) + 20000) / 100}")
    elif [[ $amount_type -lt 90 ]]; then
        # Large amounts (15% - $1000-5000)
        amount=$(awk "BEGIN {printf \"%.2f\", ($((RANDOM % 400000)) + 100000) / 100}")
    else
        # Very large amounts (10% - $5000+)
        amount=$(awk "BEGIN {printf \"%.2f\", ($((RANDOM % 500000)) + 500000) / 100}")
    fi
    
    # Fraud detection logic (more sophisticated)
    is_fraud="false"
    fraud_score=0
    
    # High amount increases fraud score
    if [[ $(awk "BEGIN {print ($amount > 5000) ? 1 : 0}") -eq 1 ]]; then
        fraud_score=$((fraud_score + 30))
    elif [[ $(awk "BEGIN {print ($amount > 2000) ? 1 : 0}") -eq 1 ]]; then
        fraud_score=$((fraud_score + 15))
    fi
    
    # Suspicious merchants
    if [[ "$merchant_name" == *"Suspicious"* || "$merchant_name" == *"Unknown"* || "$merchant_category" == "Unknown" ]]; then
        fraud_score=$((fraud_score + 40))
    elif [[ "$merchant_category" == "ATM" || "$merchant_category" == "Gambling" || "$merchant_category" == "Crypto" ]]; then
        fraud_score=$((fraud_score + 25))
    fi
    
    # Suspicious locations
    if [[ "$location" == *"Unknown"* || "$location" == *"Foreign"* || "$location" == *"International"* ]]; then
        fraud_score=$((fraud_score + 20))
    fi
    
    # Time-based fraud (late night transactions)
    hour=$(date -r "$timestamp" '+%H')
    # Remove leading zero to avoid octal interpretation
    hour=$((10#$hour))
    if [[ $hour -ge 23 || $hour -le 4 ]]; then
        fraud_score=$((fraud_score + 10))
    fi
    
    # Random fraud factor
    random_fraud=$((RANDOM % 100))
    if [[ $random_fraud -lt 5 ]]; then  # 5% random fraud
        fraud_score=$((fraud_score + 30))
    fi
    
    # Final fraud determination
    if [[ $fraud_score -ge 50 ]]; then
        is_fraud="true"
    fi
    
    current_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    
    # Write CSV record (escape commas in merchant names)
    merchant_name_escaped=$(echo "$merchant_name" | sed 's/,/;/g')
    location_escaped=$(echo "$location" | sed 's/,/;/g')
    
    echo "TXN$(printf "%03d" $i),${ENCRYPTED_CARDS[$card_index]},$amount,$merchant_name_escaped,$merchant_category,$transaction_date,$location_escaped,$is_fraud,${CARD_TYPES[$card_index]},$current_timestamp" >> "$csv_file"
done


# Copy to permanent location and finish
cp "$csv_file" "./transactions_${NUM_TRANSACTIONS}_$(date +%Y%m%d_%H%M%S).csv"
print_success "Generated $NUM_TRANSACTIONS transactions: ./transactions_${NUM_TRANSACTIONS}_$(date +%Y%m%d_%H%M%S).csv"
