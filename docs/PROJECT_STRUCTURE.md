# Project Structure

A production-ready integration for HashiCorp Vault Transform Secret Engine with BigQuery for secure fraud detection workflows.

## 📁 Directory Structure

```
vault-transform-with-big-query/
├── README.md                           # Main project documentation
├── deploy/                            # Production deployment
│   ├── deploy_production.sh          #   Main deployment script
│   ├── setup_prerequisites.sh        #   Prerequisites checker
│   ├── setup_hcp_transform.sh        #   HCP Vault configuration
│   ├── .env.template                 #   Environment template
│   ├── README.md                     #   Deployment guide
│   ├── ADMIN_SETUP_REQUIRED.md       #   Final admin steps
│   ├── HCP_QUICK_SETUP.md            #   Quick HCP Vault setup
│   ├── activate.sh                   #   Environment activation
│   ├── service_token.txt             #   HCP Vault service token
│   ├── bigquery_setup.sql            #   BigQuery schema
│   ├── create_encrypt_function.sql   #   Function creation SQL
│   └── cloud-function/               #   Cloud Function source
│       ├── main.py                   #     Function implementation
│       └── requirements.txt          #     Python dependencies
├── sql/                              # SQL scripts
│   └── bigquery_setup.sql            #   BigQuery schema and functions
├── scripts/                          # Utility scripts
│   ├── interactive_query.py          #   Interactive query tool
│   └── query_encrypted_data.py       #   Data query examples
└── docs/                             # Documentation
    ├── PROJECT_STRUCTURE.md          #   This file
    └── encrypted_queries.md          #   Query examples
```

## 🚀 Quick Start

### Prerequisites
- Google Cloud Platform account with billing enabled
- HCP Vault (Standard/Plus tier for Transform engine)
- Project Owner/Editor role in GCP

### Simple Deployment
```bash
# 1. Setup prerequisites
cd deploy
./setup_prerequisites.sh

# 2. Configure environment
cp .env.template .env
# Edit .env with your HCP Vault and GCP details
source .env

# 3. Deploy everything
./deploy_production.sh
```

## 🎯 Current Status: Production Ready

**✅ Key Components:**
- **HCP Vault Integration**: Transform engine for format-preserving encryption
- **Cloud Function**: Python function handling BigQuery remote function calls
- **BigQuery Remote Functions**: SQL-callable encrypt/decrypt endpoints
- **Automated Deployment**: Complete GCP deployment script
- **Comprehensive Documentation**: Setup guides and examples

## 🌐 Production Endpoints

After deployment, you'll have:
- **Cloud Function**: `https://vault-transform-function-{hash}.a.run.app`
- **BigQuery Dataset**: `{project}.fraud_detection`
- **Remote Functions**: `encrypt_credit_card()`, `decrypt_credit_card()`

## 🧪 Testing

### Function Test
```bash
curl -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d '{"requestId": "test-1", "calls": [["4111111111111111"]]}'
```

### BigQuery Test
```bash
bq query "SELECT vault_functions.encrypt_credit_card('4111111111111111')"
```

### Interactive Testing
```bash
python3 scripts/interactive_query.py
```

## 📦 Key Features

- **Format-Preserving Encryption**: Credit card numbers remain 16 digits
- **Production Ready**: Deployed to Google Cloud Platform
- **Zero Trust**: All data encrypted at application layer
- **SQL Transparent**: Use encryption/decryption in BigQuery SQL queries
- **Secure**: HCP Vault managed encryption keys and policies
- **Scalable**: Cloud Function auto-scales based on BigQuery demand

## 📝 Configuration

Environment variables in `deploy/.env`:
- `PROJECT_ID`: Your GCP project ID
- `VAULT_ADDR`: HCP Vault server address
- `VAULT_TOKEN`: HCP Vault authentication token
- `VAULT_ROLE`: Vault role for transform operations
- `VAULT_TRANSFORMATION`: Transform engine transformation name
