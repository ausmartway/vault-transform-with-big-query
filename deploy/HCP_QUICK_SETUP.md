# Quick HCP Vault Setup Guide

## Prerequisites

- HCP Vault cluster already running (Standard or Plus tier)
- Admin token for the HCP Vault cluster
- `vault` CLI installed (`brew install vault`)

## One-Command Setup

```bash
# Set your HCP Vault details
export VAULT_ADDR=https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200
export VAULT_TOKEN=hvs.your-admin-token
export VAULT_NAMESPACE=admin

# Run the setup script
./setup_hcp_transform.sh
```

This script will:
1. ✅ Enable Transform secrets engine
2. ✅ Create credit card alphabet and template  
3. ✅ Configure FPE transformation
4. ✅ Create application role
5. ✅ Set up security policy
6. ✅ Generate service token for Cloud Function
7. ✅ Test the complete configuration

## What You Get

After running the script:

- **Transform Engine**: Configured for credit card encryption
- **Service Token**: Saved to `service_token.txt` 
- **Policy**: Least-privilege access for Cloud Function
- **Tested Configuration**: Verified encryption/decryption works

## Copy the Service Token

The script creates a service token for your Cloud Function:

```bash
# The script will output something like:
export VAULT_TOKEN=hvs.CAESIxxxxxxx...
export VAULT_NAMESPACE=admin

# Add these to your .env file:
echo "VAULT_TOKEN=hvs.CAESIxxxxxxx..." >> .env
echo "VAULT_NAMESPACE=admin" >> .env
```

## Verify Setup

```bash
# Test the configuration
./setup_hcp_transform.sh test

# Show current setup
./setup_hcp_transform.sh show
```

## Available Commands

```bash
./setup_hcp_transform.sh setup  # Full setup (default)
./setup_hcp_transform.sh test   # Test existing config
./setup_hcp_transform.sh show   # Display configuration
./setup_hcp_transform.sh token  # Create new service token
./setup_hcp_transform.sh clean  # Remove configuration
```

## After Setup

1. **Copy service token** to your `.env` file
2. **Run prerequisites check**: `./setup_prerequisites.sh`
3. **Deploy to GCP**: `./deploy_production.sh`

Your HCP Vault is now ready for the BigQuery integration! 🎉
