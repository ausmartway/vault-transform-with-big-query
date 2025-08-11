# HCP Vault Setup for BigQuery Integration

## Overview

Since Google Cloud Functions cannot access local Vault instances, you need to use **HashiCorp Cloud Platform (HCP) Vault** or another cloud-accessible Vault deployment.

## Prerequisites

- HCP Account (sign up at https://cloud.hashicorp.com/)
- HCP Vault cluster (Standard or Plus tier required for Transform secrets engine)
- Admin access to configure the Vault cluster

## Step 1: Create HCP Vault Cluster

1. **Log into HCP Console**: https://cloud.hashicorp.com/
2. **Create Vault Cluster**:
   - Choose **Standard** or **Plus** tier (Transform engine requires these tiers)
   - Select region closest to your GCP deployment (e.g., `us-central1`)
   - Note the cluster URL (e.g., `https://vault-cluster-public-vault-12345.vault.abc123.aws.hashicorp.cloud:8200`)

3. **Generate Admin Token**:
   - Navigate to your cluster
   - Go to "Access" → "Generate Token"
   - Copy the root token for initial setup

## Step 2: Configure Transform Secrets Engine

Connect to your HCP Vault and configure the Transform secrets engine:

### Enable Transform Engine

```bash
# Set environment variables
export VAULT_ADDR="https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200"
export VAULT_TOKEN="hvs.your-admin-token"

# Enable transform secrets engine
vault auth -method=token token=$VAULT_TOKEN
vault secrets enable transform
```

### Create Transformation

```bash
# Create alphabet for credit card numbers (digits only)
vault write transform/alphabet/creditcard-digits \
    alphabet="0123456789"

# Create FPE transformation for credit cards
vault write transform/transformation/creditcard-fpe \
    type=fpe \
    template="creditcard-tmpl" \
    tweak_source=internal \
    allowed_roles="creditcard-transform"

# Create template for credit card format
vault write transform/template/creditcard-tmpl \
    type=regex \
    pattern='(\d{4})(\d{4})(\d{4})(\d{4})' \
    alphabet="creditcard-digits"

# Create role for the application
vault write transform/role/creditcard-transform \
    transformations="creditcard-fpe"
```

### Test the Configuration

```bash
# Test encoding
vault write transform/encode/creditcard-fpe \
    value="4111111111111111"

# Test decoding (use the encoded value from above)
vault write transform/decode/creditcard-fpe \
    value="your-encoded-value"
```

## Step 3: Create Service Account for Cloud Function

Instead of using a root token, create a dedicated service account:

### Create Policy

```bash
# Create policy file
cat > creditcard-policy.hcl << 'EOF'
path "transform/encode/creditcard-fpe" {
  capabilities = ["create", "update"]
}

path "transform/decode/creditcard-fpe" {
  capabilities = ["create", "update"]
}
EOF

# Apply policy
vault policy write creditcard-policy creditcard-policy.hcl
```

### Create Token with Limited Scope

```bash
# Create a long-lived token for the Cloud Function
vault token create \
    -policy="creditcard-policy" \
    -period=24h \
    -renewable=true \
    -display-name="bigquery-cloud-function"
```

## Step 4: Configure Network Access

### HCP Vault Network Settings

1. **Public Access**: Ensure your HCP Vault cluster allows public access (default)
2. **CIDR Allowlist**: Optionally restrict to Google Cloud IP ranges
3. **TLS**: HCP Vault uses TLS by default (port 8200)

### Google Cloud Function Network

No special configuration needed - Cloud Functions can access public HTTPS endpoints by default.

## Step 5: Update Environment Variables

Update your `.env` file with HCP Vault details:

```bash
# HCP Vault Configuration
export VAULT_ADDR="https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200"
export VAULT_TOKEN="hvs.your-service-token"  # Use the limited-scope token
export VAULT_ROLE="creditcard-transform"
export VAULT_TRANSFORMATION="creditcard-fpe"

# GCP Configuration
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
```

## Step 6: Verify Connectivity

Test HCP Vault access from your local machine:

```bash
# Source environment
source .env

# Test health endpoint
curl -s "$VAULT_ADDR/v1/sys/health" | jq .

# Test authentication
curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
     "$VAULT_ADDR/v1/auth/token/lookup-self" | jq .

# Test transform endpoint
curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
     -X POST \
     -d '{"value":"4111111111111111"}' \
     "$VAULT_ADDR/v1/transform/encode/creditcard-fpe" | jq .
```

## Security Best Practices

### Token Management

1. **Use AppRole Authentication** (recommended for production):
   ```bash
   # Enable AppRole
   vault auth enable approle
   
   # Create role
   vault write auth/approle/role/bigquery-function \
       token_policies="creditcard-policy" \
       token_ttl=1h \
       token_max_ttl=4h
   
   # Get role ID and secret ID for Cloud Function
   vault read auth/approle/role/bigquery-function/role-id
   vault write -f auth/approle/role/bigquery-function/secret-id
   ```

2. **Rotate Tokens Regularly**: Set up automated token renewal
3. **Monitor Usage**: Enable audit logging in HCP Vault

### Network Security

1. **VPC Peering** (for enhanced security):
   - Set up VPC peering between GCP and HCP
   - Use private endpoints

2. **IP Allowlisting**:
   - Restrict access to known Google Cloud IP ranges
   - Use Cloud NAT for consistent outbound IPs

## Troubleshooting

### Common Issues

**Connection Timeout**:
```bash
# Check if URL is accessible
curl -v "$VAULT_ADDR/v1/sys/health"
```

**Authentication Errors**:
```bash
# Verify token is valid
curl -H "X-Vault-Token: $VAULT_TOKEN" \
     "$VAULT_ADDR/v1/auth/token/lookup-self"
```

**Transform Engine Not Available**:
- Ensure you're using Standard or Plus tier
- Verify transform engine is enabled: `vault secrets list`

### Debugging Commands

```bash
# Check HCP Vault cluster status
vault status

# List enabled secrets engines
vault secrets list

# Check transform configuration
vault list transform/transformation
vault read transform/transformation/creditcard-fpe

# Test from Cloud Function environment
# (run this from Cloud Shell or a GCP VM)
curl -H "X-Vault-Token: $VAULT_TOKEN" \
     -X POST \
     -d '{"value":"4111111111111111"}' \
     "$VAULT_ADDR/v1/transform/encode/creditcard-fpe"
```

## Cost Considerations

- **HCP Vault Standard**: ~$0.50/hour for small workloads
- **HCP Vault Plus**: ~$2.00/hour with advanced features
- **Data Transfer**: Minimal cost for API calls
- **High Availability**: Plus tier includes multi-region replication

## Next Steps

Once HCP Vault is configured:

1. Update `.env` with HCP Vault credentials
2. Run `./setup_prerequisites.sh` to verify connectivity
3. Deploy with `./deploy_production.sh`

Your Cloud Function will now be able to securely connect to HCP Vault for encryption/decryption operations!
