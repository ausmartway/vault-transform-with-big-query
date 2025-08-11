-- BigQuery Remote Functions for Vault Transform Credit Card Encryption/Decryption
-- 
-- These examples assume you have deployed the Cloud Function and created the remote functions

-- 1. Create the remote functions (run these once after deploying the Cloud Function)

-- Encryption function
CREATE OR REPLACE FUNCTION `your_project.your_dataset.encrypt_credit_card`(credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION `your_project.your_location.your_connection_name`
OPTIONS (
    endpoint = 'https://your-region-your-project.cloudfunctions.net/vault-transform-function/encrypt',
    description = 'Encrypt credit card numbers using Vault Transform FPE'
);

-- Decryption function  
CREATE OR REPLACE FUNCTION `your_project.your_dataset.decrypt_credit_card`(encrypted_value STRING)
RETURNS STRING
REMOTE WITH CONNECTION `your_project.your_location.your_connection_name`
OPTIONS (
    endpoint = 'https://your-region-your-project.cloudfunctions.net/vault-transform-function/decrypt',
    description = 'Decrypt credit card numbers using Vault Transform FPE'
);

-- 2. Example usage in queries

-- Encrypt credit card numbers in a table
SELECT 
    customer_id,
    `your_project.your_dataset.encrypt_credit_card`(credit_card_number) AS encrypted_cc,
    credit_card_number AS original_cc  -- Remove this in production!
FROM `your_project.your_dataset.customer_payments`
WHERE credit_card_number IS NOT NULL
LIMIT 10;

-- Decrypt encrypted credit card numbers (for authorized access only)
SELECT 
    customer_id,
    encrypted_credit_card,
    `your_project.your_dataset.decrypt_credit_card`(encrypted_credit_card) AS decrypted_cc
FROM `your_project.your_dataset.encrypted_payments`
WHERE encrypted_credit_card IS NOT NULL
LIMIT 10;

-- Create a secure view that only shows encrypted values
CREATE OR REPLACE VIEW `your_project.your_dataset.secure_customer_payments` AS
SELECT 
    customer_id,
    customer_name,
    `your_project.your_dataset.encrypt_credit_card`(credit_card_number) AS encrypted_credit_card,
    payment_amount,
    payment_date,
    -- Don't include the original credit_card_number in the view
FROM `your_project.your_dataset.raw_customer_payments`;

-- Example: Batch encryption for migration
-- Use this to encrypt existing credit card data
CREATE OR REPLACE TABLE `your_project.your_dataset.migrated_payments` AS
SELECT 
    customer_id,
    customer_name,
    `your_project.your_dataset.encrypt_credit_card`(credit_card_number) AS encrypted_credit_card,
    payment_amount,
    payment_date
FROM `your_project.your_dataset.raw_customer_payments`
WHERE credit_card_number IS NOT NULL;

-- Verify the migration worked (round-trip test)
SELECT 
    customer_id,
    encrypted_credit_card,
    `your_project.your_dataset.decrypt_credit_card`(encrypted_credit_card) AS verification_cc
FROM `your_project.your_dataset.migrated_payments`
LIMIT 5;
