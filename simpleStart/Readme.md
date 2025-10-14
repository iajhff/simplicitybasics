# SimplicityHL Sample Install Scripts



## Quick Install

### Regtest Development Environment
```bash
./simpleStart.sh
```

### Liquid Testnet Environment
```bash
./simpleTestnet.sh
```

## What It Does

### Step 1: Elements Core Setup
- **Command:** `docker run elementsd`
- **Why:** Provides Elements regtest blockchain for testing Simplicity contracts
- **Result:** Docker container with Elements daemon and 21M L-BTC initial funding

### Step 2: Rust Toolchain
- **Command:** `curl https://sh.rustup.rs | sh`
- **Why:** Required to build Simplicity development tools
- **Result:** Rust compiler and Cargo package manager installed

### Step 3: Development Tools
- **Commands:** 
  - `cargo install hal-elements hal-simplicity`
  - `cargo install --git https://github.com/starkware-bitcoin/simply simply`
- **Why:** Essential tools for contract analysis and deployment
- **Result:** Complete Simplicity toolchain installed

### Step 4: Wallet Setup
- **Commands:** 
  - `docker exec elementsd elements-cli createwallet dev`
  - `docker exec elementsd elements-cli -rpcwallet=dev rescanblockchain`
  - `docker exec elementsd elements-cli -rpcwallet=dev sendtoaddress <addr> 21000000`
- **Why:** Need funded wallet to test contract deployments
- **Result:** Wallet 'dev' with 21 million L-BTC available

### Step 5: Project Structure
- **Commands:**
  - `mkdir -p my-simplicity-contract/{src,target,tests,witness}`
  - `cat > my-simplicity-contract/src/main.simf`
  - `echo '01' | xxd -r -p | base64 > my-simplicity-contract/target/main.base64`
- **Why:** Follows Simplicity best practices for project organization
- **Result:** Ready-to-use project with example contract

## Testnet Script (simpleTestnet.sh)

### What simpleTestnet.sh Does

#### Step 1: Environment Check
- **Commands:** `docker ps`, `docker exec elementsd elements-cli getblockchaininfo`
- **Why:** Detects existing regtest setup and backs it up
- **Result:** Preserves regtest environment while switching to testnet

#### Step 2: Liquid Testnet Setup
- **Commands:**
  - `docker stop elementsd && docker rename elementsd elementsd-regtest-backup`
  - `docker run elementsd -chain=liquidtestnet`
- **Why:** Connects to real Liquid testnet network (no local bitcoind needed)
- **Result:** Elements daemon connected to Liquid testnet

#### Step 3: Testnet Wallet
- **Commands:**
  - `docker exec elementsd elements-cli createwallet testnet`
  - `docker exec elementsd elements-cli -rpcwallet=testnet getnewaddress`
- **Why:** Creates wallet for receiving faucet L-BTC
- **Result:** Testnet wallet with address for faucet funding

#### Step 4: Project Structure
- **Commands:** `mkdir -p my-simplicity-testnet/{src,target,tests,witness}`
- **Why:** Separate project for testnet development
- **Result:** Testnet-specific project structure

## What You Get

### Regtest Environment (simpleStart.sh)
- Elements regtest blockchain (Docker container: `elementsd`)
- Funded wallet: `dev` with 21,000,000 L-BTC
- Funded address with 50 L-BTC for immediate testing
- Development tools installed:
  - **hal-elements**: Elements transaction decoder and analyzer
  - **hal-simplicity**: Simplicity contract analyzer and CMR calculator  
  - **simply**: Complete Simplicity workflow tool (build/test/deploy)
- Shell aliases for easy access

### Testnet Environment (simpleTestnet.sh)
- Elements Liquid testnet connection (real network)
- Testnet wallet: `testnet` ready for faucet L-BTC
- Testnet address for receiving funds from faucet
- Same development tools available
- Real network timing (1 minute blocks)
- Backup of regtest environment preserved

### Project Structure

**Regtest project:**
```
my-simplicity-contract/
├── src/
│   └── main.simf           # Contract: fn main() { () }
├── target/
│   └── main.base64         # Compiled witness: AQ==
├── tests/                  # Test directory
└── witness/                # Witness data directory
```

**Testnet project:**
```
my-simplicity-testnet/
├── src/
│   └── main.simf           # Contract: fn main() { () }
├── target/
│   └── main.base64         # Same compiled witness
├── tests/                  # Testnet-specific tests
└── witness/                # Testnet witness data
```

### Installed Development Tools

#### hal-elements
Elements transaction decoder and analyzer
```bash
# Transaction operations
hal-elements elements tx decode <txhex>            # Decode raw transaction
hal-elements elements tx create <json>             # Create transaction from JSON

# Address operations  
hal-elements elements address inspect <addr>       # Inspect Elements address
hal-elements elements address create <script>      # Create address from script
```

#### hal-simplicity
Simplicity contract analyzer and CMR calculator
```bash
# Program analysis
hal-simplicity simplicity simplicity info <base64>    # Get contract info including CMR
```

#### simply
Complete Simplicity workflow tool from [starkware-bitcoin/simply](https://github.com/starkware-bitcoin/simply)
```bash
# Build operations
# Simply uses a different internal key to web-ide or hal simplicity 
simply build --entrypoint src/main.simf               # Basic build
simply build --entrypoint src/main.simf --target-dir target  # Build to specific directory
simply build --witness witness.json --prune           # Build with witness and pruning
simply build --mcpp-inc-path /path/to/includes        # Build with C preprocessing

# Testing operations
simply test                                           # Run all tests
simply test --logging debug                           # Run tests with debug output
simply test --logging trace                           # Run tests with trace output

# Execution operations
simply run --entrypoint src/main.simf                 # Run contract locally
simply run --param args.json --logging info           # Run with arguments and logging
simply run --witness witness.json                     # Run with specific witness

# Deployment operations
simply deposit --entrypoint src/main.simf             # Generate P2TR deposit address
simply withdraw --entrypoint src/main.simf --txid <txid> --destination <address>  # Spend UTXO
simply withdraw --dry-run --txid <txid> --destination <address>  # Generate tx without broadcast

# Advanced options
simply build --prune                                  # Prune program (may limit reusability)
simply run --logging trace                            # Maximum debug output
```

### Quick Elements Commands

**Regtest commands:**
```bash
# Wallet operations
docker exec elementsd elements-cli -rpcwallet=dev getbalance
docker exec elementsd elements-cli -rpcwallet=dev getnewaddress
docker exec elementsd elements-cli -rpcwallet=dev listunspent

# Send funds
docker exec elementsd elements-cli -rpcwallet=dev sendtoaddress <address> <amount>

# Mine blocks (regtest only)
docker exec elementsd elements-cli generatetoaddress 1 <address>

# Get private key
docker exec elementsd elements-cli -rpcwallet=dev dumpprivkey <address>
```

**Testnet commands:**
```bash
# Wallet operations
docker exec elementsd elements-cli -rpcwallet=testnet getbalance
docker exec elementsd elements-cli -rpcwallet=testnet getnewaddress
docker exec elementsd elements-cli -rpcwallet=testnet listunspent

# Send funds (once you have L-BTC from faucet)
docker exec elementsd elements-cli -rpcwallet=testnet sendtoaddress <address> <amount>

# Get L-BTC from faucet
# Visit: https://liquidtestnet.com/faucet
# Use address from: docker exec elementsd elements-cli -rpcwallet=testnet getnewaddress

# Check sync status
docker logs elementsd
```

## Platform Support
- **macOS:** Docker Desktop + rustup
- **Linux:** Docker Engine + rustup  
- **Windows/WSL:** Docker Desktop + rustup

All commands work the same across platforms.

## Next Steps

### For Regtest Development
1. Follow the main README.md for contract development workflow
2. Use the project structure in `my-simplicity-contract/`
3. Deploy contracts using instant regtest blocks
4. Test with unlimited L-BTC funding

### For Testnet Development
1. Run `./simpleTestnet.sh` to migrate to testnet
2. Get L-BTC from https://liquidtestnet.com/faucet
3. Use the project structure in `my-simplicity-testnet/`
4. Test on real Liquid testnet network

### Development Workflow
1. Write contracts in `src/main.simf`
2. Analyze with hal-simplicity tools
3. Deploy with simply commands
4. Monitor with hal-elements tools

## Files Created

### Regtest Files
- `my-simplicity-contract/` - Regtest project directory
- `simplicity-deployment-info.txt` - Regtest environment info
- `~/.elements/elements.conf` - Regtest configuration

### Testnet Files (after running simpleTestnet.sh)
- `my-simplicity-testnet/` - Testnet project directory
- `simplicity-testnet-info.txt` - Testnet environment info
- `~/.elements-testnet/elements.conf` - Testnet configuration
- `elementsd-regtest-backup` - Backed up regtest container
