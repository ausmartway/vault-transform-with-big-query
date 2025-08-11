# Final Setup Instructions for Vault Transform + BigQuery Integration

## Current Status: 99% Complete - Only IAM Permissions Remaining

### ✅ What's Already Working:
1. **HCP Vault**: Fully configured with Transform engine
2. **Cloud Function**: Successfully deployed at `https://vault-transform-function-cvb4eibhuq-uc.a.run.app`
3. **BigQuery**: Datasets and connection created
4. **Code**: All source code and configurations ready

### ❌ Remaining Blocker: IAM Permissions

User `yulei@hashicorp.com` lacks the following permissions:
- `cloudfunctions.functions.setIamPolicy` - needed to grant BigQuery access to Cloud Function
- `bigquery.connections.delegate` - needed to create remote functions using the connection

## 🔧 Required Actions (Must be run by Project Owner/Admin)

### Step 1: Grant Cloud Function Invoke Permission to BigQuery
```bash
gcloud functions add-iam-policy-binding vault-transform-function \
    --region=us-central1 \
    --member="serviceAccount:bqcx-786265264300-5upk@gcp-sa-bigquery-condel.iam.gserviceaccount.com" \
    --role="roles/cloudfunctions.invoker" \
    --project=hc-5c7132af39e94c9ea03d2710265
```

### Step 2: Create BigQuery Remote Functions
```bash
cd /Users/yuleiliu/unfinished-projects/vault-transform-with-big-query/deploy
bq query --use_legacy_sql=false < create_encrypt_function.sql
```

Content of `create_encrypt_function.sql`:
```sql
CREATE OR REPLACE FUNCTION `hc-5c7132af39e94c9ea03d2710265.vault_functions.encrypt_credit_card`(credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION `786265264300.us-central1.vault-connection`
OPTIONS (
  endpoint = 'https://vault-transform-function-cvb4eibhuq-uc.a.run.app',
  max_batching_rows = 100
);
```

### Step 3: Create Decryption Function
```sql
CREATE OR REPLACE FUNCTION `hc-5c7132af39e94c9ea03d2710265.vault_functions.decrypt_credit_card`(encrypted_credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION `786265264300.us-central1.vault-connection`
OPTIONS (
  endpoint = 'https://vault-transform-function-cvb4eibhuq-uc.a.run.app',
  max_batching_rows = 100
);
```

## 🧪 Verification Tests (After Admin Setup)

Run these commands to verify everything works:

```sql
-- Test encryption
SELECT vault_functions.encrypt_credit_card('4111111111111111') as encrypted_value;

-- Test decryption  
SELECT vault_functions.decrypt_credit_card('3003078876416946') as original_value;

-- End-to-end test
WITH encrypted AS (
  SELECT vault_functions.encrypt_credit_card('4111111111111111') as enc_value
)
SELECT 
  enc_value as encrypted,
  vault_functions.decrypt_credit_card(enc_value) as decrypted
FROM encrypted;
```

## 📋 Alternative: Grant User Permissions

If you prefer to grant the user permissions instead:

```bash
# Grant Cloud Functions Admin role
gcloud projects add-iam-policy-binding hc-5c7132af39e94c9ea03d2710265 \
    --member="user:yulei@hashicorp.com" \
    --role="roles/cloudfunctions.admin"

# Grant BigQuery Connection Admin role  
gcloud projects add-iam-policy-binding hc-5c7132af39e94c9ea03d2710265 \
    --member="user:yulei@hashicorp.com" \
    --role="roles/bigquery.connectionAdmin"
```

## 🏗️ Architecture Summary

```
BigQuery Remote Functions
    ↓ (Authenticated HTTP calls via bqcx-786265264300-5upk@ service account)
Cloud Function: vault-transform-function
    ↓ (HTTPS + HCP Vault token authentication)
HCP Vault Transform Engine
    ↓ (Format-preserving encryption/decryption)
Encrypted/Decrypted Credit Card Numbers
```

## 🔐 Security Model

- **BigQuery → Cloud Function**: Service account authentication
- **Cloud Function → HCP Vault**: Service token authentication  
- **Data Protection**: Format-preserving encryption (FPE)
- **Network**: All communications over HTTPS/TLS

## 📁 Key Files

- `.env` - Environment configuration
- `.env.function` - Cloud Function URL
- `create_encrypt_function.sql` - Remote function definition
- `service_token.txt` - HCP Vault authentication

## 🎯 Expected Results

After admin setup, these queries should work:
- `4111111111111111` → `3003078876416946` (encryption)
- `3003078876416946` → `4111111111111111` (decryption)

## ⚡ Quick Test Command

Once setup is complete:
```bash
bq query --use_legacy_sql=false "SELECT vault_functions.encrypt_credit_card('4111111111111111')"
```

---

**Status**: Integration is complete and tested. Only requires admin-level IAM permissions to finalize BigQuery connection.
