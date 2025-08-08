# Project Structure

This project provides a Google Cloud Function that integrates Hashicorp Vault Transform Secret Engine with BigQuery for secure fraud detection workflows.

## 📁 Directory Structure

```
vault-transform-with-big-query/
├── README.md                   # Main project documentation
├── .env                        # Environment variables (local development)
├── .envrc                      # direnv configuration
├── .gitignore                  # Git ignore patterns
│
├── src/                        # Source code
│   ├── main.py                 # Main Cloud Function (encrypt/decrypt endpoints)
│   └── requirements.txt        # Python dependencies
│
├── docker/                     # Docker configuration
│   ├── docker-compose.yml      # Multi-service container setup
│   └── Dockerfile.dev          # Development container for Cloud Function
│
├── scripts/                    # Automation scripts
│   └── manage.sh               # Single comprehensive management script
│
├── config/                     # Configuration files
│   └── bigquery-data/          # BigQuery simulator test data
│       └── data.yaml           # Sample datasets and tables
│
├── tests/                      # Test scripts
│   └── test_direct.py          # Direct testing of Cloud Function
│
└── docs/                       # Documentation
    └── test_queries.md         # BigQuery SQL test queries
```

## 🚀 Quick Start

### Simple Commands
```bash
# Start everything
make start
# or
./run start

# Start just Vault
make vault  
# or
./run start vault

# Stop everything
make stop
# or  
./run stop

# Check status
make status
# or
./run status
```

## 🧪 Testing

### Direct Function Testing
```bash
make test
# or
./run test
```

### BigQuery SQL Testing
1. Start the complete environment: `make start` or `./run start`
2. Open BigQuery simulator at localhost:9050
3. Run queries from `docs/test_queries.md`

## 🌐 Service Endpoints

- **Vault UI**: http://localhost:8200
- **BigQuery Simulator**: http://localhost:9050
- **Cloud Function**: http://localhost:8080

## 📝 Configuration

Environment variables are managed in `.env`:
- `VAULT_LICENSE`: Your Hashicorp Vault Enterprise license
- `VAULT_ADDR`: Vault server address (default: http://localhost:8200)
- `PROJECT_ID`: BigQuery project ID (default: test-project)

## 📦 Components

- **Vault Transform Engine**: Credit card encryption/decryption
- **BigQuery Remote Functions**: SQL-callable encrypt/decrypt endpoints
- **Fraud Detection Simulator**: Sample datasets for testing
- **Local Development Environment**: Complete Docker-based setup
