#!/bin/bash

# SimplicityHL Liquid Testnet Setup Script
# Connects to existing Liquid testnet network (no bitcoind needed)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
ELEMENTS_CONTAINER_NAME="elementsd"
LIQUID_TESTNET_PORT="7041"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo; echo -e "${BOLD}${CYAN}=== $1 ===${NC}"; echo; }
check_command() { command -v "$1" >/dev/null 2>&1; }

check_existing_setup() {
    print_header "Checking Existing Setup"
    
    local docker_prefix=""
    if ! docker info >/dev/null 2>&1; then
        docker_prefix="sudo "
    fi
    
    # Check if elementsd container exists
    if $docker_prefix docker ps -a --format '{{.Names}}' | grep -q "^elementsd$"; then
        log_success "Found existing elementsd container"
        
        # Properly shutdown regtest and backup
        log_info "Shutting down regtest container..."
        $docker_prefix docker stop elementsd >/dev/null 2>&1 || true
        
        # Remove any existing backup
        $docker_prefix docker rm elementsd-regtest-backup >/dev/null 2>&1 || true
        
        # Backup regtest container
        if $docker_prefix docker rename elementsd elementsd-regtest-backup >/dev/null 2>&1; then
            log_success "Regtest container backed up as elementsd-regtest-backup"
        else
            log_warning "Failed to backup - removing regtest container"
            $docker_prefix docker rm elementsd >/dev/null 2>&1 || true
        fi
    else
        log_info "No existing elementsd found - will create fresh testnet setup"
    fi
    
    # Check development tools
    local missing_tools=()
    if ! check_command hal-elements; then missing_tools+=("hal-elements"); fi
    if ! check_command hal-simplicity; then missing_tools+=("hal-simplicity"); fi
    if ! check_command simply; then missing_tools+=("simply"); fi
    if ! check_command simc; then missing_tools+=("simc"); fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_info "Installing missing tools: ${missing_tools[*]}"
        install_development_tools
    else
        log_success "Development tools already installed"
    fi
}

install_development_tools() {
    # Install Rust if needed
    if ! check_command rustc; then
        log_info "Installing Rust toolchain..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    # Install tools
    if ! check_command hal-elements; then
        cargo install hal-elements
    fi
    if ! check_command hal-simplicity; then
        cargo install hal-simplicity
    fi
    if ! check_command simply; then
        cargo install --git https://github.com/starkware-bitcoin/simply simply
    fi
    if ! check_command simc; then
        cargo install simplicityhl
    fi
    
    log_success "Development tools installed"
}

setup_liquid_testnet() {
    print_header "Setting Up Liquid Testnet"
    
    echo "LEARNING: Liquid testnet connects to the existing Liquid testnet network."
    echo "No local bitcoind needed - the network handles peg-in validation."
    echo "You get L-BTC from the faucet: https://liquidtestnet.com/faucet"
    echo
    
    local docker_prefix=""
    if ! docker info >/dev/null 2>&1; then
        docker_prefix="sudo "
    fi
    
    # Create Liquid testnet configuration
    log_info "Creating Liquid testnet configuration..."
    mkdir -p ~/.elements-testnet
    cat > ~/.elements-testnet/elements.conf << 'EOF'
chain=liquidtestnet

[liquidtestnet]
server=1
daemon=0
printtoconsole=1
rpcbind=0.0.0.0
rpcallowip=0.0.0.0/0
rpcuser=admin
rpcpassword=changeme
rpcport=7041
port=7042
bind=0.0.0.0
txindex=1
debug=0
EOF
    
    # Start Elements Liquid testnet container
    echo -e "${CYAN}Command used:${NC} ${YELLOW}docker run elementsd liquidtestnet${NC}"
    log_info "Starting Elements Liquid testnet container..."
    
    local container_id
    container_id=$($docker_prefix docker run -d --name "$ELEMENTS_CONTAINER_NAME" --restart unless-stopped \
      -p "$LIQUID_TESTNET_PORT:$LIQUID_TESTNET_PORT" \
      -p "7042:7042" \
      -v ~/.elements-testnet:/root/.elements \
      elementsd:latest \
      elementsd -chain=liquidtestnet)
    
    if [[ -z "$container_id" ]]; then
        log_error "Failed to start Elements Liquid testnet container"
        return 1
    fi
    
    log_success "Elements Liquid testnet container started"
    
    # Wait for Elements daemon to fully sync
    log_info "Waiting for Elements daemon to connect and sync with Liquid testnet..."
    log_warning "Liquid testnet sync may take 10-30 minutes (downloading blocks)"
    
    local max_attempts=180  # 6 minutes for initial connection
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        # Check if daemon is responding
        if $docker_prefix docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli getblockchaininfo >/dev/null 2>&1; then
            # Check if it's still verifying blocks
            local verification_progress
            verification_progress=$($docker_prefix docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli getblockchaininfo 2>/dev/null | grep '"verificationprogress"' || echo "")
            
            if [[ -n "$verification_progress" ]]; then
                local progress
                progress=$(echo "$verification_progress" | sed 's/.*"verificationprogress": *\([0-9.]*\).*/\1/')
                echo -n " (sync: ${progress}%)"
            fi
            
            # Try a wallet operation to see if it's ready
            if $docker_prefix docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli listwallets >/dev/null 2>&1; then
                log_success "Elements Liquid testnet daemon is ready!"
                break
            fi
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
        
        if [[ $attempt -gt $max_attempts ]]; then
            log_warning "Elements daemon still syncing - continuing anyway"
            log_info "Sync will continue in background. Check progress: docker logs elementsd"
            break
        fi
    done
    
    echo
}

setup_testnet_wallet() {
    print_header "Creating Testnet Wallet"
    
    local docker_prefix=""
    if ! docker info >/dev/null 2>&1; then
        docker_prefix="sudo "
    fi
    
    wallet_name="testnet"
    
    # Try to load existing wallet first, then create if needed
    echo -e "${CYAN}Command used:${NC} ${YELLOW}docker exec elementsd elements-cli loadwallet $wallet_name${NC}"
    if $docker_prefix docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli loadwallet "$wallet_name" >/dev/null 2>&1; then
        log_success "Loaded existing wallet '$wallet_name'"
    else
        echo -e "${CYAN}Command used:${NC} ${YELLOW}docker exec elementsd elements-cli createwallet $wallet_name${NC}"
        if $docker_prefix docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli createwallet "$wallet_name" >/dev/null 2>&1; then
            log_success "Created new wallet '$wallet_name'"
        else
            log_warning "Wallet creation failed - trying to load existing wallet"
            $docker_prefix docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli loadwallet "$wallet_name" >/dev/null 2>&1 || true
        fi
    fi
    
    echo -e "${CYAN}Command used:${NC} ${YELLOW}docker exec elementsd elements-cli -rpcwallet=$wallet_name getnewaddress${NC}"
    testnet_address=$($docker_prefix docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli -rpcwallet="$wallet_name" getnewaddress 2>/dev/null)
    
    log_success "Testnet wallet created"
    
    # Create project structure for testnet
    project_dir="./my-simplicity-testnet"
    mkdir -p "$project_dir"/{src,target,tests,witness}
    
    cat > "$project_dir/src/main.simf" << 'EOF'
fn main() -> () { () }
EOF
    
    # Compile with simc if available, otherwise use fallback
    if command -v simc >/dev/null 2>&1; then
        simc "$project_dir/src/main.simf" > "$project_dir/target/main.base64"
    else
        echo -n "01" | xxd -r -p | base64 > "$project_dir/target/main.base64"
    fi
    
    # Create testnet deployment info
    cat > "./simplicity-testnet-info.txt" << EOF
# Simplicity Liquid Testnet Environment
WALLET_NAME=$wallet_name
ADDRESS=$testnet_address
NETWORK=liquidtestnet
PROJECT_DIR=$project_dir
ELEMENTS_PORT=$LIQUID_TESTNET_PORT

# Testnet commands:
docker exec elementsd elements-cli -rpcwallet=$wallet_name getbalance
docker exec elementsd elements-cli -rpcwallet=$wallet_name getnewaddress
docker exec elementsd elements-cli -rpcwallet=$wallet_name listunspent

# STEP 1: Get L-BTC from faucet (REQUIRED):
# Visit: https://liquidtestnet.com/faucet
# Enter address: $testnet_address
# Click 'Send assets'
# Wait for confirmation (~1-2 minutes)

# STEP 2: Check if L-BTC arrived:
docker exec elementsd elements-cli -rpcwallet=$wallet_name getbalance
docker exec elementsd elements-cli -rpcwallet=$wallet_name listunspent

# STEP 3: Send funds (once you have L-BTC):
docker exec elementsd elements-cli -rpcwallet=$wallet_name sendtoaddress <address> <amount>

# Development tools:
hal-elements tx decode <txhex>
hal-simplicity simplicity info <witness>
simply build --entrypoint src/main.simf
EOF
}

main() {
    # Declare variables at main function level
    local wallet_name=""
    local testnet_address=""
    local project_dir=""
    
    print_header "SimplicityHL Liquid Testnet Setup"
    
    echo "Sets up Elements Liquid testnet for real L-BTC testing (no bitcoind needed)."
    echo
    echo "This script will:"
    echo "  1. Check for existing elementsd setup"
    echo "  2. Install development tools if needed"
    echo "  3. Connect to Liquid testnet network"
    echo "  4. Create testnet wallet for faucet L-BTC"
    echo "  5. Backup regtest setup if it exists"
    echo
    echo "Get L-BTC from: https://liquidtestnet.com/faucet"
    echo
    echo -n "Force clean restart (removes all containers/data)? (y/N) [default: N]: "
    read -r force_clean
    if [[ "$force_clean" =~ ^[Yy]$ ]]; then
        log_info "Forcing complete clean restart..."
        docker stop elementsd bitcoind 2>/dev/null || true
        docker rm elementsd bitcoind elementsd-regtest-backup 2>/dev/null || true
        rm -rf ~/.elements ~/.elements-testnet ~/.bitcoin
        log_success "Complete clean restart"
    fi
    
    echo -n "Continue with Liquid testnet setup? (Y/n) [default: Y]: "
    read -r continue_setup
    if [[ -n "$continue_setup" && ! "$continue_setup" =~ ^[Yy]$ ]]; then
        echo "Testnet setup cancelled."
        exit 0
    fi
    
    # Step 1: Check existing setup
    check_existing_setup
    
    # Step 2: Setup Liquid testnet
    setup_liquid_testnet
    
    # Step 3: Setup testnet wallet
    setup_testnet_wallet
    
    echo
    echo "=== Liquid Testnet Setup Complete ==="
    echo
    echo "Liquid testnet environment ready"
    echo
    echo "WALLET DETAILS:"
    echo "   Wallet name: testnet"
    echo "   Address: $testnet_address"
    echo
    echo "GET L-BTC FROM FAUCET:"
    echo "   1. Visit: https://liquidtestnet.com/faucet"
    echo "   2. Copy your address: $testnet_address"
    echo "   3. Paste in faucet form and click 'Send assets'"
    echo "   4. Wait for confirmation (~1-2 minutes)"
    echo
    echo "READY TO USE:"
    echo "   Check balance: docker exec elementsd elements-cli -rpcwallet=testnet getbalance"
    echo "   Generate address: docker exec elementsd elements-cli -rpcwallet=testnet getnewaddress"
    echo "   Deploy contract: simply deposit --entrypoint src/main.simf"
    echo
    echo "IMPORTANT NOTES:"
    echo "   - Liquid testnet sync may take 10-30 minutes"
    echo "   - Check sync: docker logs elementsd"
    echo "   - Real network timing (~1 minute per block)"
    echo "   - Use faucet L-BTC, no mining available"
    echo
    echo "FAUCET LINK: https://liquidtestnet.com/faucet"
    echo "YOUR ADDRESS: $testnet_address"
    echo
    echo "Files created:"
    echo "  - ./simplicity-testnet-info.txt (detailed commands)"
    echo "  - ./my-simplicity-testnet/ (project structure)"
    echo
    if docker ps -a --format '{{.Names}}' | grep -q "elementsd-regtest-backup"; then
        echo "Regtest backup available:"
        echo "   To restore: docker stop elementsd && docker start elementsd-regtest-backup"
    fi
}

# Run main function
main "$@"