# Vault Policy for Transform Secret Engine Access
# This policy allows the Cloud Function to encrypt and decrypt using the Transform Secret Engine

# Allow encoding (encryption) using the creditcard-transform role
path "transform/encode/creditcard-transform" {
  capabilities = ["create", "update"]
}

# Allow decoding (decryption) using the creditcard-transform role
path "transform/decode/creditcard-transform" {
  capabilities = ["create", "update"]
}
