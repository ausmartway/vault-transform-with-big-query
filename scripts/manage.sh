#!/bin/bash

# Vault Transform BigQuery Integration Management Script
# This script manages Vault Transform Secret Engine and BigQuery simulator environments

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if .env file exists
    if [ ! -f .env ]; then
        print_error ".env file not found. Please create it with:"
        echo "VAULT_LICENSE=your-license-content"
        echo "PROJECT_ID=test-project"
        exit 1
    fi

    # Load environment variables
    export $(grep -v '^#' .env | xargs)

    # Validate required environment variables
    if [ -z "$VAULT_LICENSE" ]; then
        print_error "VAULT_LICENSE not set in .env file"
        exit 1
    fi

    if [ -z "$PROJECT_ID" ]; then
        print_error "PROJECT_ID not set in .env file"
        exit 1
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker Desktop"
        exit 1
    fi

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker Desktop"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Function to start Docker services
start_services() {
    local profile=${1:-full}
    
    print_status "Starting services with profile: $profile"
    
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        if [ "$profile" = "vault" ]; then
            docker compose -f docker/docker-compose.yml up vault -d
        else
            docker compose -f docker/docker-compose.yml --profile $profile up --build -d
        fi
    elif command -v docker-compose &> /dev/null; then
        if [ "$profile" = "vault" ]; then
            docker-compose -f docker/docker-compose.yml up vault -d
        else
            docker-compose -f docker/docker-compose.yml --profile $profile up --build -d
        fi
    else
        print_error "Neither 'docker compose' nor 'docker-compose' command found"
        exit 1
    fi
}

# Function to setup Vault Transform Secret Engine
setup_vault() {
    print_status "Setting up Vault Transform Secret Engine..."
    
    # Wait for Vault to be ready
    print_status "Waiting for Vault to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8200/v1/sys/health &> /dev/null; then
            break
        fi
        print_status "Attempt $attempt/$max_attempts: Waiting for Vault..."
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Vault did not become ready in time"
        exit 1
    fi

    print_success "Vault is ready"

    # Setup Transform Secret Engine
    export VAULT_ADDR=http://localhost:8200
    export VAULT_TOKEN=myroot

    # Enable transform secrets engine (ignore if already enabled)
    vault secrets enable -path=transform transform 2>/dev/null || print_warning "Transform engine already enabled"

    # Create alphabet for credit card numbers
    vault write transform/alphabet/creditcard-numbers \
        alphabet="0123456789" || print_error "Failed to create alphabet"

    # Create template for credit card format (16 digits)
    vault write transform/template/creditcard-16-digits \
        type=regex \
        pattern='(\d{4})(\d{4})(\d{4})(\d{4})' \
        alphabet=creditcard-numbers || print_error "Failed to create template"

    # Create FPE transformation
    vault write transform/transformation/creditcard-fpe \
        type=fpe \
        template=creditcard-16-digits \
        tweak_source=internal \
        allowed_roles="creditcard-transform" || print_error "Failed to create transformation"

    # Create role for the transformation
    vault write transform/role/creditcard-transform \
        transformations=creditcard-fpe || print_error "Failed to create role"

    print_success "Vault Transform Secret Engine setup complete"
}

# Function to stop services
stop_services() {
    print_status "Stopping all services..."
    
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose -f docker/docker-compose.yml --profile full down
    elif command -v docker-compose &> /dev/null; then
        docker-compose -f docker/docker-compose.yml --profile full down
    fi
    
    print_success "All services stopped"
}

# Function to show service status
show_status() {
    print_status "Service Status:"
    
    # Check Vault
    if curl -s http://localhost:8200/v1/sys/health &> /dev/null; then
        print_success "Vault: Running at http://localhost:8200"
    else
        print_warning "Vault: Not running"
    fi
    
    # Check BigQuery Simulator
    if curl -s http://localhost:9050 &> /dev/null; then
        print_success "BigQuery Simulator: Running at http://localhost:9050"
    else
        print_warning "BigQuery Simulator: Not running"
    fi
    
    # Check Cloud Function
    if curl -s http://localhost:8080 &> /dev/null; then
        print_success "Cloud Function: Running at http://localhost:8080"
    else
        print_warning "Cloud Function: Not running"
    fi
}

# Function to setup BigQuery sample data
setup_bigquery_data() {
    print_status "Setting up BigQuery sample data..."
    
    if [ ! -f scripts/setup_bigquery_data.py ]; then
        print_error "BigQuery data setup script not found"
        exit 1
    fi
    
    # Check if BigQuery is running
    if ! curl -s http://localhost:9050 &> /dev/null; then
        print_error "BigQuery emulator is not running. Start it first with: $0 start"
        exit 1
    fi
    
    # Run the setup script
    if python scripts/setup_bigquery_data.py; then
        print_success "BigQuery sample data setup complete"
        echo ""
        print_status "You can now run test queries with:"
        echo "  python scripts/test_bigquery_queries.py"
    else
        print_error "Failed to setup BigQuery sample data"
        exit 1
    fi
}

# Function to run BigQuery test queries
test_bigquery() {
    print_status "Running BigQuery test queries..."
    
    if [ ! -f scripts/test_bigquery_queries.py ]; then
        print_error "BigQuery test script not found"
        exit 1
    fi
    
    # Check if BigQuery is running
    if ! curl -s http://localhost:9050 &> /dev/null; then
        print_error "BigQuery emulator is not running. Start it first with: $0 start"
        exit 1
    fi
    
    python scripts/test_bigquery_queries.py
}

# Function to demonstrate encrypted data queries
demo_encrypted_queries() {
    print_status "Running encrypted data query demo..."
    
    if [ ! -f scripts/query_encrypted_data.py ]; then
        print_error "Encrypted query demo script not found"
        exit 1
    fi
    
    # Check if services are running
    if ! curl -s http://localhost:9050 &> /dev/null; then
        print_error "BigQuery emulator is not running. Start it first with: $0 start"
        exit 1
    fi
    
    if ! curl -s http://localhost:8080 &> /dev/null; then
        print_error "Cloud Function is not running. Start it first with: $0 start"
        exit 1
    fi
    
    python scripts/query_encrypted_data.py
}

# Function to run tests
run_tests() {
    print_status "Running function tests..."
    
    if [ ! -f tests/test_direct.py ]; then
        print_error "Test file tests/test_direct.py not found"
        exit 1
    fi
    
    # Activate virtual environment if it exists
    if [ -f .venv/bin/activate ]; then
        source .venv/bin/activate
        cd tests && python test_direct.py
    else
        cd tests && python3 test_direct.py
    fi
    print_success "Tests completed"
}

# Function to show help
show_help() {
    echo "Vault Transform BigQuery Integration Management"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start [full|bigquery|vault]  Start services (default: full)"
    echo "  stop                         Stop all services"
    echo "  status                       Show service status"
    echo "  test                         Run function tests"
    echo "  setup                        Setup Vault Transform engine only"
    echo "  setup-bigquery               Setup BigQuery sample data"
    echo "  test-bigquery                Run BigQuery test queries"
    echo "  demo-encrypted               Demo querying encrypted data with real card numbers"
    echo "  clean                        Clean up Docker containers and volumes"
    echo "  help                         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                     Start complete environment"
    echo "  $0 start vault               Start only Vault"
    echo "  $0 start bigquery            Start Vault + BigQuery"
    echo "  $0 stop                      Stop all services"
    echo "  $0 status                    Check what's running"
    echo "  $0 test                      Run tests"
}

# Main script logic
main() {
    local command=${1:-help}
    
    case $command in
        start)
            local profile=${2:-full}
            check_prerequisites
            start_services $profile
            if [ "$profile" != "vault" ]; then
                sleep 10  # Wait for services to start
            else
                sleep 5
            fi
            setup_vault
            show_status
            echo ""
            print_success "Environment ready!"
            if [ "$profile" = "full" ] || [ "$profile" = "bigquery" ]; then
                echo ""
                print_status "🧪 Test the setup:"
                echo "  • Run test queries: See docs/test_queries.md"
                echo "  • Direct function test: $0 test"
            fi
            ;;
        stop)
            stop_services
            ;;
        status)
            show_status
            ;;
        test)
            run_tests
            ;;
        setup)
            setup_vault
            ;;
        setup-bigquery)
            setup_bigquery_data
            ;;
        test-bigquery)
            test_bigquery
            ;;
        demo-encrypted)
            demo_encrypted_queries
            ;;
        clean)
            print_status "Cleaning up Docker containers and volumes..."
            docker compose -f docker/docker-compose.yml --profile full down -v 2>/dev/null || true
            docker system prune -f
            print_success "Cleanup completed"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
