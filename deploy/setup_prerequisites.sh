#!/bin/bash
# Prerequisites check script for GCP deployment
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

print_step() { echo -e "\n${BLUE}📋 Step $1:${NC} $2"; }

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_warning "This script is optimized for macOS. Commands may differ on other systems."
fi

echo "🔧 Prerequisites Setup for Vault Transform + BigQuery Integration"
echo "This script will help you prepare your environment for production deployment."
echo ""

print_step "1" "Install Google Cloud SDK"
if command -v gcloud &> /dev/null; then
    print_success "gcloud CLI already installed"
    gcloud version
else
    print_status "Installing Google Cloud SDK..."
    echo "Run the following commands:"
    echo "curl https://sdk.cloud.google.com | bash"
    echo "exec -l \$SHELL"
    echo "gcloud init"
fi

print_step "2" "Authenticate with Google Cloud"
if gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 &> /dev/null; then
    current_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1)
    print_success "Already authenticated as: $current_account"
else
    print_warning "Not authenticated with Google Cloud"
    echo "Run: gcloud auth login"
fi

print_step "3" "Set up Google Cloud Project"
current_project=$(gcloud config get-value project 2>/dev/null || echo "none")
if [ "$current_project" != "none" ]; then
    print_success "Current project: $current_project"
    echo "To change project: gcloud config set project YOUR_PROJECT_ID"
else
    print_warning "No project set"
    echo "Set project: gcloud config set project YOUR_PROJECT_ID"
fi

print_step "4" "Check required environment variables"
echo "You need to set these environment variables before deployment:"
echo ""
print_warning "IMPORTANT: Use HCP Vault (cloud) - local Vault won't work with Cloud Functions!"
echo "See hcp_vault_setup.md for detailed setup instructions."
echo ""

if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID not set"
    echo "export PROJECT_ID=your-gcp-project-id"
else
    print_success "PROJECT_ID=$PROJECT_ID"
fi

if [ -z "$VAULT_ADDR" ]; then
    print_error "VAULT_ADDR not set"
    echo "export VAULT_ADDR=https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200"
    print_warning "Must be HCP Vault URL, not localhost!"
else
    if echo "$VAULT_ADDR" | grep -q "localhost\|127.0.0.1\|0.0.0.0"; then
        print_error "VAULT_ADDR points to localhost - Cloud Functions cannot access local services!"
        echo "Use HCP Vault instead: https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200"
    else
        print_success "VAULT_ADDR=$VAULT_ADDR"
    fi
fi

if [ -z "$VAULT_TOKEN" ]; then
    print_error "VAULT_TOKEN not set"
    echo "export VAULT_TOKEN=your-hcp-vault-token"
else
    print_success "VAULT_TOKEN=***[hidden]***"
fi

if [ -z "$VAULT_NAMESPACE" ]; then
    print_error "VAULT_NAMESPACE not set"
    echo "export VAULT_NAMESPACE=admin"
    print_warning "HCP Vault requires VAULT_NAMESPACE=admin"
else
    if [ "$VAULT_NAMESPACE" != "admin" ]; then
        print_error "VAULT_NAMESPACE must be 'admin' for HCP Vault"
        echo "export VAULT_NAMESPACE=admin"
    else
        print_success "VAULT_NAMESPACE=$VAULT_NAMESPACE"
    fi
fi

print_step "5" "Verify HCP Vault connectivity (if configured)"
if [ -n "$VAULT_ADDR" ] && [ -n "$VAULT_TOKEN" ] && [ -n "$VAULT_NAMESPACE" ]; then
    if echo "$VAULT_ADDR" | grep -q "localhost\|127.0.0.1\|0.0.0.0"; then
        print_error "Cannot test localhost Vault - Cloud Functions need cloud-accessible Vault!"
        print_warning "Please set up HCP Vault first (see hcp_vault_setup.md)"
    else
        print_status "Testing HCP Vault connection..."
        if command -v curl &> /dev/null; then
            vault_status=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" "$VAULT_ADDR/v1/sys/health" || echo "error")
            if echo "$vault_status" | grep -q "initialized"; then
                print_success "HCP Vault connection successful"
                
                # Test transform endpoint if available
                transform_test=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" \
                    -X POST \
                    -d '{"value":"4111111111111111"}' \
                    "$VAULT_ADDR/v1/transform/encode/creditcard-fpe" 2>/dev/null || echo "error")
                
                if echo "$transform_test" | grep -q "encoded_value"; then
                    print_success "Transform engine configured and working"
                else
                    print_warning "Transform engine not configured - run ./setup_hcp_transform.sh"
                fi
            else
                print_warning "HCP Vault connection failed or not configured properly"
                echo "Response: $vault_status"
            fi
        else
            print_warning "curl not available to test HCP Vault connection"
        fi
    fi
else
    print_warning "HCP Vault not fully configured - please set VAULT_ADDR, VAULT_TOKEN, and VAULT_NAMESPACE"
    if [ -z "$VAULT_NAMESPACE" ]; then
        print_warning "Missing VAULT_NAMESPACE=admin (required for HCP Vault)"
    fi
fi

print_step "6" "Check Python dependencies"
if command -v python3 &> /dev/null; then
    print_success "Python 3 available"
    python3 --version
    
    # Check for pip
    if python3 -m pip --version &> /dev/null; then
        print_success "pip available"
    else
        print_error "pip not available"
        echo "Install pip: python3 -m ensurepip --upgrade"
    fi
else
    print_error "Python 3 not found"
    echo "Install Python 3: brew install python"
fi

print_step "7" "Prepare environment file"
cat > .env.template << 'EOF'
# GCP Configuration
export PROJECT_ID=your-gcp-project-id

# HCP Vault Configuration (REQUIRED - local Vault won't work!)
export VAULT_ADDR=https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200
export VAULT_TOKEN=your-hcp-vault-token
export VAULT_NAMESPACE=admin
export VAULT_ROLE=creditcard-transform
export VAULT_TRANSFORMATION=creditcard-fpe

# Optional: Deployment Region
export REGION=us-central1
EOF

print_success "Created .env.template file"
echo "⚠️  IMPORTANT: Copy .env.template to .env and configure HCP Vault details"
echo "📖 See hcp_vault_setup.md for detailed HCP Vault setup instructions"

print_step "8" "Summary and next steps"
echo ""
print_success "Prerequisites check complete!"
echo ""
print_warning "🔑 CRITICAL: Set up HCP Vault before deployment!"
echo ""
echo "📋 Before running deployment:"
echo "  1. Set up HCP Vault cluster (see hcp_vault_setup.md)"
echo "  2. Configure Transform secrets engine in HCP Vault"
echo "  3. Set all required environment variables in .env file"
echo "  4. Ensure you have billing enabled on your GCP project"
echo ""
echo "🚀 To deploy:"
echo "  cp .env.template .env    # Configure with HCP Vault details"
echo "  source .env"
echo "  ./deploy_production.sh"
echo ""
echo "🧪 Available commands:"
echo "  ./deploy_production.sh deploy  # Full deployment"
echo "  ./deploy_production.sh test    # Test existing deployment"
echo "  ./deploy_production.sh clean   # Remove all resources"
echo ""
echo "📖 Documentation:"
echo "  • hcp_vault_setup.md - HCP Vault configuration guide"
echo "  • README.md - Complete deployment guide"

# Create a simple activation script
cat > activate.sh << 'EOF'
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
EOF

chmod +x activate.sh
print_success "Created activate.sh script to load environment variables"
