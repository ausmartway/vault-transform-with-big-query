# BigQuery Simulator SQL Queries for Fraud Detection Testing

## 1. Basic Query - View all transactions
```sql
SELECT * FROM fraud_detection.transactions;
```

## 2. Decrypt Credit Cards for Fraud Analysis
```sql
SELECT 
  transaction_id,
  PARSE_JSON(CALL_REMOTE_FUNCTION(
    'http://cloud-function-dev:8080/decrypt',
    JSON_OBJECT('encrypted_value', encrypted_credit_card)
  )).decrypted_value AS credit_card_number,
  amount,
  merchant,
  transaction_date,
  is_fraud
FROM fraud_detection.transactions
WHERE is_fraud = true;
```

## 3. Find Suspicious Patterns
```sql
WITH decrypted_transactions AS (
  SELECT 
    transaction_id,
    PARSE_JSON(CALL_REMOTE_FUNCTION(
      'http://cloud-function-dev:8080/decrypt',
      JSON_OBJECT('encrypted_value', encrypted_credit_card)
    )).decrypted_value AS credit_card_number,
    amount,
    merchant,
    transaction_date,
    is_fraud
  FROM fraud_detection.transactions
)
SELECT 
  credit_card_number,
  COUNT(*) as transaction_count,
  SUM(amount) as total_amount,
  MAX(amount) as max_amount,
  AVG(amount) as avg_amount
FROM decrypted_transactions
GROUP BY credit_card_number
HAVING COUNT(*) > 1 OR MAX(amount) > 1000;
```

## 4. Test Encryption of New Data
```sql
SELECT 
  'TEST001' as transaction_id,
  PARSE_JSON(CALL_REMOTE_FUNCTION(
    'http://cloud-function-dev:8080/encrypt',
    JSON_OBJECT('credit_card_number', '5555555555554444')
  )).encrypted_value AS encrypted_credit_card,
  100.00 as amount,
  'Test Merchant' as merchant,
  CURRENT_TIMESTAMP() as transaction_date,
  false as is_fraud;
```

## 5. Round-trip Test (Encrypt then Decrypt)
```sql
WITH encrypted_test AS (
  SELECT 
    PARSE_JSON(CALL_REMOTE_FUNCTION(
      'http://cloud-function-dev:8080/encrypt',
      JSON_OBJECT('credit_card_number', '4111111111111111')
    )).encrypted_value AS encrypted_value
)
SELECT 
  '4111111111111111' as original,
  encrypted_value,
  PARSE_JSON(CALL_REMOTE_FUNCTION(
    'http://cloud-function-dev:8080/decrypt',
    JSON_OBJECT('encrypted_value', encrypted_value)
  )).decrypted_value AS decrypted_value
FROM encrypted_test;
```

## 6. Fraud Detection Query with Decryption
```sql
SELECT 
  transaction_id,
  PARSE_JSON(CALL_REMOTE_FUNCTION(
    'http://cloud-function-dev:8080/decrypt',
    JSON_OBJECT('encrypted_value', encrypted_credit_card)
  )).decrypted_value AS credit_card_number,
  amount,
  merchant,
  CASE 
    WHEN amount > 10000 THEN 'HIGH_RISK'
    WHEN amount > 1000 THEN 'MEDIUM_RISK'
    ELSE 'LOW_RISK'
  END as risk_level,
  is_fraud
FROM fraud_detection.transactions
ORDER BY amount DESC;
```
