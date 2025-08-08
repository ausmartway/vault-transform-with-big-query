-- BigQuery SQL script to create remote functions for Vault Transform integration
-- Run these commands in BigQuery after deploying the Cloud Function

-- Replace 'your-project-id' and 'your-function-url' with actual values

-- Create dataset for the remote functions (if it doesn't exist)
CREATE SCHEMA IF NOT EXISTS `your-project-id.vault_functions`
OPTIONS(
  description="Remote functions for Vault Transform Secret Engine integration"
);

-- Create remote function for encrypting credit card numbers
CREATE OR REPLACE FUNCTION `your-project-id.vault_functions.encrypt_credit_card`(credit_card_number STRING)
RETURNS STRING
REMOTE WITH CONNECTION `your-project-id.your-region.your-connection-name`
OPTIONS (
  endpoint = 'https://your-function-url/encrypt',
  description = 'Encrypts credit card numbers using Hashicorp Vault Transform Secret Engine'
);

-- Create remote function for decrypting credit card numbers  
CREATE OR REPLACE FUNCTION `your-project-id.vault_functions.decrypt_credit_card`(encrypted_value STRING)
RETURNS STRING
REMOTE WITH CONNECTION `your-project-id.your-region.your-connection-name`
OPTIONS (
  endpoint = 'https://your-function-url/decrypt',
  description = 'Decrypts credit card numbers using Hashicorp Vault Transform Secret Engine'
);

-- Example usage queries:

-- 1. Query using original credit card number (will be encrypted for the search)
-- BigQuery will automatically encrypt '4111111111111111' before querying
SELECT 
  transaction_id,
  vault_functions.decrypt_credit_card(encrypted_credit_card) as credit_card_number,
  amount,
  transaction_date,
  merchant_name
FROM `your-project-id.fraud_detection.transactions`
WHERE encrypted_credit_card = vault_functions.encrypt_credit_card('4111111111111111')
ORDER BY transaction_date DESC;

-- 2. Bulk analysis with decrypted results
SELECT 
  vault_functions.decrypt_credit_card(encrypted_credit_card) as credit_card_number,
  COUNT(*) as transaction_count,
  SUM(amount) as total_amount,
  AVG(amount) as avg_amount
FROM `your-project-id.fraud_detection.transactions`
WHERE transaction_date >= '2024-01-01'
GROUP BY encrypted_credit_card
HAVING COUNT(*) > 10
ORDER BY total_amount DESC;

-- 3. Fraud detection pattern analysis
SELECT 
  vault_functions.decrypt_credit_card(encrypted_credit_card) as credit_card_number,
  merchant_name,
  COUNT(*) as suspicious_transactions,
  ARRAY_AGG(STRUCT(transaction_id, amount, transaction_date) ORDER BY transaction_date) as transaction_details
FROM `your-project-id.fraud_detection.transactions`
WHERE 
  amount > 1000
  AND transaction_date >= CURRENT_DATE() - INTERVAL 7 DAY
GROUP BY encrypted_credit_card, merchant_name
HAVING COUNT(*) >= 3
ORDER BY suspicious_transactions DESC;
