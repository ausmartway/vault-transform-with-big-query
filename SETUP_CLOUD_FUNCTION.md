# Cloud Function Setup Script

## Overview

The `setup-cloud-function.sh` script provides a complete automation solution for deploying and testing the Vault Transform Cloud Function.

## Features

### 🔧 **Automated Setup**
- ✅ Checks prerequisites (gcloud CLI, authentication)
- ✅ Validates Vault Transform configuration
- ✅ Deploys Cloud Function to correct GCP region
- ✅ Runs comprehensive tests

### 🧪 **Comprehensive Testing**
- ✅ Encryption functionality test
- ✅ Decryption functionality test  
- ✅ Round-trip validation
- ✅ Format preservation verification
- ✅ Health check

### 🌏 **Regional Configuration**
- ✅ Auto-detects GCP region settings
- ✅ Deploys to `australia-southeast1` (or configured region)
- ✅ Uses correct project ID from gcloud config

## Usage

### Quick Start
```bash
./setup-cloud-function.sh
```

### Prerequisites
1. **Google Cloud CLI** installed and authenticated
2. **HCP Vault cluster** with Transform engine configured
3. **Vault tokens** (admin or client token)
4. **GCP project** with necessary APIs enabled

### Environment Variables
The script automatically detects and uses:
- `PROJECT_ID` - From gcloud config
- `REGION` - From gcloud config (default: australia-southeast1)
- `VAULT_ADDR` - HCP Vault cluster URL
- `VAULT_CLIENT_TOKEN` - Client token (preferred)
- `VAULT_TOKEN` - Admin token (fallback)

## Script Flow

### 1. Prerequisites Check
- ✅ Verifies gcloud CLI installation
- ✅ Checks authentication status
- ✅ Gets project and region settings
- ✅ Validates Vault configuration

### 2. Vault Setup Verification
- ✅ Checks for Vault address and tokens
- ✅ Runs `setup-transform.sh` if needed
- ✅ Validates Transform engine setup

### 3. Cloud Function Deployment
- ✅ Calls `deploy/deploy_production.sh`
- ✅ Deploys to correct region
- ✅ Configures environment variables
- ✅ Handles IAM permission warnings

### 4. Comprehensive Testing
- ✅ Tests encryption with multiple credit cards
- ✅ Tests decryption functionality
- ✅ Verifies round-trip accuracy
- ✅ Validates format preservation

### 5. Summary Report
- ✅ Displays deployment details
- ✅ Shows test results
- ✅ Provides next steps
- ✅ Includes testing commands

## Test Results Example

```
📋 Deployment Summary:
======================
Function Name: vault-transform-function
Project ID: hc-5c7132af39e94c9ea03d2710265
Region: australia-southeast1
Account: yulei@hashicorp.com

🔐 Vault Configuration:
Vault Address: https://vault-cluster.vault.aws.hashicorp.cloud:8200
Vault Namespace: admin
Transform Role: creditcard-transform

✅ Verified Functionality:
• Credit card encryption (FPE)
• Credit card decryption
• Round-trip validation
• BigQuery Remote Function format
```

## Manual Testing Commands

### Encrypt Test
```bash
gcloud functions call vault-transform-function \
  --region=australia-southeast1 \
  --data='{"calls":[["4111111111111111"]]}'
```

### Decrypt Test
```bash
gcloud functions call vault-transform-function \
  --region=australia-southeast1 \
  --data='{"mode":"decrypt","calls":[["3003078876416946"]]}'
```

## Error Handling

The script handles common issues:
- ❌ **Missing gcloud CLI** - Provides installation instructions
- ❌ **Not authenticated** - Prompts for `gcloud auth login`
- ❌ **No project set** - Prompts for project configuration
- ❌ **Missing Vault tokens** - Runs setup-transform.sh automatically
- ⚠️ **IAM permission warnings** - Continues deployment (expected in some environments)

## Next Steps After Successful Setup

1. **Create BigQuery Remote Function connections**
2. **Set up BigQuery IAM permissions**
3. **Create SQL functions for encrypt/decrypt**
4. **Test with real BigQuery queries**

## Files Created/Modified

- `setup-cloud-function.sh` - Main setup script
- `deploy/cloud-function/` - Function source code
- `creditcard-transform-policy.hcl` - Vault policy file
- `.env` - Updated environment configuration

## Security Features

- ✅ Uses client tokens with minimal Vault permissions
- ✅ Validates Vault connectivity before deployment
- ✅ Tests with non-production credit card numbers
- ✅ Handles authentication securely through gcloud
