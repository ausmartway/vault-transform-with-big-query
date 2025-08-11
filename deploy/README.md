# Production Deployment Guide

This guide shows you how to deploy the **Vault Transform + BigQuery** integration to Google Cloud Platform.

## Quick Start

1. **Setup prerequisites**:

   ```bash
   cd deploy
   ./setup_prerequisites.sh
   ```

2. **Configure environment**:

   ```bash
   cp .env.template .env
   # Edit .env with your HCP Vault and GCP details
   source .env
   ```

3. **Deploy everything**:

   ```bash
   ./deploy_production.sh
   ```

## Architecture

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   BigQuery      │───▶│ Cloud Function  │───▶│ HashiCorp Vault │
│                 │    │                 │    │                 │
│ Remote Functions│    │ Python Runtime  │    │ Transform Engine│
│ • encrypt_cc()  │    │ • hvac client   │    │ • FPE encryption│
│ • decrypt_cc()  │    │ • REST endpoint │    │ • Role-based    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Prerequisites

### Required Services

- **Google Cloud Platform** account with billing enabled
- **HCP Vault** (Standard/Plus tier for Transform engine)
- **Project Owner/Editor** role in GCP
- **BigQuery Admin** permissions

⚠️ **CRITICAL**: Must use HCP Vault or cloud-accessible Vault (not localhost)

### Required Tools

- `gcloud` CLI (Google Cloud SDK)
- `bq` CLI (BigQuery command-line tool)
- `python3` with pip

## HCP Vault Setup

If you don't have HCP Vault configured yet:

1. **Create HCP Vault Cluster** (Standard or Plus tier)
2. **Configure Transform Engine**:

   ```bash
   export VAULT_ADDR=https://your-hcp-vault.vault.aws.hashicorp.cloud:8200
   export VAULT_TOKEN=your-admin-token
   export VAULT_NAMESPACE=admin
   
   ./setup_hcp_transform.sh
   ```

3. **Get service token** for production use

See `HCP_QUICK_SETUP.md` for detailed HCP Vault setup instructions.

## Environment Configuration

Create and configure your environment file:

```bash
cp .env.template .env
```

Edit `.env` with your actual values:

```bash
# GCP Configuration
export PROJECT_ID=my-fraud-detection-project

# Vault Configuration
export VAULT_ADDR=https://vault.company.com:8200
export VAULT_TOKEN=hvs.CAESIGw...your-token
export VAULT_ROLE=creditcard-transform
export VAULT_TRANSFORMATION=creditcard-fpe

# Optional: Deployment Region
export REGION=us-central1
```

Load the environment:

```bash
source .env
```

### Step 3: Deploy to Production

Run the full deployment:

```bash
./deploy_production.sh
```

This automated script will:

1. ✅ **Validate environment** and prerequisites
2. ✅ **Enable GCP APIs** (Cloud Functions, BigQuery, Cloud Build)
3. ✅ **Deploy Cloud Function** with Vault integration
4. ✅ **Test Cloud Function** with sample encryption
5. ✅ **Create BigQuery dataset** and table
6. ✅ **Set up remote functions** with external connection
7. ✅ **Test BigQuery integration** end-to-end
8. ✅ **Load sample data** for testing
9. ✅ **Validate complete workflow**

### Step 4: Verify Deployment

Test the integration:

```bash
# Test just the function and BigQuery
./deploy_production.sh test

# Test a query manually
bq query "SELECT vault_functions.encrypt_credit_card('4111111111111111')"
```

## Manual Deployment Steps

If you prefer manual deployment or need to troubleshoot:

### 1. Deploy Cloud Function

```bash
# Prepare source
mkdir -p cloud-function
cp ../src/* cloud-function/

# Deploy
gcloud functions deploy vault-transform-function \
    --gen2 \
    --runtime=python311 \
    --region=us-central1 \
    --source=cloud-function \
    --entry-point=vault_transform_bigquery \
    --trigger=http \
    --allow-unauthenticated \
    --set-env-vars="VAULT_ADDR=${VAULT_ADDR},VAULT_TOKEN=${VAULT_TOKEN},VAULT_ROLE=${VAULT_ROLE},VAULT_TRANSFORMATION=${VAULT_TRANSFORMATION}"
```

### 2. Get Function URL

```bash
FUNCTION_URL=$(gcloud functions describe vault-transform-function \
    --region=us-central1 \
    --format="value(serviceConfig.uri)")

echo "Function URL: $FUNCTION_URL"
```

### 3. Create BigQuery Resources

```bash
# Create dataset
bq mk --dataset \
    --description="Fraud detection with encrypted credit cards" \
    --location=US \
    ${PROJECT_ID}:fraud_detection

# Create external connection
bq query --use_legacy_sql=false "
CREATE OR REPLACE EXTERNAL CONNECTION \`${PROJECT_ID}.us-central1.vault-connection\`
OPTIONS (
  type = 'CLOUD_RESOURCE',
  endpoint = '${FUNCTION_URL}'
)"

# Create remote functions
bq query --use_legacy_sql=false "
CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.vault_functions.encrypt_credit_card\`(credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION \`${PROJECT_ID}.us-central1.vault-connection\`
OPTIONS (
  endpoint = '${FUNCTION_URL}',
  max_batching_rows = 100
)"
```

## Testing

### Basic Function Test

```bash
curl -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d '{
        "requestId": "test-1",
        "calls": [["4111111111111111"]]
    }'
```

### BigQuery Integration Test

```sql
-- Test encryption
SELECT vault_functions.encrypt_credit_card('4111111111111111') as encrypted_value;

-- Test with data
SELECT 
    transaction_id,
    vault_functions.decrypt_credit_card(encrypted_credit_card) as original_card,
    amount
FROM `your-project.fraud_detection.transactions`
LIMIT 5;
```

### Query Encrypted Data

```sql
-- Find transactions for a specific credit card
SELECT 
    transaction_id,
    amount,
    merchant,
    is_fraud
FROM `your-project.fraud_detection.transactions`
WHERE encrypted_credit_card = vault_functions.encrypt_credit_card('4111111111111111');
```

## Troubleshooting

### Common Issues

#### 1. Function deployment fails

```bash
# Check quota and permissions
gcloud functions deploy --help
gcloud auth list
```

#### 2. BigQuery external connection fails

```bash
# Verify function URL is accessible
curl -X GET "$FUNCTION_URL"

# Check BigQuery permissions
bq ls
```

#### 3. Vault connection issues

```bash
# Test Vault connectivity
curl -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/health"

# Test transform endpoint
curl -H "X-Vault-Token: $VAULT_TOKEN" \
     -X POST \
     -d '{"value":"4111111111111111"}' \
     "$VAULT_ADDR/v1/transform/encode/creditcard-fpe"
```

### Debugging Commands

```bash
# Check function logs
gcloud functions logs read vault-transform-function --region=us-central1

# Check BigQuery job history
bq ls -j --max_results=10

# Test function locally
cd cloud-function
functions-framework --target=vault_transform_bigquery --debug
```

## Security Considerations

1. **Function Authentication**: Consider enabling authentication for the Cloud Function
2. **Network Security**: Use VPC connectors for internal communication
3. **Vault Token**: Use short-lived tokens or AppRole authentication
4. **Data Access**: Implement proper BigQuery IAM roles
5. **Monitoring**: Set up logging and alerting

## Cost Optimization

1. **Function Memory**: Adjust based on actual usage (current: 512MB)
2. **BigQuery Slots**: Monitor query performance and costs
3. **Data Lifecycle**: Set up table partitioning and expiration
4. **Monitoring**: Use Cloud Monitoring for cost tracking

## Monitoring & Maintenance

### Set up Monitoring

```bash
# Enable monitoring
gcloud services enable monitoring.googleapis.com

# Create custom dashboard (manual setup in Console)
# Monitor: Function executions, BigQuery queries, Vault API calls
```

### Regular Maintenance

- **Vault Token Rotation**: Update function environment variables
- **Function Updates**: Redeploy for security patches
- **BigQuery Optimization**: Monitor query patterns and optimize
- **Cost Review**: Monthly cost analysis and optimization

## Cleanup

To remove all deployed resources:

```bash
./deploy_production.sh clean
```

This will delete:

- Cloud Function
- BigQuery dataset and tables
- External connections

## Next Steps

1. **Production Hardening**: Implement authentication, monitoring, and backup
2. **CI/CD Pipeline**: Set up automated deployment
3. **Data Integration**: Connect to real data sources
4. **Scaling**: Monitor and optimize for production workloads

---

## Quick Reference

### Essential Commands

```bash
# Deploy everything
./deploy_production.sh

# Test deployment
./deploy_production.sh test

# Clean up
./deploy_production.sh clean

# Load environment
source .env

# Manual function test
curl -X POST "$FUNCTION_URL" -H "Content-Type: application/json" -d '{"requestId":"test","calls":[["4111111111111111"]]}'

# BigQuery test
bq query "SELECT vault_functions.encrypt_credit_card('4111111111111111')"
```

### Key Resources Created

- **Cloud Function**: `vault-transform-function` (us-central1)
- **BigQuery Dataset**: `fraud_detection`
- **BigQuery Table**: `transactions`
- **External Connection**: `vault-connection`
- **Remote Functions**: `encrypt_credit_card`, `decrypt_credit_card`

### Key Environment Variables

```bash
PROJECT_ID=your-gcp-project-id
VAULT_ADDR=https://your-vault-url:8200
VAULT_TOKEN=your-vault-token
VAULT_ROLE=creditcard-transform
VAULT_TRANSFORMATION=creditcard-fpe
```
