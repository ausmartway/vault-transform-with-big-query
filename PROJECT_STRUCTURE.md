# 🗂️ Project Structure - Vault Transform + BigQuery Integration

## 📁 Essential Files

### `/deploy/` - Deployment & Configuration
```
├── .env.template              # Environment template (copy to .env)
├── .env.function             # Cloud Function URL (auto-generated)
├── service_token.txt         # HCP Vault service token
├── activate.sh               # Environment activation script
│
├── setup_hcp_transform.sh    # HCP Vault setup script ✅ COMPLETED
├── deploy_production.sh      # Full GCP deployment script
│
├── ADMIN_SETUP_REQUIRED.md   # 🎯 Final admin commands needed
├── CLOUD_DEPLOYMENT.md       # Deployment guide
├── HCP_QUICK_SETUP.md        # HCP Vault setup guide
├── hcp_vault_setup.md        # Detailed HCP setup
├── README.md                 # Main documentation
└── setup_prerequisites.sh    # Prerequisites check
```

### `/deploy/cloud-function/` - Cloud Function Source
```
├── main.py                   # Cloud Function code
└── requirements.txt          # Python dependencies
```

### Other Directories
```
├── /src/                     # Original source code
├── /docker/                  # Docker development environment  
├── /docs/                    # Additional documentation
├── /config/                  # Configuration files
├── /sql/                     # SQL examples and scripts
├── /scripts/                 # Utility scripts
└── /tests/                   # Test files
```

## 🎯 Current Status: 99% Complete

**✅ Working Components:**
- HCP Vault Transform engine configured
- Cloud Function deployed: `https://vault-transform-function-cvb4eibhuq-uc.a.run.app`
- BigQuery datasets and connection created
- All code and configurations ready

**⚠️ Final Step Required:**
See `ADMIN_SETUP_REQUIRED.md` for the final commands an admin needs to run.

## 🚀 Quick Start

1. **Copy environment template:**
   ```bash
   cd deploy
   cp .env.template .env
   # Edit .env with your values
   ```

2. **Set up HCP Vault (if needed):**
   ```bash
   ./setup_hcp_transform.sh
   ```

3. **Deploy to GCP:**
   ```bash
   ./deploy_production.sh
   ```

4. **Complete setup (admin required):**
   Follow instructions in `ADMIN_SETUP_REQUIRED.md`

## 📋 Key Endpoints

- **HCP Vault**: `https://vault-plus-demo-public-vault-16765abc.e222d45b.z1.hashicorp.cloud:8200`
- **Cloud Function**: `https://vault-transform-function-cvb4eibhuq-uc.a.run.app`
- **Project**: `hc-5c7132af39e94c9ea03d2710265`

## 🧪 Test Commands (After Admin Setup)

```sql
-- Encrypt credit card
SELECT vault_functions.encrypt_credit_card('4111111111111111') as encrypted;

-- Decrypt credit card  
SELECT vault_functions.decrypt_credit_card('3003078876416946') as decrypted;
```
