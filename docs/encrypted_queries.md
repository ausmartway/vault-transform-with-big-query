# Querying Encrypted Data with Real Credit Card Numbers

This document demonstrates how to use real credit card numbers as input to query encrypted transaction data in BigQuery, showcasing the complete end-to-end encryption workflow.

## Overview

The system provides a secure way to:
1. Store credit card data in encrypted format using Vault Transform
2. Query encrypted data using original credit card numbers as input  
3. Perform analytics on encrypted datasets without exposing sensitive data
4. Maintain referential integrity while ensuring data protection

## Architecture Flow

```
Real Credit Card → Cloud Function → Vault Transform → Encrypted Value → BigQuery Query
     ↓                   ↓              ↓               ↓                ↓
4111111111111111 → /encrypt → FPE Transform → 9673837498063827 → WHERE clause
```

## Available Tools

### 1. Demo Script (`./scripts/manage.sh demo-encrypted`)
Comprehensive demonstration showing:
- How existing encrypted data maps to original credit card numbers
- Advanced analytics on encrypted datasets
- Real-time encryption and querying workflow

### 2. Interactive Query Tool (`./scripts/manage.sh interactive`)
User-friendly interface for:
- Querying transactions by credit card number
- Searching by merchant name
- Viewing fraud transactions
- Analytics dashboard

### 3. Direct Script (`python scripts/query_encrypted_data.py`)
Programmatic access to the query functionality

## Sample Queries

### Query by Credit Card Number
```python
# Input: Real credit card number
card_number = "4111111111111111"

# Step 1: Encrypt using Cloud Function
encrypted = encrypt_credit_card(card_number)
# Result: "9673837498063827"

# Step 2: Query BigQuery
sql = f"""
SELECT transaction_id, amount, merchant, is_fraud
FROM `test-project.fraud_detection.transactions`
WHERE encrypted_credit_card = '{encrypted}'
"""
```

### Analytics on Encrypted Data
```sql
-- Fraud analysis without exposing card numbers
SELECT 
    encrypted_credit_card,
    COUNT(*) as transaction_count,
    SUM(amount) as total_spent,
    COUNT(CASE WHEN is_fraud = true THEN 1 END) as fraud_count
FROM `test-project.fraud_detection.transactions`
GROUP BY encrypted_credit_card
ORDER BY total_spent DESC
```

### Risk Assessment
```sql
-- High-value transaction analysis
SELECT 
    encrypted_credit_card,
    amount,
    merchant,
    CASE 
        WHEN amount > 10000 THEN 'Very High Risk'
        WHEN amount > 5000 THEN 'High Risk'
        WHEN amount > 1000 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as risk_category
FROM `test-project.fraud_detection.transactions`
WHERE amount > 1000
ORDER BY amount DESC
```

## Sample Data in Database

The system includes sample transactions for testing:

| Original Card | Encrypted Value | Transactions | Fraud Count |
|---------------|----------------|--------------|-------------|
| 4111111111111111 | 9673837498063827 | 2 | 1 |
| 4222222222222222 | 0478270584270145 | 2 | 0 |
| 5555555555554444 | 8514374752952481 | 2 | 0 |
| 6011111111111117 | 2573849502847193 | 2 | 1 |

## Usage Examples

### 1. Quick Demo
```bash
./scripts/manage.sh demo-encrypted
```

### 2. Interactive Exploration
```bash
./scripts/manage.sh interactive
```

### 3. Programmatic Access
```python
from scripts.query_encrypted_data import find_transactions_by_card

# Find all transactions for a specific card
find_transactions_by_card("4111111111111111")
```

## Key Features

### 🔐 Security
- Credit card numbers are encrypted before storage
- Queries encrypt input before searching
- No plain text credit cards exposed in logs or results
- Vault Transform provides format-preserving encryption

### 📊 Analytics Capabilities
- Transaction volume analysis by encrypted card
- Fraud pattern detection
- Merchant category risk assessment
- High-value transaction monitoring

### 🔍 Query Flexibility
- Search by original credit card number
- Filter by merchant, category, amount
- Date range queries
- Complex analytical queries

### 🎯 Real-time Processing
- Live encryption of input credit card numbers
- Immediate query results
- Interactive exploration tools

## Production Considerations

### Security
- Implement proper authentication for Cloud Function
- Add rate limiting to prevent abuse
- Use HTTPS for all communications
- Implement audit logging

### Performance
- Index encrypted credit card fields
- Optimize query patterns
- Implement caching for frequent lookups
- Monitor query performance

### Monitoring
- Track encryption/decryption operations
- Monitor query patterns for anomalies
- Alert on high-value transactions
- Log all data access

## Error Handling

The system handles various error scenarios:
- Invalid credit card number format
- Encryption service unavailable
- BigQuery connectivity issues
- Malformed query requests

## Testing

Run comprehensive tests:
```bash
# Test all functionality
./scripts/manage.sh demo-encrypted

# Interactive testing
./scripts/manage.sh interactive

# Basic service tests
./scripts/manage.sh test-bigquery
```

## Integration Points

### With Vault Transform
- Encryption: `POST /encrypt` - Converts real credit card to encrypted value
- Decryption: `POST /decrypt` - Converts encrypted value back to real credit card
- Health: `GET /health` - Service health check

### With BigQuery
- Standard SQL queries work on encrypted data
- Remote functions can be called for real-time encryption/decryption
- Analytics and reporting function normally

### With Applications
- REST API endpoints for programmatic access
- Interactive tools for manual investigation
- Batch processing capabilities for large datasets

This architecture demonstrates how to maintain strong data protection while enabling powerful analytics and operational capabilities on sensitive financial data.
