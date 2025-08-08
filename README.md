# Hashicorp Vault Transform Secret Engine with BigQuery

## problem

The Hashicorp Vault Transform Secret Engine is a powerful tool for managing sensitive data transformations. Raw data is send to Vault Transform Secret Engine, goes through a Format Preserving Encryption (FPE) process, and returns the encrypted data, which is then saved in database. For example, a credit card number can be transformed into an encrypted format that retains the original format's structure, allowing for secure storage and processing without exposing sensitive information.

BigQuery is a fully managed, serverless data warehouse that enables scalable analysis over petabytes of data. Operators use BigQuery to query and analyze large datasets efficiently. for example, Operators from Fraud Detection team can use BigQuery to analyze large datasets of credit card transactions, identifying patterns and anomalies that may indicate fraudulent activity. With the data being encrypted, Operators need to decrypt the data before they can analyze it. This extra step can be cumbersome and time-consuming, especially for non-technical Operators.

The user story is as follows:

Transactions are sent to Vault Transform Secret Engine, which encrypts the data.

As an Operator, I want to be able to query the encrypted data in BigQuery without needing to decrypt it first, so that I can analyze the data more efficiently. I can use original credit card numbers as part of my queries. BigQuery will first call Vault transform API to encrypt the orginal credit card number, which will then be used to query the database, then decrypt the result and show the transactions to the Operator allowing me to decide whether the transaction is fraudulent or not.

## solution

The solution is to create a custom BigQuery function that integrates with the Hashicorp Vault Transform Secret Engine. This function will handle the encryption and decryption of sensitive data, allowing Operators to query encrypted data directly in BigQuery without needing to manually decrypt it.

The function should be hosted on Google Cloud Functions, which will allow it to be easily accessible from BigQuery. The function will take the original credit card number as input, call the Vault Transform Secret Engine API to encrypt it, and return the encrypted value. When querying the database, BigQuery will use this function to encrypt the credit card number before executing the query.

When retrieving results, the function will also handle decryption of the data returned from BigQuery, allowing Operators to view the original credit card numbers in a secure manner.

## implementation

This implementation provides a complete solution for integrating Hashicorp Vault Transform Secret Engine with BigQuery through Google Cloud Functions.

### Components

1. **Google Cloud Function** (`main.py`): A Python-based Cloud Function that provides encryption and decryption endpoints
2. **BigQuery Remote Functions** (`bigquery_setup.sql`): SQL scripts to create remote functions in BigQuery
3. **Vault Policy** (`transform-policy.hcl`): Vault policy for Transform Secret Engine access
4. **Vault Setup Script** (`setup_vault.sh`): Automated Vault configuration script
5. **Deployment Script** (`deploy.sh`): Automated deployment to Google Cloud
6. **Tests** (`test_main.py`): Unit tests for the Cloud Function
7. **Terraform Configuration** (`vault_terraform.tf`): Infrastructure as Code for Vault setup

### Features

- **Custom Credit Card Transformation**: Uses a custom FPE transformation optimized for credit card number format
- **Format Preserving Encryption (FPE)**: Maintains the original format of credit card numbers
- **BigQuery Integration**: Seamless integration with BigQuery remote functions
- **Real Credit Card Queries**: Query encrypted data using original credit card numbers as input
- **Interactive Query Tools**: CLI tools and demo scripts for hands-on exploration
- **Secure Communication**: Uses Vault's API for all encryption/decryption operations
- **Error Handling**: Comprehensive error handling and logging
- **Health Monitoring**: Health check endpoint for monitoring
- **Docker Development Environment**: Complete local setup with all services

### Setup Instructions

#### 1. Vault Configuration

You have multiple options to configure your Vault Transform Secret Engine:

> **Note**: This implementation uses a custom FPE (Format Preserving Encryption) transformation specifically designed for credit card numbers, providing secure encryption while maintaining the original format structure.

##### Option A: Use the automated setup script (Recommended)

```bash
# Make the script executable and run it
chmod +x setup_vault.sh
./setup_vault.sh
```

##### Option B: Manual setup using Vault CLI commands

```bash
# Enable Transform Secret Engine
vault secrets enable transform

# Create alphabet for numeric characters
vault write transform/alphabet/numeric alphabet="0123456789"

# Create template for credit card format
vault write transform/template/creditcard \
  type=regex \
  pattern="(\d{4})-?(\d{4})-?(\d{4})-?(\d{4})" \
  alphabet=numeric

# Create FPE transformation
vault write transform/transformation/creditcard-fpe \
  type=fpe \
  template=creditcard \
  tweak_source=internal \
  allowed_roles=creditcard-transform

# Create role using our custom transformation
vault write transform/role/creditcard-transform \
  transformations=creditcard-fpe

# Create policy and token
vault policy write transform-policy transform-policy.hcl
vault token create -policy=transform-policy
```

##### Option C: Use Terraform for Infrastructure as Code

```bash
# Initialize and apply Terraform configuration
terraform init
terraform plan
terraform apply
```

#### 2. Deploy Cloud Function

Update the variables in `deploy.sh` with your actual values:

```bash
# Edit deploy.sh with your project details
PROJECT_ID="your-project-id"
VAULT_URL="https://your-vault-instance.com"
VAULT_TOKEN="your-vault-token"

# Make script executable and deploy
chmod +x deploy.sh
./deploy.sh
```

#### 3. Create BigQuery Connection

Create a connection to your Cloud Function in BigQuery:

```sql
-- Create connection for remote functions
CREATE OR REPLACE EXTERNAL CONNECTION `your-project-id.your-region.vault-connection`
OPTIONS (
  type = 'CLOUD_RESOURCE',
  endpoint = 'https://your-cloud-function-url'
);
```

#### 4. Set Up BigQuery Remote Functions

Run the SQL commands in `bigquery_setup.sql` to create the remote functions in BigQuery.

## Local Development Environment

For testing and development, this project includes a complete Docker-based environment that runs all services locally.

### Quick Start with Docker

```bash
# Start all services
./scripts/manage.sh start

# Check service status
./scripts/manage.sh status

# Run interactive query tool
./scripts/manage.sh interactive

# Run comprehensive demo
./scripts/manage.sh demo-encrypted

# Stop all services
./scripts/manage.sh stop
```

### Services Included

- **Vault**: HashiCorp Vault with Transform Secret Engine (port 8200)
- **BigQuery Emulator**: Local BigQuery simulator (port 9050)
- **Cloud Function**: Google Cloud Functions Framework (port 8080)

### Sample Data and Demos

The local environment includes:

- Pre-configured sample transaction data
- Interactive query tools 
- Comprehensive demos showing encrypted data workflows
- Analytics examples on encrypted datasets

For detailed documentation on querying encrypted data, see [`docs/encrypted_queries.md`](docs/encrypted_queries.md).

### Usage Examples

#### Query with Original Credit Card Number

```sql
-- Find transactions for a specific credit card
SELECT 
  transaction_id,
  vault_functions.decrypt_credit_card(encrypted_credit_card) as credit_card_number,
  amount,
  transaction_date,
  merchant_name
FROM `fraud_detection.transactions`
WHERE encrypted_credit_card = vault_functions.encrypt_credit_card('4111111111111111')
ORDER BY transaction_date DESC;
```

#### Fraud Detection Analysis

```sql
-- Analyze suspicious patterns
SELECT 
  vault_functions.decrypt_credit_card(encrypted_credit_card) as credit_card_number,
  merchant_name,
  COUNT(*) as suspicious_transactions,
  SUM(amount) as total_amount
FROM `fraud_detection.transactions`
WHERE 
  amount > 1000
  AND transaction_date >= CURRENT_DATE() - INTERVAL 7 DAY
GROUP BY encrypted_credit_card, merchant_name
HAVING COUNT(*) >= 3
ORDER BY suspicious_transactions DESC;
```

### Security Considerations

1. **Vault Token Management**: Use Vault's auth methods (e.g., GCP auth) instead of static tokens in production
2. **Network Security**: Ensure secure communication between Cloud Function and Vault
3. **Access Control**: Implement proper IAM policies for BigQuery and Cloud Functions
4. **Audit Logging**: Enable audit logging for both Vault and BigQuery operations
5. **Key Rotation**: Implement regular rotation of Vault tokens and encryption keys

### Monitoring and Logging

- Cloud Function logs are available in Google Cloud Logging
- Vault audit logs track all encryption/decryption operations
- BigQuery job logs show remote function usage
- Set up alerts for failed operations or unusual patterns

### Testing

Run the unit tests to verify the implementation:

```bash
python -m pytest test_main.py -v
```

### Troubleshooting

Common issues and solutions:

1. **Vault Connection Issues**: Verify network connectivity and authentication
2. **BigQuery Remote Function Errors**: Check Cloud Function logs and IAM permissions
3. **Performance Issues**: Consider implementing caching for frequently accessed data
4. **Rate Limiting**: Implement proper retry logic and rate limiting

This solution provides a robust, secure, and scalable way for operators to work with encrypted credit card data in BigQuery while maintaining the security benefits of Vault Transform Secret Engine.
