# Updated Deployment Guide: HCP Vault Integration

## 🔑 Key Changes for Cloud Deployment

Your production deployment now requires **HCP Vault (HashiCorp Cloud Platform)** instead of local Vault because:

- ❌ Cloud Functions **cannot** access `localhost` or local networks
- ✅ HCP Vault provides cloud-accessible endpoints
- ✅ Secure, managed Vault with enterprise features

## 📋 Updated Deployment Steps

### Step 1: Set Up HCP Vault (REQUIRED)

**Before any GCP deployment**, configure HCP Vault:

```bash
# Read the detailed setup guide
cat hcp_vault_setup.md

# Key points:
# - Create HCP Vault cluster (Standard/Plus tier)
# - Enable Transform secrets engine
# - Configure creditcard-fpe transformation
# - Create service token for Cloud Function
```

### Step 2: Update Environment Variables

Your `.env` file now requires HCP Vault URLs:

```bash
# OLD (won't work with Cloud Functions)
export VAULT_ADDR=http://localhost:8200

# NEW (required for Cloud Functions)
export VAULT_ADDR=https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200
export VAULT_TOKEN=hvs.your-hcp-service-token
```

### Step 3: Validate Setup

The prerequisites script now checks for HCP Vault:

```bash
cd deploy
./setup_prerequisites.sh
```

This will:
- ❌ Reject localhost Vault URLs
- ✅ Test HCP Vault connectivity
- ✅ Verify Transform engine is configured

### Step 4: Deploy (Same Process)

```bash
source .env
./deploy_production.sh
```

## 🔧 What Changed in the Scripts

### Prerequisites Script (`setup_prerequisites.sh`)
- Added localhost detection and warnings
- Added HCP Vault connectivity testing
- Added Transform engine validation
- Updated environment template with HCP Vault URLs

### Deployment Script (`deploy_production.sh`)
- Added localhost URL validation
- Enhanced HCP Vault connection testing
- Updated success messages to mention HCP Vault

### Documentation
- Created `hcp_vault_setup.md` with complete HCP Vault configuration
- Updated README.md with HCP Vault requirements

## 🎯 Benefits of HCP Vault

1. **Cloud Native**: Accessible from Google Cloud Functions
2. **Managed Service**: No infrastructure maintenance
3. **Enterprise Features**: Transform engine included
4. **High Availability**: Multi-region deployment
5. **Security**: Built-in monitoring and audit logging

## 🚨 Important Notes

- **Local development** still works with the existing docker-compose setup
- **Production deployment** requires HCP Vault
- **Cost**: HCP Vault Standard ~$0.50/hour, Plus ~$2.00/hour
- **Setup time**: ~15 minutes to configure HCP Vault

## 📖 Complete Setup Guide

1. **Read HCP Setup**: `cat hcp_vault_setup.md`
2. **Check Prerequisites**: `./setup_prerequisites.sh`
3. **Deploy to GCP**: `./deploy_production.sh`

The deployment process remains the same - just the Vault endpoint changes from localhost to HCP Vault cloud URL!
