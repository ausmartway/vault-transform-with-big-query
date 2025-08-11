# Deploying to Google Cloud Platform

This guide walks you through deploying the Vault Transform + BigQuery integration to real Google Cloud Platform.

## Prerequisites

### 1. Google Cloud Setup
```bash
# Install Google Cloud CLI (if not already installed)
# macOS:
brew install google-cloud-sdk

# Verify installation
gcloud --version

# Login to your Google account
gcloud auth login

# Set your project (replace with your actual project ID)
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

### 2. HashiCorp Vault Setup
You'll need a Vault instance accessible from Google Cloud. Options:

**Option A: Vault Cloud (Recommended)**
- Sign up at https://cloud.hashicorp.com/
- Create a Vault cluster
- Note the cluster URL and admin token

**Option B: Self-hosted Vault**
- Deploy Vault on Compute Engine or GKE
- Ensure it's accessible from Cloud Functions
- Configure Transform Secret Engine

### 3. Environment Variables
Create a `.env.production` file:
```bash
# Copy from local .env and update for production
cp .env .env.production

# Edit for production values
VAULT_ADDR=https://your-vault-cluster.vault.hashicorp.cloud:8200
VAULT_TOKEN=your-production-vault-token
PROJECT_ID=your-gcp-project-id
```

## Step 1: Deploy Cloud Function

### 1.1 Prepare Function Source
```bash
# Create deployment directory
mkdir -p deploy/cloud-function
cp -r src/* deploy/cloud-function/

# Update requirements.txt for production
cat > deploy/cloud-function/requirements.txt << EOF
functions-framework==3.5.0
hvac==2.0.0
google-cloud-bigquery==3.15.0
requests==2.31.0
EOF
```

### 1.2 Update Configuration for Production
```bash
# Create production config
cat > deploy/cloud-function/.env << EOF
VAULT_ADDR=${VAULT_ADDR}
VAULT_TOKEN=${VAULT_TOKEN}
VAULT_ROLE=creditcard-transform
VAULT_TRANSFORMATION=creditcard-fpe
EOF
```

### 1.3 Deploy the Function
```bash
# Deploy Cloud Function
gcloud functions deploy vault-transform-function \
    --gen2 \
    --runtime=python311 \
    --region=us-central1 \
    --source=deploy/cloud-function \
    --entry-point=vault_transform_bigquery \
    --trigger=http \
    --allow-unauthenticated \
    --memory=512MB \
    --timeout=60s \
    --set-env-vars="VAULT_ADDR=${VAULT_ADDR},VAULT_TOKEN=${VAULT_TOKEN}"

# Get the function URL
FUNCTION_URL=$(gcloud functions describe vault-transform-function \
    --region=us-central1 \
    --format="value(serviceConfig.uri)")

echo "Cloud Function URL: $FUNCTION_URL"
```

### 1.4 Test the Deployed Function
```bash
# Test encryption
curl -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d '{
        "requestId": "test-encrypt",
        "calls": [["4111111111111111"]]
    }'

# Should return: {"replies": ["encrypted-value"]}
```

## Step 2: Set Up BigQuery

### 2.1 Create Dataset
```bash
# Create BigQuery dataset
bq mk --dataset \
    --description="Fraud detection with encrypted credit cards" \
    --location=US \
    ${PROJECT_ID}:fraud_detection
```

### 2.2 Create Sample Table
```bash
# Create table schema file
cat > deploy/table_schema.json << 'EOF'
[
    {"name": "transaction_id", "type": "STRING", "mode": "REQUIRED"},
    {"name": "encrypted_credit_card", "type": "STRING", "mode": "REQUIRED"},
    {"name": "amount", "type": "FLOAT", "mode": "REQUIRED"},
    {"name": "merchant", "type": "STRING", "mode": "REQUIRED"},
    {"name": "category", "type": "STRING", "mode": "REQUIRED"},
    {"name": "transaction_date", "type": "TIMESTAMP", "mode": "REQUIRED"},
    {"name": "is_fraud", "type": "BOOLEAN", "mode": "REQUIRED"}
]
EOF

# Create table
bq mk --table \
    ${PROJECT_ID}:fraud_detection.transactions \
    deploy/table_schema.json
```

### 2.3 Set Up Remote Functions
```bash
# Create external connection
bq mk --connection \
    --display_name="Vault Transform Connection" \
    --connection_type=CLOUD_RESOURCE \
    --cloud_resource_service_account_id="vault-transform-sa" \
    --location=us-central1 \
    vault-connection

# Get connection details
bq show --connection \
    --location=us-central1 \
    vault-connection
```

### 2.4 Create Remote Functions
```sql
-- Run these SQL commands in BigQuery Console or via bq command

-- 1. Create external connection (if not done via CLI)
CREATE OR REPLACE EXTERNAL CONNECTION `{PROJECT_ID}.us-central1.vault-connection`
OPTIONS (
  type = 'CLOUD_RESOURCE',
  endpoint = '{FUNCTION_URL}'
);

-- 2. Create encryption function
CREATE OR REPLACE FUNCTION `{PROJECT_ID}.vault_functions.encrypt_credit_card`(credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION `{PROJECT_ID}.us-central1.vault-connection`
OPTIONS (
  endpoint = '{FUNCTION_URL}',
  max_batching_rows = 100
);

-- 3. Create decryption function  
CREATE OR REPLACE FUNCTION `{PROJECT_ID}.vault_functions.decrypt_credit_card`(encrypted_credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION `{PROJECT_ID}.us-central1.vault-connection`
OPTIONS (
  endpoint = '{FUNCTION_URL}',
  max_batching_rows = 100
);
```

### 2.5 Execute SQL Setup
```bash
# Create SQL file with your values
envsubst < sql/bigquery_setup.sql > deploy/bigquery_setup_production.sql

# Execute the SQL
bq query --use_legacy_sql=false < deploy/bigquery_setup_production.sql
```

## Step 3: Load Sample Data

### 3.1 Create Sample Data Script
```bash
cat > deploy/load_sample_data.py << 'EOF'
#!/usr/bin/env python3
"""Load sample encrypted data into production BigQuery."""

import requests
from google.cloud import bigquery
import os
from datetime import datetime, timedelta

# Configuration
PROJECT_ID = os.getenv('PROJECT_ID')
FUNCTION_URL = os.getenv('FUNCTION_URL')

def encrypt_credit_card(card_number):
    """Encrypt credit card using Cloud Function."""
    response = requests.post(FUNCTION_URL, json={
        "requestId": "data-load",
        "calls": [[card_number]]
    })
    return response.json()['replies'][0]

def load_sample_data():
    """Load sample data with encrypted credit cards."""
    client = bigquery.Client(project=PROJECT_ID)
    
    # Sample credit card numbers
    sample_cards = [
        "4111111111111111",  # Visa
        "4222222222222222",  # Visa
        "5555555555554444",  # Mastercard
        "6011111111111117",  # Discover
        "3782822463100005"   # American Express
    ]
    
    # Generate sample transactions
    rows_to_insert = []
    base_date = datetime.now() - timedelta(days=30)
    
    for i, card in enumerate(sample_cards):
        encrypted_card = encrypt_credit_card(card)
        
        # Create 2 transactions per card
        for j in range(2):
            row = {
                "transaction_id": f"txn_{i}_{j}",
                "encrypted_credit_card": encrypted_card,
                "amount": 100.0 + (i * 50) + (j * 25),
                "merchant": f"Merchant_{i}_{j}",
                "category": ["Grocery", "Gas", "Restaurant", "Online", "ATM"][i],
                "transaction_date": base_date + timedelta(days=i*2+j),
                "is_fraud": j == 1 and i % 2 == 0  # Make some transactions fraud
            }
            rows_to_insert.append(row)
    
    # Insert data
    table_id = f"{PROJECT_ID}.fraud_detection.transactions"
    table = client.get_table(table_id)
    
    errors = client.insert_rows_json(table, rows_to_insert)
    if errors:
        print(f"Errors inserting data: {errors}")
    else:
        print(f"Successfully inserted {len(rows_to_insert)} rows")

if __name__ == "__main__":
    load_sample_data()
EOF

# Make executable and run
chmod +x deploy/load_sample_data.py
cd deploy && python load_sample_data.py
```

## Step 4: Test the Integration

### 4.1 Test Remote Functions
```sql
-- Test encryption function
SELECT vault_functions.encrypt_credit_card('4111111111111111') as encrypted_value;

-- Test decryption function (use result from above)
SELECT vault_functions.decrypt_credit_card('encrypted-value-here') as original_value;
```

### 4.2 Test Complete Workflow
```sql
-- Query transactions using original credit card number
SELECT 
    transaction_id,
    vault_functions.decrypt_credit_card(encrypted_credit_card) as original_card,
    amount,
    merchant,
    transaction_date,
    is_fraud
FROM `{PROJECT_ID}.fraud_detection.transactions`
WHERE encrypted_credit_card = vault_functions.encrypt_credit_card('4111111111111111')
ORDER BY transaction_date DESC;
```

### 4.3 Fraud Analysis Query
```sql
-- Analyze fraud patterns by encrypted credit card
SELECT 
    encrypted_credit_card,
    COUNT(*) as total_transactions,
    SUM(amount) as total_amount,
    COUNT(CASE WHEN is_fraud THEN 1 END) as fraud_count,
    ROUND(COUNT(CASE WHEN is_fraud THEN 1 END) * 100.0 / COUNT(*), 2) as fraud_percentage
FROM `{PROJECT_ID}.fraud_detection.transactions`
GROUP BY encrypted_credit_card
HAVING COUNT(*) > 1
ORDER BY fraud_percentage DESC, total_amount DESC;
```

## Step 5: Production Considerations

### 5.1 Security
```bash
# Create service account for Cloud Function
gcloud iam service-accounts create vault-transform-sa \
    --description="Service account for Vault Transform function" \
    --display-name="Vault Transform SA"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:vault-transform-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.connectionUser"

# Update function to use service account
gcloud functions deploy vault-transform-function \
    --service-account="vault-transform-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --update-env-vars="VAULT_ADDR=${VAULT_ADDR},VAULT_TOKEN=${VAULT_TOKEN}"
```

### 5.2 Monitoring
```bash
# Enable Cloud Logging for the function
gcloud logging sinks create vault-transform-logs \
    bigquery.googleapis.com/projects/$PROJECT_ID/datasets/vault_logs \
    --log-filter='resource.type="cloud_function" AND resource.labels.function_name="vault-transform-function"'
```

### 5.3 Rate Limiting and Quotas
- Monitor BigQuery quota usage
- Set up Cloud Function concurrency limits
- Implement exponential backoff for Vault API calls

## Step 6: Create Production Management Scripts

### 6.1 Deployment Script
```bash
cat > deploy/deploy_production.sh << 'EOF'
#!/bin/bash
set -e

# Load environment
source .env.production

echo "🚀 Deploying Vault Transform + BigQuery to GCP"
echo "Project: $PROJECT_ID"
echo "Vault: $VAULT_ADDR"

# Deploy Cloud Function
echo "📦 Deploying Cloud Function..."
gcloud functions deploy vault-transform-function \
    --gen2 \
    --runtime=python311 \
    --region=us-central1 \
    --source=cloud-function \
    --entry-point=vault_transform_bigquery \
    --trigger=http \
    --allow-unauthenticated \
    --memory=512MB \
    --timeout=60s \
    --set-env-vars="VAULT_ADDR=${VAULT_ADDR},VAULT_TOKEN=${VAULT_TOKEN}"

# Get function URL
FUNCTION_URL=$(gcloud functions describe vault-transform-function \
    --region=us-central1 \
    --format="value(serviceConfig.uri)")

echo "✅ Cloud Function deployed: $FUNCTION_URL"

# Setup BigQuery
echo "📊 Setting up BigQuery..."
envsubst < ../sql/bigquery_setup.sql > bigquery_setup_production.sql
bq query --use_legacy_sql=false < bigquery_setup_production.sql

echo "✅ Production deployment complete!"
echo ""
echo "🧪 Test with:"
echo "  SELECT vault_functions.encrypt_credit_card('4111111111111111');"
EOF

chmod +x deploy/deploy_production.sh
```

### 6.2 Testing Script
```bash
cat > deploy/test_production.py << 'EOF'
#!/usr/bin/env python3
"""Test production BigQuery + Vault integration."""

from google.cloud import bigquery
import os

PROJECT_ID = os.getenv('PROJECT_ID')

def test_remote_functions():
    """Test BigQuery remote functions."""
    client = bigquery.Client(project=PROJECT_ID)
    
    # Test encryption
    encrypt_query = """
    SELECT vault_functions.encrypt_credit_card('4111111111111111') as encrypted_value
    """
    
    result = client.query(encrypt_query).result()
    encrypted_value = list(result)[0].encrypted_value
    print(f"✅ Encryption test: 4111111111111111 → {encrypted_value}")
    
    # Test decryption
    decrypt_query = f"""
    SELECT vault_functions.decrypt_credit_card('{encrypted_value}') as original_value
    """
    
    result = client.query(decrypt_query).result()
    original_value = list(result)[0].original_value
    print(f"✅ Decryption test: {encrypted_value} → {original_value}")
    
    # Test query workflow
    workflow_query = """
    SELECT 
        transaction_id,
        amount,
        merchant,
        is_fraud
    FROM `{}.fraud_detection.transactions`
    WHERE encrypted_credit_card = vault_functions.encrypt_credit_card('4111111111111111')
    """.format(PROJECT_ID)
    
    result = client.query(workflow_query).result()
    transactions = list(result)
    print(f"✅ Workflow test: Found {len(transactions)} transactions")
    
    for txn in transactions:
        print(f"   {txn.transaction_id}: ${txn.amount} at {txn.merchant} (fraud: {txn.is_fraud})")

if __name__ == "__main__":
    test_remote_functions()
EOF

chmod +x deploy/test_production.py
```

## Quick Start Commands

```bash
# 1. Set up environment
export PROJECT_ID="your-project-id"
export VAULT_ADDR="your-vault-url"
export VAULT_TOKEN="your-vault-token"

# 2. Deploy everything
cd deploy
./deploy_production.sh

# 3. Load sample data
python load_sample_data.py

# 4. Test the integration
python test_production.py
```

## Troubleshooting

### Common Issues

1. **Function deployment fails**
   - Check that all required APIs are enabled
   - Verify service account permissions
   - Check function logs: `gcloud functions logs read vault-transform-function`

2. **Remote function creation fails**
   - Ensure external connection exists
   - Verify function URL is accessible
   - Check BigQuery connection permissions

3. **Vault connection issues**
   - Verify Vault URL and token
   - Check network connectivity from Cloud Functions
   - Ensure Transform Secret Engine is configured

### Monitoring Commands

```bash
# Check function logs
gcloud functions logs read vault-transform-function --limit=50

# Check function status
gcloud functions describe vault-transform-function --region=us-central1

# Test BigQuery connection
bq show --connection --location=us-central1 vault-connection

# Query audit logs
bq query "SELECT * FROM \`{PROJECT_ID}.fraud_detection.transactions\` LIMIT 5"
```

This setup gives you a production-ready Vault Transform + BigQuery integration with remote functions!
