# Terraform configuration for Vault Transform Secret Engine
# Creates a custom FPE transformation for credit card numbers
# Use this if you prefer to manage Vault configuration with Terraform

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }
}

# Configure the Vault Provider
provider "vault" {
  # Vault address and token should be set via environment variables:
  # VAULT_ADDR and VAULT_TOKEN
}

# Enable Transform Secret Engine
resource "vault_mount" "transform" {
  path = "transform"
  type = "transform"
  description = "Transform Secret Engine for credit card encryption"
}

# Create alphabet for numeric characters
resource "vault_transform_alphabet" "numeric" {
  path      = vault_mount.transform.path
  name      = "numeric"
  alphabet  = "0123456789"
}

# Create template for credit card format
resource "vault_transform_template" "creditcard" {
  path     = vault_mount.transform.path
  name     = "creditcard"
  type     = "regex"
  pattern  = "(\\d{4})-?(\\d{4})-?(\\d{4})-?(\\d{4})"
  alphabet = vault_transform_alphabet.numeric.name
}

# Create FPE transformation
resource "vault_transform_transformation" "creditcard_fpe" {
  path           = vault_mount.transform.path
  name           = "creditcard-fpe"
  type           = "fpe"
  template       = vault_transform_template.creditcard.name
  tweak_source   = "internal"
  allowed_roles  = ["creditcard-transform"]
}

# Create role using our custom transformation
resource "vault_transform_role" "creditcard_transform" {
  path            = vault_mount.transform.path
  name            = "creditcard-transform"
  transformations = [vault_transform_transformation.creditcard_fpe.name]
}

# Create policy for Cloud Function access
resource "vault_policy" "transform_policy" {
  name = "transform-policy"

  policy = <<EOT
# Allow encoding (encryption) using the creditcard-transform role
path "transform/encode/creditcard-transform" {
  capabilities = ["create", "update"]
}

# Allow decoding (decryption) using the creditcard-transform role
path "transform/decode/creditcard-transform" {
  capabilities = ["create", "update"]
}
EOT
}

# Output the policy name for reference
output "policy_name" {
  value = vault_policy.transform_policy.name
  description = "Name of the policy created for Cloud Function access"
}

# Note: In production, create auth methods instead of tokens
# Example GCP auth method (uncomment if needed):
#
# resource "vault_gcp_auth_backend" "gcp" {
#   credentials = file("path/to/service-account.json")
# }
#
# resource "vault_gcp_auth_backend_role" "cloud_function" {
#   backend                = vault_gcp_auth_backend.gcp.path
#   role                   = "cloud-function-role"
#   type                   = "iam"
#   bound_service_accounts = ["your-cloud-function-sa@project.iam.gserviceaccount.com"]
#   token_policies         = [vault_policy.transform_policy.name]
# }
