# BigQuery Emulator Remote Function Support Analysis

## Executive Summary

**BigQuery emulator does NOT support remote functions or external connections to Cloud Functions.**

This has been confirmed through comprehensive testing and examination of the BigQuery emulator source code and documentation.

## Test Results

### ❌ Unsupported Features

| Feature | Status | Error Message |
|---------|--------|---------------|
| External Connections | ❌ Not Supported | `Syntax error: Expected keyword TABLE but got keyword CONNECTION` |
| Remote Functions | ❌ Not Supported | `Keyword REMOTE is not supported` |
| HTTP Functions | ❌ Not Supported | `Function not found: NET.HTTP_GET` |

### ✅ Supported Features

| Feature | Status | Notes |
|---------|--------|-------|
| Basic SQL Queries | ✅ Supported | Full functionality |
| Regular UDFs | ✅ Supported | Standard SQL UDFs work |
| JavaScript UDFs | ✅ Supported | Creation succeeds |
| Standard Functions | ✅ Supported | 200+ functions available |

## BigQuery Emulator Architecture

The BigQuery emulator (`ghcr.io/goccy/bigquery-emulator:0.4.3`) is built on:

- **go-zetasqlite**: Parses Google Standard SQL and converts to SQLite
- **SQLite backend**: All data stored in SQLite database
- **ZetaSQL parser**: Uses Google's ZetaSQL for query parsing

**Key Limitation**: The emulator focuses on SQL query compatibility, not Google Cloud service integrations like external connections or remote functions.

## Production vs Local Development

### Production BigQuery (Google Cloud)

```sql
-- 1. Create external connection
CREATE OR REPLACE EXTERNAL CONNECTION `project.region.vault-connection`
OPTIONS (
  type = 'CLOUD_RESOURCE',
  endpoint = 'https://your-cloud-function-url'
);

-- 2. Create remote function
CREATE OR REPLACE FUNCTION `project.vault_functions.encrypt_credit_card`(card STRING)
RETURNS STRING
REMOTE WITH CONNECTION `project.region.vault-connection`;

-- 3. Use in queries seamlessly
SELECT * FROM transactions 
WHERE encrypted_card = vault_functions.encrypt_credit_card('4111111111111111');
```

### Local Development (BigQuery Emulator)

```python
# 1. Direct HTTP call to Cloud Function
def encrypt_credit_card(card_number):
    response = requests.post('http://localhost:8080', json={
        "requestId": "encrypt-query",
        "calls": [[card_number]]
    })
    return response.json()['replies'][0]

# 2. Use encrypted value in standard SQL
encrypted_value = encrypt_credit_card('4111111111111111')
sql = f"SELECT * FROM transactions WHERE encrypted_card = '{encrypted_value}'"
```

## Our Implementation Strategy

### ✅ Current Approach (Correct)

1. **Cloud Function**: Implements Google Cloud Functions Framework interface
   - Accepts BigQuery remote function request format
   - Returns BigQuery remote function response format
   - Compatible with both local testing and production deployment

2. **Local Development**: Direct HTTP calls to Cloud Function
   - Simulates what BigQuery would do in production
   - Same encryption/decryption logic
   - Same request/response format

3. **Production Deployment**: BigQuery remote functions
   - Same Cloud Function code
   - BigQuery handles HTTP calls automatically
   - Seamless encryption/decryption in SQL

### ❌ Alternative Approaches (Not Viable)

1. **Mock BigQuery Remote Functions**: Not possible due to parser limitations
2. **Patch BigQuery Emulator**: Would require complex ZetaSQL modifications
3. **Custom SQL Functions**: Emulator doesn't support external function registration

## Verification Methods

### 1. Direct Testing
```bash
./scripts/manage.sh test-emulator
```
Systematically tests all remote function related features.

### 2. Error Analysis
- `CREATE EXTERNAL CONNECTION`: Parser doesn't recognize CONNECTION keyword
- `CREATE FUNCTION ... REMOTE`: REMOTE keyword not supported
- `NET.HTTP_*`: Network functions not implemented

### 3. Source Code Review
- No external connection handling in emulator codebase
- No remote function infrastructure
- Focus on SQL compatibility, not cloud service integration

## Recommendations

### ✅ Keep Current Approach
Our workaround is:
- **Architecturally sound**: Same function code works in both environments
- **Functionally equivalent**: Same encryption logic and data flow
- **Production ready**: Cloud Function easily deployable to Google Cloud
- **Well tested**: Comprehensive demos and test scripts

### 📋 Documentation
- `sql/bigquery_setup.sql`: Production remote function setup
- `scripts/bigquery_connection_demo.py`: Shows local vs production approaches
- `scripts/test_emulator_remote_functions.py`: Comprehensive capability testing

### 🔄 Migration Path
When moving to production:
1. Deploy Cloud Function to Google Cloud
2. Run SQL commands from `sql/bigquery_setup.sql`
3. Replace direct HTTP calls with BigQuery remote function calls
4. No changes needed to encryption logic or data structure

## Conclusion

The BigQuery emulator's limitation regarding remote functions is:
- **Expected**: Emulator focuses on SQL compatibility, not cloud service integration
- **Well documented**: Our testing confirms the limitations
- **Properly handled**: Our workaround provides equivalent functionality
- **Production compatible**: Same code works in both environments

Our implementation correctly bridges the gap between local development constraints and production capabilities.
