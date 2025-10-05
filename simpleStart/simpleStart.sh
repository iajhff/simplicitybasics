#!/bin/bash

# SimplicityHL Simple Installer - Docker Only
# Version: 2.0

set -euo pipefail

# Basic colors for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Global configuration
ELEMENTS_VERSION=""
RPC_USERNAME=""
RPC_PASSWORD=""
ELEMENTS_RPC_PORT="19000"
ELEMENTS_P2P_PORT="19001"
ELEMENTS_DATA_DIR="$HOME/.elements"
ELEMENTS_CONTAINER_NAME="elementsd"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo; echo -e "${BOLD}${CYAN}=== $1 ===${NC}"; echo; }
check_command() { command -v "$1" >/dev/null 2>&1; }

install_or_check_docker() {
    echo -e "${CYAN}Command used:${NC} ${YELLOW}docker --version${NC}"
    log_info "Checking Docker installation..."
    
    if check_command docker; then
        log_success "Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
        
        echo -e "${CYAN}Command used:${NC} ${YELLOW}docker info${NC}"
        if docker info >/dev/null 2>&1; then
            log_success "Docker daemon is accessible"
            return 0
        else
            log_warning "Docker installed but daemon not accessible"
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                log_info "Attempting to start Docker Desktop..."
                open -a Docker 2>/dev/null || true
                sleep 10
                
                if docker info >/dev/null 2>&1; then
                    log_success "Docker Desktop started successfully"
                    return 0
                fi
            fi
            
            log_warning "Trying with sudo..."
            if sudo docker info >/dev/null 2>&1; then
                log_success "Docker daemon accessible with sudo"
                return 0
            else
                log_error "Docker daemon not accessible"
            return 1
            fi
        fi
    else
        log_error "Docker not installed"
        log_info "Please install Docker from: https://docker.com"
        return 1
    fi
}

get_latest_elements_version() {
    log_info "Checking for latest Elements Core release..."
    if check_command curl; then
        local latest_tag
        latest_tag=$(curl -s https://api.github.com/repos/ElementsProject/elements/releases/latest | grep '"tag_name"' | cut -d'"' -f4 2>/dev/null || echo "")
        if [[ -n "$latest_tag" ]]; then
            ELEMENTS_VERSION="${latest_tag#elements-}"
        else
            ELEMENTS_VERSION="23.2.7"
        fi
    else
        ELEMENTS_VERSION="23.2.7"
    fi
    log_success "Elements version: $ELEMENTS_VERSION"
}

configure_elements() {
    print_header "Elements Configuration"
    
    echo -n "RPC Username [default: admin]: "
    read -r RPC_USERNAME
    if [[ -z "$RPC_USERNAME" || "$RPC_USERNAME" == "Y" || "$RPC_USERNAME" == "y" ]]; then
        RPC_USERNAME="admin"
    fi
    echo "[SELECTED] Using: $RPC_USERNAME"
    
    echo
    echo -n "RPC Password [default: changeme]: "
    read -s RPC_PASSWORD
    echo
    if [[ -z "$RPC_PASSWORD" ]]; then
        RPC_PASSWORD="changeme"
    fi
    echo "[SELECTED] Password set"
    
    echo
    echo -n "Elements RPC Port [default: $ELEMENTS_RPC_PORT]: "
    read -r port
    if [[ -n "$port" && "$port" != "Y" && "$port" != "y" ]]; then
        ELEMENTS_RPC_PORT="$port"
    fi
    echo "[SELECTED] Using: $ELEMENTS_RPC_PORT"
    
    echo -n "Elements P2P Port [default: $ELEMENTS_P2P_PORT]: "
    read -r port
    if [[ -n "$port" && "$port" != "Y" && "$port" != "y" ]]; then
        ELEMENTS_P2P_PORT="$port"
    fi
    echo "[SELECTED] Using: $ELEMENTS_P2P_PORT"
}

docker_setup_elements() {
    local repo_url="https://github.com/Blockstream/bitcoin-images.git"
    local repo_dir="bitcoin-images"
    local image_tag="elementsd:latest"
    local container_name="$ELEMENTS_CONTAINER_NAME"
    
    local docker_cmd="docker"
    if ! docker info >/dev/null 2>&1; then
        docker_cmd="sudo docker"
    fi
    
    # Check if Elements container is already running and working
    if $docker_cmd ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        log_info "Elements container '$container_name' is already running"
        if $docker_cmd exec "$container_name" elements-cli getblockchaininfo >/dev/null 2>&1; then
            log_success "Existing Elements daemon is up and working!"
            return 0
        else
            log_warning "Existing container found but not responding - will restart"
            $docker_cmd stop "$container_name" >/dev/null 2>&1 || true
            $docker_cmd rm "$container_name" >/dev/null 2>&1 || true
        fi
    fi
    
    # Check if image exists, build if not
    if ! $docker_cmd images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$image_tag$"; then
    log_info "Building Elements Docker image..."
    
        if [[ -d "$repo_dir" ]]; then
            rm -rf "$repo_dir"
        fi
        
        git clone "$repo_url" "$repo_dir"
        cd "$repo_dir/elementsd"
        $docker_cmd build -t "$image_tag" .
        cd - >/dev/null
        rm -rf "$repo_dir"
    
    log_success "Elements Docker image built successfully"
    else
        log_success "Elements Docker image already exists"
    fi
    
    # Ensure completely fresh Elements data directory
    log_info "Creating fresh Elements data directory..."
    rm -rf "$ELEMENTS_DATA_DIR"
    mkdir -p "$ELEMENTS_DATA_DIR"
    
    # Create Elements configuration with standalone parameters
    log_info "Creating Elements standalone configuration..."
    cat > "$ELEMENTS_DATA_DIR/elements.conf" << EOF
chain=elementsregtest

[regtest]
server=1
daemon=0
printtoconsole=1
rpcbind=0.0.0.0
rpcallowip=0.0.0.0/0
rpcuser=$RPC_USERNAME
rpcpassword=$RPC_PASSWORD
rpcport=$ELEMENTS_RPC_PORT
port=$ELEMENTS_P2P_PORT
bind=0.0.0.0
blocktime=1
validatepegin=0
defaultpeggedassetname=bitcoin
initialfreecoins=2100000000000000
initialreissuancetokens=200000000
txindex=1
debug=0
EOF
    
    log_info "Starting Elements container..."
    
    container_id=$($docker_cmd run -d --name "$ELEMENTS_CONTAINER_NAME" --restart unless-stopped \
      -p "$ELEMENTS_RPC_PORT:$ELEMENTS_RPC_PORT" \
      -p "$ELEMENTS_P2P_PORT:$ELEMENTS_P2P_PORT" \
      -v "$ELEMENTS_DATA_DIR:/root/.elements" \
      "$image_tag" \
      elementsd -validatepegin=0 -defaultpeggedassetname=bitcoin -initialfreecoins=2100000000000000 -initialreissuancetokens=200000000)
    
    if [[ -z "$container_id" ]]; then
        log_error "Failed to start Elements container"
        return 1
    fi
    
    log_success "Elements container started: $container_id"
    
    # Wait for Elements daemon to be ready
    log_info "Waiting for Elements daemon to start..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if $docker_cmd exec "$container_name" elements-cli getblockchaininfo >/dev/null 2>&1; then
            log_success "Elements daemon is ready!"
            break
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
        
        if [[ $attempt -gt $max_attempts ]]; then
            log_error "Elements daemon failed to start within timeout"
            return 1
        fi
    done
    
    echo
    log_success "Elements Core setup completed"
    return 0
}

install_rust_toolchain() {
    log_info "Installing Rust toolchain..."
    
    if check_command rustc; then
        log_success "Rust already installed: $(rustc --version)"
        return 0
    fi
    
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    
    log_success "Rust toolchain installed"
}

install_simplicityhl_compiler() {
    log_info "Installing SimplicityHL compiler..."
    
    if check_command simc; then
        log_success "SimplicityHL compiler already installed"
        return 0
    fi
    
    echo -e "${BOLD}Command:${NC} ${YELLOW}cargo install simplicityhl${NC}"
    cargo install simplicityhl
    
    if check_command simc; then
        log_success "SimplicityHL compiler installed successfully"
    else
        log_error "SimplicityHL compiler installation failed"
        return 1
    fi
}

install_helper_tools() {
    log_info "Installing helper tools..."
    
    if ! check_command hal-elements; then
        cargo install hal-elements
    fi
    
    if ! check_command hal-simplicity; then
        cargo install hal-simplicity
    fi
    
    if ! check_command simply; then
        cargo install --git https://github.com/starkware-bitcoin/simply simply
    fi
    
    log_success "Helper tools installed"
}

main() {
    # Declare variables at function level
    local wallet_name=""
    local address=""
    local balance="0"
    local project_dir=""
    
    print_header "SimplicityHL Development Environment Setup"
    
    echo "Sets up Elements regtest with funded wallet and basic Simplicity project structure."
    echo
    echo -n "Continue? (Y/n) [default: Y]: "
    read -r continue_install
    if [[ -n "$continue_install" && ! "$continue_install" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # Step 1: Elements Core
    print_header "Step 1/3: Installing Elements Core"
    echo -e "${BOLD}Command:${NC} ${YELLOW}docker run elementsd${NC}"
    echo "Installing Elements Core regtest with 21M L-BTC initial funding."
    echo
    if ! install_or_check_docker; then
        log_error "Docker installation failed"
        exit 1
    fi
    
    get_latest_elements_version
    configure_elements
    
    if ! docker_setup_elements; then
        log_error "Elements setup failed"
        exit 1
    fi
    
    # Step 2: SimplicityHL
    print_header "Step 2/3: Installing SimplicityHL Compiler"
    echo -e "${BOLD}Command:${NC} ${YELLOW}cargo install simc${NC}"
    echo "Installing Rust toolchain and SimplicityHL compiler placeholder."
    echo
    install_rust_toolchain
    install_simplicityhl_compiler
    
    # Step 3: Helper Tools
    print_header "Step 3/3: Installing Helper Tools"
    echo -e "${BOLD}Command:${NC} ${YELLOW}cargo install hal-elements hal-simplicity${NC}"
    echo -e "${BOLD}Command:${NC} ${YELLOW}cargo install --git https://github.com/starkware-bitcoin/simply simply${NC}"
    echo "Installing transaction and contract analysis tools."
    echo
    install_helper_tools
    
    log_success "Installation completed successfully!"
    
    # Regtest setup
    print_header "Regtest Development Setup"
    
    local docker_prefix=""
    if ! docker info >/dev/null 2>&1; then
        docker_prefix="sudo "
    fi
    
    # ALWAYS force complete reset for reliable operation
    log_info "Forcing complete reset to give fresh dev wallet..."
    
            ${docker_prefix}docker stop "$ELEMENTS_CONTAINER_NAME" >/dev/null 2>&1 || true
            ${docker_prefix}docker rm "$ELEMENTS_CONTAINER_NAME" >/dev/null 2>&1 || true
                rm -rf "$ELEMENTS_DATA_DIR"
            
            log_info "Starting fresh Elements daemon..."
            if ! docker_setup_elements; then
        log_error "Failed to start fresh Elements daemon"
        exit 1
            fi
            
    log_success "Fresh Elements setup complete"
    
    # Create wallet
    echo
    echo -n "Create wallet? (Y/n) [default: Y]: "
    read -r create_wallet
    if [[ -z "$create_wallet" || "$create_wallet" =~ ^[Yy]$ ]]; then
        echo
        echo -n "Wallet name [default: dev]: "
        read -r wallet_name
        if [[ -z "$wallet_name" ]]; then
            wallet_name="dev"
        fi
        
        # Use EXACT working sequence
        echo -e "${CYAN}Command used:${NC} ${YELLOW}docker exec elementsd elements-cli createwallet $wallet_name${NC}"
        ${docker_prefix}docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli createwallet "$wallet_name" >/dev/null 2>&1 || true
        
        echo -e "${CYAN}Command used:${NC} ${YELLOW}docker exec elementsd elements-cli -rpcwallet=$wallet_name rescanblockchain${NC}"
                ${docker_prefix}docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli -rpcwallet="$wallet_name" rescanblockchain >/dev/null 2>&1
                
        echo -e "${CYAN}Command used:${NC} ${YELLOW}docker exec elementsd elements-cli -rpcwallet=$wallet_name getbalance${NC}"
        local balance_json
        balance_json=$(${docker_prefix}docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli -rpcwallet="$wallet_name" getbalance 2>/dev/null)
        balance=$(echo "$balance_json" | grep '"bitcoin"' | sed 's/.*"bitcoin": *\([0-9.]*\).*/\1/' || echo "0")
        
        log_success "Wallet '$wallet_name' created with balance: $balance L-BTC"
    fi
    
    # Generate address
    echo
    echo -n "Generate address? (Y/n) [default: Y]: "
    read -r generate_addr
    if [[ -z "$generate_addr" || "$generate_addr" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Command used:${NC} ${YELLOW}docker exec elementsd elements-cli -rpcwallet=$wallet_name getnewaddress${NC}"
        address=$(${docker_prefix}docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli -rpcwallet="$wallet_name" getnewaddress 2>/dev/null)
            
            echo
            echo "=== Generated Address ==="
        echo "Address: $address"
        echo
        
        # Fund the address with 50 L-BTC for testing
        echo -n "Fund address with 50 L-BTC for testing? (Y/n) [default: Y]: "
        read -r fund_address
        if [[ -z "$fund_address" || "$fund_address" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Command used:${NC} ${YELLOW}docker exec elementsd elements-cli -rpcwallet=$wallet_name sendtoaddress $address 50${NC}"
            local fund_txid
            fund_txid=$(${docker_prefix}docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli -rpcwallet="$wallet_name" sendtoaddress "$address" 50 2>/dev/null)
            
            if [[ -n "$fund_txid" ]]; then
                log_success "Sent 50 L-BTC to address - Transaction: $fund_txid"
                
                # Mine a block to confirm the transaction
                echo -e "${CYAN}Command used:${NC} ${YELLOW}docker exec elementsd elements-cli generatetoaddress 1 $address${NC}"
                ${docker_prefix}docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli generatetoaddress 1 "$address" >/dev/null 2>&1
                log_success "Transaction confirmed in new block"
                
                # Update balance after funding
                local updated_balance_json
                updated_balance_json=$(${docker_prefix}docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli -rpcwallet="$wallet_name" getbalance 2>/dev/null)
                balance=$(echo "$updated_balance_json" | grep '"bitcoin"' | sed 's/.*"bitcoin": *\([0-9.]*\).*/\1/' || echo "0")
            else
                log_warning "Failed to fund address"
            fi
        fi
    fi
    
    # Create project structure
    echo
    echo -n "Create Simplicity project structure? (Y/n) [default: Y]: "
    read -r create_contract
    if [[ -z "$create_contract" || "$create_contract" =~ ^[Yy]$ ]]; then
        project_dir="./my-simplicity-contract"
        
        echo -e "${CYAN}Command used:${NC} ${YELLOW}mkdir -p $project_dir/{src,target,tests,witness}${NC}"
        mkdir -p "$project_dir"/{src,target,tests,witness}
        
        echo -e "${CYAN}Command used:${NC} ${YELLOW}cat > $project_dir/src/main.simf${NC}"
        cat > "$project_dir/src/main.simf" << 'EOF'
fn main() -> () { () }
EOF
        
        echo -e "${CYAN}Command used:${NC} ${YELLOW}simc $project_dir/src/main.simf > $project_dir/target/main.base64${NC}"
        if check_command simc; then
            simc "$project_dir/src/main.simf" > "$project_dir/target/main.base64"
        else
            echo -e "${CYAN}Command used:${NC} ${YELLOW}echo '01' | xxd -r -p | base64 > $project_dir/target/main.base64${NC}"
            echo -n "01" | xxd -r -p | base64 > "$project_dir/target/main.base64"
        fi
        
        log_success "Project structure created at $project_dir"
    fi
    
    # Create deployment info
    cat > "./simplicity-deployment-info.txt" << EOF
# Simplicity Development Environment
WALLET_NAME=$wallet_name
ADDRESS=$address
BALANCE=$balance
PROJECT_DIR=$project_dir
FUNDED_ADDRESS=$address
FUNDED_AMOUNT=50
FUNDING_TXID=${fund_txid:-"not_funded"}

# Docker Elements commands:
docker exec elementsd elements-cli -rpcwallet=$wallet_name getbalance
docker exec elementsd elements-cli -rpcwallet=$wallet_name getnewaddress
docker exec elementsd elements-cli generatetoaddress 1 $address

# Check funded address balance:
docker exec elementsd elements-cli -rpcwallet=$wallet_name listunspent 0 9999999 '["$address"]'
docker exec elementsd elements-cli -rpcwallet=$wallet_name getaddressinfo $address
EOF
    
    # Get final balance for display
    if [[ -n "$wallet_name" ]]; then
        local final_balance_json
        final_balance_json=$(${docker_prefix}docker exec "$ELEMENTS_CONTAINER_NAME" elements-cli -rpcwallet="$wallet_name" getbalance 2>/dev/null)
        balance=$(echo "$final_balance_json" | grep '"bitcoin"' | sed 's/.*"bitcoin": *\([0-9.]*\).*/\1/' || echo "0")
    fi
    
    echo
    echo "=== Environment Ready ==="
    echo "Wallet: $wallet_name ($balance L-BTC)"
    echo "Project: $project_dir"
    echo "Container: $ELEMENTS_CONTAINER_NAME"
    echo "Info: ./simplicity-deployment-info.txt"
}

# Run main function
main "$@"