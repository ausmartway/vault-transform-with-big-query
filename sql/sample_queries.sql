# SQL Examples and Queries

## Basic Queries

### View all transactions
```sql
SELECT transaction_id, encrypted_credit_card, amount, merchant_name, is_fraud 
FROM `hc-5c7132af39e94c9ea03d2710265.fraud_detection.transactions` 
ORDER BY amount DESC
LIMIT 10;
```

### Find fraud transactions
```sql
SELECT transaction_id, encrypted_credit_card, amount, merchant_name, location
FROM `hc-5c7132af39e94c9ea03d2710265.fraud_detection.transactions` 
WHERE is_fraud = true
ORDER BY amount DESC;
```

### Transaction statistics by merchant category
```sql
SELECT 
    merchant_category,
    COUNT(*) as transaction_count,
    AVG(amount) as avg_amount,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) as fraud_count
FROM `hc-5c7132af39e94c9ea03d2710265.fraud_detection.transactions`
GROUP BY merchant_category
ORDER BY fraud_count DESC;
```

## Advanced Analytics

### High-value transactions by card type
```sql
SELECT 
    card_type,
    COUNT(*) as high_value_transactions,
    AVG(amount) as avg_amount
FROM `hc-5c7132af39e94c9ea03d2710265.fraud_detection.transactions`
WHERE amount > 1000
GROUP BY card_type
ORDER BY avg_amount DESC;
```

### Fraud detection patterns
```sql
SELECT 
    location,
    merchant_category,
    COUNT(*) as fraud_transactions,
    AVG(amount) as avg_fraud_amount
FROM `hc-5c7132af39e94c9ea03d2710265.fraud_detection.transactions`
WHERE is_fraud = true
GROUP BY location, merchant_category
HAVING COUNT(*) > 1
ORDER BY fraud_transactions DESC;
```

## Remote Function Examples (when available)

### Encrypt and query by credit card number
```sql
-- Find transactions for a specific credit card
SELECT 
    transaction_id,
    merchant_name,
    amount,
    transaction_date
FROM `hc-5c7132af39e94c9ea03d2710265.fraud_detection.transactions`
WHERE encrypted_credit_card = `hc-5c7132af39e94c9ea03d2710265.fraud_detection.encrypt_credit_card`('4111111111111111');
```

### Decrypt credit cards for analysis
```sql
-- Decrypt credit cards for fraud analysis (if remote function available)
SELECT 
    `hc-5c7132af39e94c9ea03d2710265.fraud_detection.decrypt_credit_card`(encrypted_credit_card) as credit_card,
    merchant_name,
    amount,
    is_fraud
FROM `hc-5c7132af39e94c9ea03d2710265.fraud_detection.transactions`
WHERE is_fraud = true;
```
