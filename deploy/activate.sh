#!/bin/bash
if [ -f .env ]; then
    source .env
    echo "Environment loaded from .env"
    echo "Project: $PROJECT_ID"
    echo "Vault: $VAULT_ADDR"
else
    echo "Please create .env file from .env.template first"
    exit 1
fi
