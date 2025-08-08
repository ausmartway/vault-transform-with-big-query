# BigQuery Transaction Data

This document describes the sample transaction data loaded into BigQuery for testing the Vault Transform integration.

## Datasets

### `fraud_detection.transactions`
Contains sample credit card transaction data with encrypted credit card numbers.

**Schema:**
- `transaction_id` (STRING): Unique identifier for each transaction
- `encrypted_credit_card` (STRING): Credit card number encrypted using Vault Transform
- `original_credit_card` (STRING): Original credit card number (for demo purposes only)
- `amount` (FLOAT64): Transaction amount in USD
- `merchant` (STRING): Merchant name
- `merchant_category` (STRING): Category of merchant (Electronics, Food & Beverage, etc.)
- `transaction_date` (TIMESTAMP): When the transaction occurred
- `location` (STRING): Transaction location
- `is_fraud` (BOOLEAN): Whether the transaction is marked as fraudulent
- `created_at` (TIMESTAMP): When the record was created

**Sample Data:**
- 8 total transactions
- 2 transactions marked as fraud
- 4 unique credit cards (encrypted)
- Various merchant categories and amounts

### `vault_functions.remote_functions`
Metadata about available Vault Transform remote functions.

**Schema:**
- `function_name` (STRING): Name of the remote function
- `endpoint_url` (STRING): URL endpoint for the function
- `description` (STRING): Description of what the function does
- `created_at` (TIMESTAMP): When the function was registered

**Available Functions:**
- `encrypt_credit_card`: Encrypts credit card numbers using Vault Transform
- `decrypt_credit_card`: Decrypts credit card numbers using Vault Transform
- `health_check`: Health check endpoint for the Vault Transform service

## Data Setup

To populate BigQuery with sample data:

```bash
# Setup sample data
./scripts/manage.sh setup-bigquery

# Run test queries
./scripts/manage.sh test-bigquery

# Or run manually
python scripts/setup_bigquery_data.py
python scripts/test_bigquery_queries.py
```

## Example Queries

### 1. View All Transactions
```sql
SELECT transaction_id, encrypted_credit_card, amount, merchant, is_fraud 
FROM `test-project.fraud_detection.transactions` 
ORDER BY transaction_date;
```

### 2. Find Fraud Transactions
```sql
SELECT transaction_id, encrypted_credit_card, amount, merchant, location 
FROM `test-project.fraud_detection.transactions` 
WHERE is_fraud = true;
```

### 3. Transaction Summary by Category
```sql
SELECT 
    merchant_category, 
    COUNT(*) as transaction_count, 
    SUM(amount) as total_amount, 
    AVG(amount) as avg_amount 
FROM `test-project.fraud_detection.transactions` 
GROUP BY merchant_category 
ORDER BY total_amount DESC;
```

### 4. High-Value Transactions
```sql
SELECT transaction_id, encrypted_credit_card, amount, merchant, is_fraud 
FROM `test-project.fraud_detection.transactions` 
WHERE amount > 1000 
ORDER BY amount DESC;
```

### 5. Credit Card Usage Patterns
```sql
SELECT 
    encrypted_credit_card, 
    COUNT(*) as usage_count, 
    SUM(amount) as total_spent, 
    MAX(amount) as highest_transaction 
FROM `test-project.fraud_detection.transactions` 
GROUP BY encrypted_credit_card 
ORDER BY total_spent DESC;
```

### 6. Available Remote Functions
```sql
SELECT function_name, endpoint_url, description 
FROM `test-project.vault_functions.remote_functions`;
```

## Key Features

1. **Encrypted Credit Cards**: All credit card numbers are stored in encrypted format using Vault Transform
2. **Fraud Detection**: Sample includes both legitimate and fraudulent transactions
3. **Realistic Data**: Transactions include various merchants, categories, and amounts
4. **Remote Functions**: Metadata for Vault Transform functions that can be called from BigQuery
5. **Test Queries**: Comprehensive set of example queries for analysis

## Next Steps

- Connect BigQuery remote functions to the Cloud Function
- Implement real-time fraud detection algorithms
- Add more sophisticated transaction patterns
- Test decryption of credit card numbers through remote function calls

## Security Note

⚠️ **Important**: The `original_credit_card` field is included for demo purposes only to show the encryption/decryption process. In a production environment, original credit card numbers should NEVER be stored alongside encrypted values.
