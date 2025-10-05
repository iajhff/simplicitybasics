# SIMPLICITY FIRST CONTRACT

## Install Tools

```bash
# Install Rust if you don't have it
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# Install simply - bundles SimplicityHL compiler, Bitcoin P2TR support, 
# transaction builder, witness generator, test framework, and Liquid integration with esplora testnet api support
cargo install --git https://github.com/starkware-bitcoin/simply simply

# Install Elements Core (for generating destination addresses)
https://github.com/ElementsProject/elements/releases

# Verify installation
simply --help
elements-cli --help
```

## Setup Elements Core

Start Elements Core in Liquid testnet mode to generate addresses:

```bash
elementsd -chain=liquidtestnet -validatepegin=0 -daemon
```

Wait a moment for it to initialize (about 30 seconds), then create a wallet:
```bash
elements-cli -chain=liquidtestnet createwallet "test"
```

**Note:** This will start syncing the blockchain in the background, but you don't need to wait for it! You can generate addresses immediately after creating the wallet. Stop it later with: `elements-cli -chain=liquidtestnet stop`

## Complete Workflow

### Step 1: Create Your Contract

```bash
# Create your Simplicity contract
cat > contract.simf << 'EOF'
fn main() {
    ()
}
EOF
```

### Step 2: Generate Your Contract Address

# For simple contracts like this one, simply deposit automatically compiles 
# the source file internally. No separate build step is needed - the tool 
# handles compilation on-demand. For complex contracts with witness data, you 
# may want to pre-build with 'simply build' for debugging.

```bash
simply deposit --entrypoint contract.simf
```

This outputs something like: `P2TR address: tex1p9jcvyzkdwdqtf49kta4xpc5g35xkfcexwfsl8v70w2gwttelncyshxjk56`
Copy this address - this is where you'll send funds!

### Step 3: Generate Destination Address

```bash
# By default this gives you confidential address but we're going to use unconfidential for demo purposes
elements-cli -chain=liquidtestnet getnewaddress

# Get address info and copy unconfidential
elements-cli -chain=liquidtestnet getaddressinfo <address> 
```

This outputs a Liquid testnet address like: `tex1q8nfm4a0z90xnkgkhvp9jrhfaustt4zwr5a8k8r`
Copy this address - this is where funds will be sent to!

### Step 4: Fund Your Contract

1. Go to: https://liquidtestnet.com/faucet
2. Paste your contract address from step 2
3. Click "Send assets"
4. Wait for the transaction to confirm
5. Copy the transaction ID from the faucet

### Step 5: Spend from Your Contract

```bash
# simply connects to the esplora api for you and creates your transaction via https://blockstream.info/liquidtestnet/tx/push. This avoids lengthy testnet daemon sync. Creating transactions is complex and will covered in future guides. 
simply withdraw --entrypoint contract.simf --txid YOUR_FUNDING_TXID --destination YOUR_DESTINATION_ADDRESS
```

Replace:
- `YOUR_FUNDING_TXID` with the transaction ID from step 4
- `YOUR_DESTINATION_ADDRESS` with the address from step 3

This will create and broadcast the transaction automatically!

## Verify Your Deployment

```bash
# Check your transaction
# Replace `YOUR_TXID` with the transaction ID from the withdraw command
curl "https://blockstream.info/liquidtestnet/api/tx/YOUR_TXID"

# Check your contract address balance
# `YOUR_CONTRACT_ADDRESS` with the address from Step 2
curl "https://blockstream.info/liquidtestnet/api/address/YOUR_CONTRACT_ADDRESS"
```

#### simply command reference
Complete Simplicity workflow tool from [starkware-bitcoin/simply](https://github.com/starkware-bitcoin/simply)
```bash
# Build operations (optional - deposit/withdraw can compile automatically)
simply build --entrypoint src/main.simf               # Manual build (useful for debugging)
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
