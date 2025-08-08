-- BigQuery Remote Functions Setup
-- This file contains SQL commands to set up BigQuery remote functions 
-- that connect to the Cloud Function for encryption/decryption operations

-- ========================================
-- PRODUCTION SETUP (Google Cloud)
-- ========================================

-- 1. Create external connection to Cloud Function
-- Replace 'your-project-id', 'your-region', and 'your-cloud-function-url' with actual values
CREATE OR REPLACE EXTERNAL CONNECTION `your-project-id.your-region.vault-connection`
OPTIONS (
  type = 'CLOUD_RESOURCE',
  endpoint = 'https://your-cloud-function-url'
);

-- 2. Create remote function for credit card encryption
CREATE OR REPLACE FUNCTION `your-project-id.vault_functions.encrypt_credit_card`(credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION `your-project-id.your-region.vault-connection`
OPTIONS (
  endpoint = 'https://your-cloud-function-url',
  max_batching_rows = 100
);

-- 3. Create remote function for credit card decryption  
CREATE OR REPLACE FUNCTION `your-project-id.vault_functions.decrypt_credit_card`(encrypted_credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION `your-project-id.your-region.vault-connection`
OPTIONS (
  endpoint = 'https://your-cloud-function-url',
  max_batching_rows = 100
);

-- ========================================
-- LOCAL DEVELOPMENT SETUP (BigQuery Emulator)
-- ========================================

-- Note: The BigQuery emulator doesn't support external connections or remote functions
-- For local development, we use direct HTTP calls to the Cloud Function instead
-- See scripts/query_encrypted_data.py for examples

-- Example of how you would use the remote functions in production:
/*
-- Query transactions for a specific credit card (production example)
SELECT 
    transaction_id,
    vault_functions.decrypt_credit_card(encrypted_credit_card) as original_card,
    amount,
    merchant,
    transaction_date,
    is_fraud
FROM `your-project-id.fraud_detection.transactions`
WHERE encrypted_credit_card = vault_functions.encrypt_credit_card('4111111111111111')
ORDER BY transaction_date DESC;

-- Fraud analysis with encryption/decryption (production example)
SELECT 
    vault_functions.decrypt_credit_card(encrypted_credit_card) as original_card,
    COUNT(*) as total_transactions,
    SUM(amount) as total_amount,
    COUNT(CASE WHEN is_fraud THEN 1 END) as fraud_count,
    ROUND(COUNT(CASE WHEN is_fraud THEN 1 END) * 100.0 / COUNT(*), 2) as fraud_percentage
FROM `your-project-id.fraud_detection.transactions`
GROUP BY encrypted_credit_card
HAVING COUNT(*) > 1
ORDER BY fraud_percentage DESC, total_amount DESC;
*/

-- ========================================
-- DEPLOYMENT INSTRUCTIONS
-- ========================================

/*
To deploy these functions to production BigQuery:

1. Deploy your Cloud Function to Google Cloud:
   gcloud functions deploy vault-transform-function \
     --runtime python39 \
     --trigger-http \
     --allow-unauthenticated \
     --source src/

2. Get your Cloud Function URL:
   gcloud functions describe vault-transform-function \
     --format="value(httpsTrigger.url)"

3. Replace placeholders in this file:
   - your-project-id: Your Google Cloud project ID
   - your-region: Your preferred region (e.g., us-central1)
   - your-cloud-function-url: URL from step 2

4. Execute the SQL commands in BigQuery console or using bq CLI:
   bq query --use_legacy_sql=false < bigquery_setup.sql

5. Test the functions:
   SELECT vault_functions.encrypt_credit_card('4111111111111111');
   SELECT vault_functions.decrypt_credit_card('encrypted-value-here');

For more details on BigQuery remote functions, see:
https://cloud.google.com/bigquery/docs/remote-functions
*/
