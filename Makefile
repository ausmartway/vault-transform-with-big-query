# Makefile for Vault Transform BigQuery Integration

.PHONY: help start stop vault bigquery test clean build status

# Default target
help:
	@echo "🔧 Vault Transform BigQuery Integration"
	@echo ""
	@echo "📋 Available commands:"
	@echo "  make start     - Start complete BigQuery testing environment"
	@echo "  make vault     - Start Vault-only environment"
	@echo "  make bigquery  - Start Vault + BigQuery environment"
	@echo "  make stop      - Stop all services"
	@echo "  make status    - Show service status"
	@echo "  make test      - Run direct function tests"
	@echo "  make clean     - Clean up Docker containers and volumes"
	@echo "  make build     - Build Docker images"
	@echo ""
	@echo "🌐 Service endpoints:"
	@echo "  • Vault UI: http://localhost:8200"
	@echo "  • BigQuery Simulator: http://localhost:9050"
	@echo "  • Cloud Function: http://localhost:8080"

# Start complete environment
start:
	@./scripts/manage.sh start full

# Start Vault only
vault:
	@./scripts/manage.sh start vault

# Start Vault + BigQuery
bigquery:
	@./scripts/manage.sh start bigquery

# Stop all services
stop:
	@./scripts/manage.sh stop

# Show service status
status:
	@./scripts/manage.sh status

# Run tests
test:
	@./scripts/manage.sh test

# Clean up everything
clean:
	@./scripts/manage.sh clean

# Build Docker images
build:
	@echo "🔨 Building Docker images..."
	@docker compose -f docker/docker-compose.yml build
