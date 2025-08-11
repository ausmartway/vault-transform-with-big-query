# Vault Transform with BigQuery Integration

A complete solution for encrypting sensitive data (credit cards) using HashiCorp Vault Transform Engine and querying it through BigQuery with Cloud Functions.

## Overview

This project demonstrates how to:
- Use Vault Transform Engine for Format Preserving Encryption (FPE) of credit card numbers
- Store encrypted data in BigQuery
- Query encrypted data using original credit card numbers via BigQuery Remote Functions
- Deploy Cloud Functions that handle encryption/decryption seamlessly

## Problem Statement

Fraud detection teams need to analyze credit card transactions stored in BigQuery, but:
- Credit card data must be encrypted for security compliance
- Analysts want to query using real credit card numbers (not encrypted versions)
- Manual encryption/decryption is cumbersome for operators

## Solution

1. **Vault Transform Engine**: Encrypts credit card numbers using FPE
2. **Cloud Function**: Provides HTTP endpoints for encryption/decryption
3. **BigQuery Remote Functions**: Allow querying with real credit card numbers
4. **Automated Pipeline**: Generate and load encrypted transaction data

## Quick Start

### Prerequisites
- HCP Vault cluster (or local Vault with Transform license)
- Google Cloud Project with BigQuery API enabled
- gcloud CLI authenticated

### 1. Setup Vault Transform Engine
```bash
# Create 30-day client token for Transform operations
./setup-transform.sh
```

### 2. Generate Sample Data
```bash
# Generate 100 encrypted transactions
./generate-transactions.sh 100

# Load data into BigQuery
bq load --source_format=CSV --skip_leading_rows=1 \
  fraud_detection.transactions \
  transactions_100_*.csv \
  transaction_id:STRING,encrypted_credit_card:STRING,amount:NUMERIC,merchant_name:STRING,merchant_category:STRING,transaction_date:TIMESTAMP,location:STRING,is_fraud:BOOLEAN,card_type:STRING,created_at:TIMESTAMP
```

### 3. Deploy Cloud Function (Optional)
```bash
# Deploy encryption/decryption function
./setup-cloud-function.sh

# Setup BigQuery remote functions
./setup-bigquery-functions.sh
```

## Project Structure

```
├── README.md                    # This file
├── setup-transform.sh           # Vault Transform setup (30-day tokens)
├── generate-transactions.sh     # Generate encrypted transaction data
├── creditcard-transform-policy.hcl # Vault policy for Transform operations
│
├── cloud-function/              # Cloud Function source code
│   ├── main.py                  # HTTP endpoints for encrypt/decrypt
│   └── requirements.txt         # Python dependencies
│
├── setup-cloud-function.sh      # Deploy Cloud Function
├── setup-bigquery-functions.sh  # Create BigQuery remote functions
│
├── scripts/                     # Utility scripts
│   ├── query_encrypted_data.py  # Query examples
│   └── interactive_query.py     # Interactive BigQuery tool
│
└── sql/                         # SQL examples and schemas
    └── sample_queries.sql       # Example fraud detection queries
```

## Features

### ✅ Completed
- **30-day Vault Tokens**: Long-lived tokens for extended development
- **Parameterized Transaction Generation**: Configurable number of transactions
- **BigQuery Integration**: CSV data loading and verification
- **Cloud Function Deployment**: HTTP endpoints for encryption/decryption
- **Format Preserving Encryption**: Credit cards maintain 16-digit format

### 🔧 Current Status
- **Vault Transform**: ✅ Working with FPE encryption
- **BigQuery Data**: ✅ 100+ encrypted transactions loaded
- **Cloud Function**: ✅ Deployed and functional
- **Remote Functions**: ⚠️  Blocked by organization policy

## Usage Examples

### Query Encrypted Data
```sql
-- View encrypted transactions
SELECT transaction_id, encrypted_credit_card, amount, merchant_name, is_fraud 
FROM `hc-5c7132af39e94c9ea03d2710265.fraud_detection.transactions` 
WHERE is_fraud = true
ORDER BY amount DESC
LIMIT 10;
```

### Generate More Data
```bash
# Generate specific number of transactions
./generate-transactions.sh 50    # 50 transactions
./generate-transactions.sh       # 100 transactions (default)
```

### Test Vault Encryption
```bash
# Direct Vault API test
vault write -field=encoded_value transform/encode/creditcard-transform value="4111111111111111"
```

## Configuration

### Environment Variables
```bash
# Vault Configuration
export VAULT_ADDR="https://your-vault-cluster:8200"
export VAULT_TOKEN="hvs.your-30-day-token"

# GCP Configuration  
export PROJECT_ID="your-gcp-project"
export DATASET_NAME="fraud_detection"
```

### Vault Policy
The project uses a minimal policy for Transform operations:
```hcl
path "transform/encode/creditcard-transform" {
  capabilities = ["create", "update"]
}
path "transform/decode/creditcard-transform" {
  capabilities = ["create", "update"]  
}
```

## Troubleshooting

### Common Issues

**Vault Token Expired**
```bash
# Regenerate 30-day token
./setup-transform.sh
```

**BigQuery Permission Errors**
```bash
# Verify authentication
gcloud auth list
gcloud config set project YOUR_PROJECT_ID
```

**Cloud Function Organization Policy**
Some organizations restrict public Cloud Function access. The function works but BigQuery Remote Functions may be blocked.

## Architecture

```
[Transaction Data] → [Vault Transform] → [Encrypted CSV] → [BigQuery]
                                              ↓
[BigQuery Queries] ← [Cloud Function] ← [Remote Functions]
```

1. **Data Flow**: Credit cards encrypted via Vault Transform before storage
2. **Query Flow**: BigQuery calls Cloud Function to encrypt search terms
3. **Result Flow**: Encrypted results can be decrypted via Cloud Function

## Development

### Local Testing
```bash
# Test Cloud Function locally
./run-local.sh

# Test with Python
python3 test-cloud-function.py
```

### Adding New Transaction Types
Modify `generate-transactions.sh` to include new merchant categories or fraud patterns.

## Security Notes

- **30-day Tokens**: Balance between security and development convenience
- **Minimal Permissions**: Transform policy only allows encode/decode operations
- **No Plaintext Storage**: Credit cards never stored unencrypted
- **Audit Trail**: All Vault operations are logged

## License

This project is for demonstration purposes. Ensure compliance with your organization's security policies before production use.
