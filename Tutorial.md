# Simplicity on Liquid: Complete Guide

A guide to deploying Simplicity smart contracts on Liquid testnet using SimplicityHL, hal-simplicity, and Elements Core.


## TODO
1. Replace simple_tx_tool with official way to build transaction with correct control block (can not mix control blocks)
2. bug test simple_tx_tool and consider adding working functionality to hal simplicity as need [Simple_TX_Tool_Sample_Code](https://github.com/iajhff/simplicitytxtool)

---


## Table of Contents

1. [Simplicity Introduction](#simplicity-introduction)
2. [Installing the Toolchain](#1-installing-the-necessary-toolchain)
3. [Deploying a Simple Contract](#2-deploying-simple-contract)
4. [Deploying a Contract with Witness](#3-deploying-contract-with-witness)
5. [Using the Simplicity Web IDE](#4-using-the-simplicity-web-ide)
6. [Next Steps](#next-steps)
7. [Useful Command List](#useful-command-list)

---

## Simplicity Introduction

### What is Simplicity?

Simplicity is a low-level, formally verifiable programming language designed specifically for blockchain smart contracts. Unlike traditional smart contract languages, Simplicity prioritizes:

- **Formal Verification**: Programs can be mathematically proven to be correct
- **Static Analysis**: Resource usage (CPU, memory) is known before execution
- **Security**: Minimal attack surface with clear, auditable semantics
- **Efficiency**: Optimized for blockchain validation

### How Simplicity Fits into Liquid and Bitcoin

**Current Status:**
- **Liquid Network**: Simplicity is currently active on Liquid testnet and will soon be available on Liquid mainnet
- **Bitcoin**: Simplicity is designed for Bitcoin but requires a soft fork activation (future)

**Architecture:**
- Simplicity programs are deployed as **Taproot script paths** (P2TR)
- Programs execute in a **bit machine** (not stack-based)
- Uses **jets** (optimized opcodes) for common operations like signature verification
- Compatible with **BIP-340 Schnorr signatures** and **BIP-341 Taproot**

**SimplicityHL** is the high-level language that compiles to Simplicity, similar to how Rust compiles to assembly language.

### How Simplicity Works

1. **Write**: Developer writes a contract in SimplicityHL (`.simf` file)
2. **Compile**: SimplicityHL compiler (`simc`) converts it to Simplicity bytecode
   - *Implementation*: [`SimplicityHL/src/compile.rs`](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/src/compile.rs) - translates SimplicityHL AST to Simplicity combinators
3. **Commit**: The program's CMR (Commitment Merkle Root) is computed
   - *Implementation*: [`rust-simplicity/src/merkle/cmr.rs`](https://github.com/BlockstreamResearch/rust-simplicity/blob/master/src/merkle/cmr.rs) - Merkle root that commits to program structure
4. **Address**: A P2TR address is derived from the CMR
5. **Fund**: Bitcoin/Liquid is sent to the address
6. **Spend**: To spend, you provide:
   - The Simplicity program
   - Witness data (signatures, hash preimages, etc.)
   - The transaction spends the UTXO if the program evaluates to `true`

**Execution Model:**
```
Transaction → Simplicity VM → Program + Witness → Evaluate → Accept/Reject
```

The program has access to transaction data (sighash) through **jets** like `jet::sig_all_hash()`.

**Technical Details:**
- **Jets**: Optimized native implementations of common operations. For example, `jet::bip_0340_verify` is implemented in [`rust-simplicity/simplicity-sys/depend/simplicity/jets-secp256k1.c`](https://github.com/BlockstreamResearch/rust-simplicity/blob/master/simplicity-sys/depend/simplicity/jets-secp256k1.c#L649-L665) (C) with Rust bindings
- **Sighash**: Computed in [`rust-simplicity/src/policy/sighash.rs`](https://github.com/BlockstreamResearch/rust-simplicity/blob/master/src/policy/sighash.rs#L83-L94) using `ElementsEnv::c_tx_env().sighash_all()`
- **Transaction Environment**: Elements-specific environment built in [`rust-simplicity/simplicity-sys/depend/simplicity/elements/txEnv.c`](https://github.com/BlockstreamResearch/rust-simplicity/blob/master/simplicity-sys/depend/simplicity/elements/txEnv.c)

### The Benefits of Simplicity

#### 1. **Formal Verification**
- Programs can be mathematically proven correct
- No runtime errors or undefined behavior
- Security properties verified before deployment

#### 2. **Predictable Resource Usage**
- CPU cost known at parse time
- No gas estimation needed
- No out-of-gas failures

#### 3. **Static Analysis**
- All execution paths analyzable before running
- Can prove programs always terminate
- Can verify security properties (e.g., "funds never locked")

#### 4. **Covenants**
- Full access to transaction structure
- Can enforce spending conditions (amount, destination, etc.)
- Enables advanced use cases (vaults, atomic swaps, inheritance, etc.)

#### 5. **Compatibility**
- Uses Bitcoin's Taproot (P2TR)
- Works with existing wallet infrastructure
- Schnorr signatures (BIP-340)

#### 6. **Efficiency**
- Jets provide native-speed operations
- Optimized for common operations (signature verification, hashing)
- Smaller on-chain footprint than alternatives

#### 7. **Developer Experience**
- SimplicityHL looks like Rust
- Type safety and type inference
- Clear error messages
- VSCode extension available

---

## 1. Installing the Necessary Toolchain

### Prerequisites

- **Operating System**: Linux, macOS, or WSL2 on Windows
- **Rust**: Version 1.78.0 or higher
- **Git**: For cloning repositories
- **curl**: For API interactions

### a) Install SimplicityHL (simc compiler)

SimplicityHL is the high-level language compiler that generates Simplicity bytecode.

```bash
# Install Rust if you don't have it
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# Install SimplicityHL compiler (simc)
cargo install --git https://github.com/BlockstreamResearch/SimplicityHL simc

# Verify installation
simc --help
```

**What simc does:**
- Compiles `.simf` files (SimplicityHL) to Simplicity bytecode
- Outputs base64-encoded programs
- Validates program structure and types

**Code Reference:**
- Compiler implementation: [`SimplicityHL/src/compile.rs`](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/src/compile.rs)
- Entry point: `Program::compile()` method that transforms AST to Simplicity nodes
- Translation semantics: [`SimplicityHL/doc/translation.md`](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/doc/translation.md)

### b) Install Elements Core

Elements Core is required for:
- Generating destination addresses
- Getting private keys for signing
- (Optional) Running a local testnet node

**Download and install:**

```bash
# Download from GitHub releases
# https://github.com/ElementsProject/elements/releases
# Get the latest version for your OS

# For Ubuntu/Debian:
wget https://github.com/ElementsProject/elements/releases/download/elements-23.2.3/elements-23.2.3-x86_64-linux-gnu.tar.gz
tar -xzf elements-23.2.3-x86_64-linux-gnu.tar.gz
sudo cp elements-23.2.3/bin/* /usr/local/bin/

# For macOS:
wget https://github.com/ElementsProject/elements/releases/download/elements-23.2.3/elements-23.2.3-osx64.tar.gz
tar -xzf elements-23.2.3-osx64.tar.gz
sudo cp elements-23.2.3/bin/* /usr/local/bin/

# Verify installation
elements-cli --version
```

**Start Elements in Liquid testnet mode:**

```bash
# Start daemon
elementsd -chain=liquidtestnet -validatepegin=0 -daemon

# Wait 30 seconds for initialization
sleep 30

# Create wallet
elements-cli -chain=liquidtestnet createwallet "simplicity"

# Verify it's running
elements-cli -chain=liquidtestnet getblockchaininfo
```

**Note**: You don't need to wait for blockchain sync! You can generate keys immediately.

**Stop Elements later:**
```bash
elements-cli -chain=liquidtestnet stop
```

### c) Install hal

hal is a Bitcoin companion tool for key management and signing.

```bash
cargo install hal
```

**Verify installation:**
```bash
hal --version
```

**What hal does:**
- Generate keypairs
- Sign messages with Schnorr signatures (BIP-340)
- Verify signatures
- Key manipulation (derive, inspect, etc.)

### d) Install hal-simplicity

hal-simplicity is the Simplicity extension for hal that provides:
- Sighash computation for Simplicity transactions
- Program parsing and address generation
- Simplicity-specific transaction operations

```bash
cargo install hal-simplicity
```

**Verify installation:**
```bash
hal-simplicity --version
```

**What hal-simplicity does:**
- Computes sighash for Simplicity transactions (the NEW method!)
- Generates addresses from Simplicity programs
- Parses and inspects Simplicity programs
- Creates and decodes Simplicity transactions

**Code Reference:**
- hal-simplicity sighash implementation: [`test.rs`](../test.rs#L138-L256) (in parent directory)
- The sighash command builds `ElementsEnv` and calls `c_tx_env().sighash_all()`
- Under the hood: [`rust-simplicity/simplicity-sys/src/c_jets/c_env/elements.rs`](https://github.com/BlockstreamResearch/rust-simplicity/blob/master/simplicity-sys/src/c_jets/c_env/elements.rs#L150-L153)

### e) Install simplicity_tx_tool

simplicity_tx_tool builds complete Simplicity transactions with proper witness encoding. It uses the **same taproot construction as hal-simplicity and Web IDE**, ensuring compatibility.

```bash
cargo install --git https://github.com/iajhff/simplicitytxtool
```

**Verify installation:**
```bash
simplicity_tx_tool --help
```

**What simplicity_tx_tool does:**
- Builds complete transactions from contract + witness + UTXO data
- Handles control block generation automatically
- Encodes witness stack properly: `[witness_bytes, program_bytes, cmr, control_block]`
- Compatible with hal-simplicity addresses (uses same internal key)

**Code Reference:**
- Based on simfony library and Web IDE code
- Uses same taproot construction as Web IDE: [`simplicity-webide/src/util.rs`](https://github.com/BlockstreamResearch/simplicity-webide/blob/master/src/util.rs#L155-L219)

### Verification

Verify all tools are installed:

```bash
# Check all tools
simc --help
elements-cli --help
hal --version
hal-simplicity --version
simplicity_tx_tool --help

# All should return successfully
echo "All tools installed successfully"
```

---

## 2. Deploying Simple Contract

This section covers deploying a simple Simplicity contract that requires no witness data (always evaluates to `true`).

### a) Writing the Contract

Create a simple contract that always succeeds:

```bash
cat > simple.simf << 'EOF'
// Simple contract: always returns true
fn main() {
    ()  // Unit type - always succeeds
}
EOF
```

**Explanation:**
- `fn main()` is the entry point
- `()` is the unit type, equivalent to `true`
- This contract can be spent by anyone (no conditions)

### b) Compile Contract and Generate Address

**Compile the contract:**
```bash
simc simple.simf
```

This outputs base64-encoded Simplicity bytecode. Copy the output (e.g., `JA==`).

**Generate address and get program info:**
```bash
hal-simplicity simplicity simplicity info <base64_program>
```

Replace `<base64_program>` with the output from simc.

**Output:**
```json
{
  "cmr": "c40a10263f7436b4160acbef1c36fba4be4d95df181a968afeab5eac247adff7",
  "liquid_testnet_address_unconf": "tex1pjj4anx9xlvl05v3g9vwtcez5xsdvseprv53vnhv4f2deymtnd5rs8prcsy",
  ...
}
```

**Save these values:**
- Address: `tex1p...` (for funding)
- CMR: `c40a10263...` (for reference)

### c) Fund the Contract

**Use the faucet:**
```bash
curl "https://liquidtestnet.com/faucet?address=<your_address>&action=lbtc"
```

Replace `<your_address>` with your tex1p... address.

**Wait 30-60 seconds** for confirmation, then check the funding transaction:

```bash
curl "https://blockstream.info/liquidtestnet/api/address/<your_address>/txs"
```

**From the output, note:**
- `txid` - The funding transaction ID
- `vout` - Output index (usually 0)  
- `value` - Amount in satoshis (100000 from faucet)

**Check transaction status:**
```bash
curl "https://blockstream.info/liquidtestnet/api/tx/<funding_txid>/status"
```

### d) Generate Destination Address

**Generate a new address:**
```bash
elements-cli -chain=liquidtestnet getnewaddress
```

This returns a confidential address. **Get the unconfidential version:**
```bash
elements-cli -chain=liquidtestnet getaddressinfo <confidential_address>
```

Look for the `"unconfidential"` field in the output (starts with `tex1q...`). This is your destination address.

### e) Build and Broadcast Transaction

Use `simplicity_tx_tool` to build the complete transaction:

```bash
simplicity_tx_tool build-tx simple.simf <funding_txid> 0 100000 <destination_address> 1000 empty.wit
```

**Replace:**
- `<funding_txid>` - Transaction ID from step (c)
- `<destination_address>` - Unconfidential address from step (d)

**What this does:**
- Compiles the contract
- Builds transaction with witness stack: `[witness_bytes, program_bytes, cmr, control_block]`
- Uses same taproot construction as hal-simplicity (compatible!)
- Outputs complete transaction hex

**Output:** Transaction hex ready to broadcast

**Broadcast the transaction:**
```bash
curl -X POST "https://blockstream.info/liquidtestnet/api/tx" -d "<transaction_hex>"
```

**Response:** Transaction ID (txid)

### f) Check Transaction Status

**Check confirmation:**
```bash
curl "https://blockstream.info/liquidtestnet/api/tx/<txid>/status"
```

**Wait ~30-60 seconds** and check again if not confirmed.

**Output:**
```json
{
  "confirmed": true,
  "block_height": 2123456
}
```

**View on explorers:**
- Blockstream: `https://blockstream.info/liquidtestnet/tx/<txid>`
- Mempool.space: `https://liquid.network/testnet/tx/<txid>`

---

### Summary: Simple Contract Deployment

**Complete workflow:**
1. Write contract (`simple.simf`)
2. Compile and generate address (simc + hal-simplicity)
3. Fund address (faucet)
4. Generate destination (`elements-cli getnewaddress`)
5. Build and broadcast (`simplicity_tx_tool build-tx`)

**Tools used:**
- simc (compile contracts to Simplicity bytecode)
- hal-simplicity (generate addresses from programs)
- elements-cli (generate destination addresses)
- simplicity_tx_tool (build complete transaction with witness stack)

**Why these tools work together:**
- hal-simplicity and simplicity_tx_tool use the **same taproot construction**
- Same internal key: `0xf5919fa64ce45f8306849072b26c1bfdd2937e6b81774796ff372bd1eb5362d2`
- Addresses generated by hal-simplicity can be spent using simplicity_tx_tool
- Compatible control blocks and witness stacks

---

## 3. Deploying Contract with Witness

This section covers deploying a P2PK (Pay-to-Public-Key) contract that requires a signature witness.

We'll use the example files from `examples/`:
- `p2pk.simf` - The contract code
- `p2pk.args` - The public key parameter
- `p2pk.wit` - The signature witness (you'll generate this)

### a) The Contract Files

**Contract: `examples/p2pk.simf`**
```rust
/*
 * PAY TO PUBLIC KEY
 *
 * The coins move if the person with the given public key signs the transaction.
 */
fn main() {
    jet::bip_0340_verify((param::ALICE_PUBLIC_KEY, jet::sig_all_hash()), witness::ALICE_SIGNATURE)
}
```

**Parameters: `examples/p2pk.args`**
```json
{
    "ALICE_PUBLIC_KEY": {
        "value": "0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
        "type": "Pubkey"
    }
}
```

**Witness Template: `examples/p2pk.wit`**
```json
{
    "ALICE_SIGNATURE": {
        "value": "0x<your_signature_here>",
        "type": "Signature"
    }
}
```

**Explanation:**
- `param::ALICE_PUBLIC_KEY` - The public key from the .args file
- `jet::sig_all_hash()` - Gets the transaction sighash
  - *Implementation*: Accesses precomputed sighash from `ElementsEnv` transaction environment
- `jet::bip_0340_verify()` - Verifies the BIP-340 Schnorr signature
  - *Implementation*: [`jets-secp256k1.c#L649`](https://github.com/BlockstreamResearch/rust-simplicity/blob/master/simplicity-sys/depend/simplicity/jets-secp256k1.c#L649-L665) - calls libsecp256k1's `secp256k1_schnorrsig_verify`
- `witness::ALICE_SIGNATURE` - The signature you'll provide

**Note**: For your own contract, replace the pubkey with your own from `hal key generate`

### b) Compile and Generate Address

For this example, we'll use `simple_p2pk.simf` (embedded pubkey, no parameters needed):

**Compile the contract:**
```bash
simc simple_p2pk.simf
```

This outputs base64-encoded Simplicity bytecode. Copy the output.

**Generate address:**
```bash
hal-simplicity simplicity simplicity info <base64_program>
```

Replace `<base64_program>` with simc output.

**Output:**
```json
{
  "cmr": "119eec27a5a51b49680bcee62f9f757676bfce6ba35917d44fd08fa2e4a61610",
  "liquid_testnet_address_unconf": "tex1p8ng5dmfam5a6ljkyu646ym6yn6r9pfhylpn4gzl67p0hymc83yzs3mccce",
  ...
}
```

Copy the address for funding.

### c) Fund the Contract

**Use the faucet:**
```bash
curl "https://liquidtestnet.com/faucet?address=<your_address>&action=lbtc"
```

Replace `<your_address>` with your tex1p... address.

**Wait for confirmation** (~1 minute), then check the funding transaction:

```bash
curl "https://blockstream.info/liquidtestnet/api/address/<your_address>/txs"
```

**From the output, note:**
- `txid` - The funding transaction ID
- `vout` - Output index (usually 0)
- `value` - Amount in satoshis (100000 from faucet)

### d) Generate Destination Address

**Generate a new address:**
```bash
elements-cli -chain=liquidtestnet getnewaddress
```

This returns a confidential address. **Get the unconfidential version:**
```bash
elements-cli -chain=liquidtestnet getaddressinfo <confidential_address>
```

Look for the `"unconfidential"` field in the output (starts with `tex1q...`). This is your destination address.

### e) Compute Sighash and Sign (Using hal-simplicity - THE NEW METHOD!)

For contracts with witness data, you need to sign the transaction.

**Build unsigned transaction** (for sighash computation):

Create `tx.json`:
```json
{
  "version": 2,
  "locktime": 0,
  "input": [{"txid": "<funding_txid>", "vout": 0, "sequence": 4294967294}],
  "output": [
    {"asset": "144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49", "value": 99000, "script_pubkey": "<destination_scriptpubkey>"},
    {"asset": "144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49", "value": 1000, "script_pubkey": ""}
  ]
}
```

Create transaction hex:
```bash
hal-elements elements tx create tx.json --raw-stdout
```

**Compute sighash:**
```bash
hal-simplicity simplicity sighash <tx_hex> 0 <cmr> <control_block> -v 100000 -a 144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49 --utxo-script <funding_scriptpubkey> -g a771da8e52ee6ad581ed1e9a99825e5b3b7992225534eaa2ae23244fe26ab1c1 -s <private_key>
```

**Note:** Computing the control block requires code. For simplicity, use `simplicity_tx_tool` which computes it automatically (next step).

### f) Create Witness File

Create a witness file with a dummy signature (for testing):

```bash
cat > witness.wit << 'EOF'
{
    "SIGNATURE": {
        "value": "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "type": "Signature"
    }
}
EOF
```

**For real deployment:** Compute the actual signature using hal-simplicity sighash (see step e), then update this file.

### g) Build and Broadcast Transaction

Use `simplicity_tx_tool` to build the complete transaction:

```bash
simplicity_tx_tool build-tx simple_p2pk.simf <funding_txid> 0 100000 <destination_address> 1000 witness.wit
```

**Replace:**
- `<funding_txid>` - Transaction ID from step (c)
- `<destination_address>` - Unconfidential address from step (d)

**What this does:**
- Compiles contract with witness
- Computes control block from CMR
- Builds transaction with witness stack: `[witness_bytes, program_bytes, cmr, control_block]`
- Uses same taproot construction as hal-simplicity (compatible!)
- Outputs complete transaction hex

**Output:** Transaction hex

**Broadcast:**
```bash
curl -X POST "https://blockstream.info/liquidtestnet/api/tx" -d "<transaction_hex>"
```

**Response:** Transaction ID (txid)

### h) Check Transaction Status

**Check confirmation:**
```bash
curl "https://blockstream.info/liquidtestnet/api/tx/<txid>/status"
```

**Wait ~30-60 seconds** and check again if not confirmed.

**Output:**
```json
{
  "confirmed": true,
  "block_height": 2123456
}
```

**View on explorers:**
- Blockstream: `https://blockstream.info/liquidtestnet/tx/<txid>`
- Mempool.space: `https://liquid.network/testnet/tx/<txid>`

---

### Summary: P2PK Contract Deployment

**Complete workflow:**
1. Write contract (`simple_p2pk.simf` with embedded pubkey)
2. Compile and generate address (simc + hal-simplicity)
3. Fund address (faucet)
4. Generate destination (`elements-cli getnewaddress`)
5. Optionally: Compute sighash using hal-simplicity (educational)
6. Create witness file (`witness.wit`)
7. Build and broadcast (`simplicity_tx_tool build-tx`)

**Tools used:**
- simc (compile to Simplicity bytecode)
- hal-simplicity (generate addresses, compute sighash)
- elements-cli (generate destination addresses)
- simplicity_tx_tool (build complete transactions)

**Why these tools work together:**
hal-simplicity and simplicity_tx_tool use the **same taproot construction** (same internal key: `0xf5919fa6...`), so addresses generated by hal-simplicity can be spent using simplicity_tx_tool.

**Important:** Do not mix with `simply` tool - it uses a different internal key and will generate incompatible addresses!

---

## 4. Using the Simplicity Web IDE

The **Simplicity Web IDE** is the easiest way to deploy contracts to Liquid testnet. It provides a visual interface that handles all the complexity of transaction building, sighash computation, and signing.

**Live Demo**: https://ide.simplicity-lang.org

**Advantages:**
- No installation required (browser-based)
- Automatic sighash computation (uses the same method as hal-simplicity)
- Built-in key management
- Visual transaction builder
- Automatic witness encoding
- Direct broadcast to testnet
- Real-time error checking

**Limitations:**
- Only supports simple transactions (1 input → 1 output + 1 fee output)
- No confidential transactions
- No custom assets (L-BTC only)
- Testnet only in the public instance

**Code Reference:**
The Web IDE is built on the same Rust libraries used by the CLI tools:
- Uses `simfony` library for compilation
- Uses `simplicity` for transaction environment and sighash
- Source: https://github.com/BlockstreamResearch/simplicity-webide

---

### Step-by-Step Guide

#### Step 1: Write Your Contract

1. Open https://ide.simplicity-lang.org in your browser
2. You'll see a default P2PK (Pay-to-Public-Key) contract:

```rust
fn main() {
    let pubkey: Pubkey = 0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798;
    jet::bip_0340_verify((pubkey, jet::sig_all_hash()), witness::sig)
}

mod witness {
    const sig: Signature = 0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
}
```

3. **Customize the contract** (optional):
   - Change the `pubkey` value to your own public key
   - Modify the logic (e.g., add timelocks, multisig, etc.)
   - Or leave it as-is for testing

**Example Modifications:**

**Simple contract (always succeeds):**
```rust
fn main() {
    ()  // Always returns true
}
```

**Contract with timelock:**
```rust
fn main() {
    let lock_time: u32 = 2000000;  // Block height
    jet::check_lock_height(lock_time)
}
```

![Web IDE Screenshot - Editor](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide0.png)

---

#### Step 2: Generate Address

1. Click the **"Address"** button in the top-right
2. The address is automatically copied to your clipboard
3. The address format: `tex1p...` (Liquid testnet unconfidential P2TR)

**What happens internally:**
- Compiles your SimplicityHL code to Simplicity bytecode
- Computes the CMR (Commitment Merkle Root)
- Constructs taproot address from CMR
- Same as running `hal-simplicity simplicity info` + extracting address

**Keep the Web IDE tab open** - you'll need it for the next steps!

![Web IDE Screenshot - Address](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide1.png)

---

#### Step 3: Fund the Address

1. Go to https://liquidtestnet.com/faucet
2. Paste your address
3. Click **"Send assets"**
4. The faucet sends **100,000 satoshis** (0.001 L-BTC)

![Faucet Screenshot](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/faucet1.png)

5. **Copy the transaction ID** from the faucet response

![Faucet Transaction](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/faucet2.png)

---

#### Step 4: Look Up Funding Transaction

1. Go to https://blockstream.info/liquidtestnet
2. Paste the funding transaction ID
3. Wait for confirmation (~1 minute)

![Explorer Search](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/esplora1.png)

4. Scroll down to find your UTXO
5. Note the **vout** index (usually 0 or 1)
6. Note the **value** (usually 100000)

**Finding your UTXO:**
- Look for output with value = 100,000 sats
- The scriptPubKey will start with `512034...` (Taproot)
- In the example below, vout = 1

![Explorer UTXO](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/esplora2.png)

---

#### Step 5: Enter UTXO Data

Go back to the Web IDE and scroll down to the **"Transaction"** section.

Enter the UTXO details:

1. **Txid**: Paste the funding transaction ID
2. **Vout**: Enter the output index (e.g., `1`)
3. **Value**: Enter the value in satoshis (e.g., `100000`)

**Optional fields** (you can leave defaults):
- **Destination**: Where to send funds (default is a testnet address)
- **Fee**: Transaction fee in satoshis (default: 1000)
- **Lock time**: For time-locked contracts (default: 0)
- **Sequence**: For relative timelocks (default: 0xfffffffe)

![Web IDE Transaction Form](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide2.png)

---

#### Step 6: Generate Signature

If your contract requires a signature (like P2PK), you need to sign the transaction:

1. Click the **"Sig 0"** button
2. The Web IDE will:
   - Build the complete transaction
   - Compute the sighash (same as `hal-simplicity simplicity sighash`)
   - Sign it with the built-in key
   - Copy the signature to clipboard

**What "Sig 0" means:**
- "Sig" = Signature
- "0" = First signature slot
- If you have multiple signatures, you'd use "Sig 1", "Sig 2", etc.

**Under the hood:**
- Constructs `ElementsEnv` with transaction + UTXO data
- Calls `c_tx_env().sighash_all()` (same as hal-simplicity!)
- Signs with BIP-340 Schnorr signature
- Implementation: [`simplicity-webide/src/function.rs`](https://github.com/BlockstreamResearch/simplicity-webide/blob/master/src/function.rs)

![Web IDE Signature](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide3.png)

---

#### Step 7: Update Witness Data

If your contract needs a signature, paste it into the witness section:

1. Find the `mod witness { ... }` section in your code
2. Replace the dummy signature with the real one:

**Before:**
```rust
mod witness {
    const sig: Signature = 0x0000000000000000...;
}
```

**After (paste your signature):**
```rust
mod witness {
    const sig: Signature = 0xf74b3ca574647f8595624b129324afa2f38b598a9c1c7cfc5f08a9c036ec5acd3c0fbb9ed3dae5ca23a0a65a34b5d6cccdd6ba248985d6041f7b21262b17af6f;
}
```

**Note**: Signature is 64 bytes (128 hex characters) for BIP-340 Schnorr.

![Web IDE Witness](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide4.png)

---

#### Step 8: Build Transaction

1. Click the **"Transaction"** button
2. The complete transaction hex is copied to clipboard
3. The Web IDE builds:
   - The spending transaction
   - With your Simplicity program + witness in the witness stack
   - Properly encoded with control block
   - Ready to broadcast!

**What's included:**
- Transaction inputs (spending your UTXO)
- Transaction outputs (destination + fee)
- Witness stack:
  - Simplicity program (with witness data)
  - Control block (for taproot spending)
  - Annex (if present)

![Web IDE Transaction](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide5.png)

---

#### Step 9: Broadcast Transaction

1. Go to https://blockstream.info/liquidtestnet/tx/push
2. Paste the transaction hex
3. Click **"Broadcast transaction"**

**Success:**
If everything worked, you'll see your transaction on the explorer!

**Congratulations!** You've successfully deployed and spent a Simplicity smart contract on Liquid testnet!

**View your transaction:**
- Blockstream Explorer: `https://blockstream.info/liquidtestnet/tx/YOUR_TXID`
- Mempool.space: `https://liquid.network/testnet/tx/YOUR_TXID`

![Broadcast Result](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/esplora3.png)

---

### Advanced Features

#### Key Store Tab

The Web IDE has a **Key Store** tab for managing keys:

1. Click the **"Key Store"** tab
2. You can:
   - Generate new keypairs
   - Import existing private keys
   - View public keys
   - Manage multiple keys for multisig

**Using custom keys:**
1. Generate or import a key in the Key Store
2. Copy the public key (x-coordinate only, 32 bytes)
3. Update your contract with the new pubkey:
   ```rust
   let pubkey: Pubkey = 0xYOUR_PUBLIC_KEY_HERE;
   ```
4. Click "Address" to generate new address
5. Fund and spend as normal

#### Multiple Signatures

For contracts requiring multiple signatures (multisig):

```rust
fn main() {
    let pubkey1: Pubkey = 0xabc123...;
    let pubkey2: Pubkey = 0xdef456...;
    
    // Verify both signatures
    let sig1_valid = jet::bip_0340_verify((pubkey1, jet::sig_all_hash()), witness::sig1);
    let sig2_valid = jet::bip_0340_verify((pubkey2, jet::sig_all_hash()), witness::sig2);
    
    // Both must be valid
    jet::verify(sig1_valid);
    jet::verify(sig2_valid)
}

mod witness {
    const sig1: Signature = 0x...;
    const sig2: Signature = 0x...;
}
```

**Workflow:**
1. Click "Sig 0" to generate first signature
2. Paste into `witness::sig1`
3. Click "Sig 1" to generate second signature
4. Paste into `witness::sig2`
5. Build and broadcast

#### Parameters Tab

The **Parameters** tab allows you to:
- Define compile-time constants
- Parameterize contracts without changing code
- Useful for contract templates

**Example:**
```rust
fn main() {
    let pubkey: Pubkey = param::ALICE_PUBLIC_KEY;
    jet::bip_0340_verify((pubkey, jet::sig_all_hash()), witness::ALICE_SIGNATURE)
}
```

Then in the Parameters tab:
```json
{
    "ALICE_PUBLIC_KEY": {
        "value": "0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
        "type": "Pubkey"
    }
}
```

---

### Troubleshooting

#### Error: "Transaction not found"

**Cause**: Fake error - the transaction actually worked!

**Solution**: Wait 1 minute and reload the page. The explorer sometimes takes time to index.

---

#### Error: `bad-txns-inputs-missingorspent`

**Cause**: The UTXO doesn't exist or was already spent.

**Solution**:
1. Double-check the txid and vout
2. Wait 1 minute for confirmation
3. Make sure you haven't already spent this UTXO
4. Verify on explorer: `https://blockstream.info/liquidtestnet/tx/YOUR_TXID`

---

#### Error: `bad-txns-in-ne-out, value in != value out`

**Cause**: Input value ≠ output value + fee

**Solution**:
1. Verify the UTXO value is correct (check on explorer)
2. Make sure: `input_value = output_value + fee`
3. If input is 100,000 and fee is 1,000, output should be 99,000

---

#### Error: `bad-txns-fee-outofrange`

**Cause**: Fee is too low to cover transaction size.

**Solution**: Increase the fee (try 2000 or 5000 satoshis).

---

#### Error: `non-final`

**Cause**: Lock time is higher than current block height.

**Solution**:
1. Set lock time to 0 (if not using timelocks)
2. Or wait until block height reaches your lock time
3. Check current height: `curl https://blockstream.info/liquidtestnet/api/blocks/tip/height`

---

#### Error: `non-BIP68-final`

**Cause**: Sequence-based timelock hasn't expired yet.

**Solution**:
1. Set sequence to `0xfffffffe` (default, no timelock)
2. Or wait until relative timelock expires
3. Check UTXO confirmation time

---

#### Error: `dust`

**Cause**: Output value is too small (dust).

**Solution**:
1. Decrease the fee
2. Make sure output value > 546 satoshis
3. For Liquid testnet with 100,000 input, fee should be < 99,454

---

#### Error: `non-mandatory-script-verify-flag (Assertion failed inside jet)`

**Cause**: Your Simplicity program failed! A jet returned an error.

**Common causes:**
1. **Wrong signature**: The signature doesn't match the sighash
2. **Wrong public key**: Using different key than signature
3. **Timelock not met**: Time/height conditions not satisfied
4. **Hash preimage wrong**: For HTLC contracts

**Solution**:
1. Verify your witness data is correct
2. If you changed transaction parameters, **regenerate signatures**!
   - Any change to txid, vout, value, destination, fee, locktime, or sequence changes the sighash
   - You must click "Sig 0" again to regenerate
3. Double-check public keys match your private keys
4. For timelocks, verify block height/time conditions

**Important**: Every time you modify transaction parameters, the sighash changes and you need new signatures!

---

#### Error: `non-mandatory-script-verify-flag (Witness program hash mismatch)`

**Cause**: The CMR in the UTXO doesn't match the CMR in your current program.

**What this means:**
- You funded address A (with program A)
- But you're trying to spend with program B
- The CMRs don't match!

**Solution**:
1. **Best**: Restore your original program code from backup
2. **Alternative**: Try to reconstruct the exact program you used to create the address
3. **Last resort**: Consider the funds locked (if you can't recover the program)

**Prevention**: Always save your contract code after funding!

---

### Tips and Best Practices

#### 1. Save Your Code!

**Critical**: Always save your contract code after generating an address and funding it.

- Copy to a file
- Use version control (git)
- Keep backups

If you lose your code, you lose access to your funds!

#### 2. Test with Small Amounts

- Testnet is free, but practice good habits
- Test with default 100,000 sats from faucet
- Don't try to send large amounts on testnet

#### 3. Use the Browser Console

Open browser DevTools (F12) to see:
- Compilation errors
- Detailed error messages
- Transaction hex before broadcast

#### 4. Regenerate Signatures After Changes

**Remember**: If you change ANY transaction parameter, you must regenerate signatures!

Parameters that affect sighash:
- Txid
- Vout
- Value
- Destination
- Fee
- Lock time
- Sequence

Changes that DON'T affect sighash:
- Witness data (signatures, preimages)
- Comments in code

#### 5. Start Simple

Before complex contracts:
1. Deploy a simple `fn main() { () }` contract
2. Then try P2PK (default example)
3. Then add timelocks
4. Then try multisig
5. Finally, build custom logic

#### 6. Use Example Programs

The Web IDE includes example programs:
- Check the examples in the SimplicityHL repository
- Study how they structure witness data
- Understand the jets they use

---

### Comparing Web IDE vs Command Line

| Feature | Web IDE | hal-simplicity CLI |
|---------|---------|-------------------|
| **Installation** | None (browser) | Requires Rust, tools |
| **Ease of Use** | Very Easy | Moderate |
| **Flexibility** | Limited (1 input/output) | Full control |
| **Key Management** | Built-in | Use hal/elements-cli |
| **Sighash Method** | Automatic | Manual (hal-simplicity) |
| **Witness Encoding** | Automatic | Manual |
| **Transaction Building** | Automatic | Manual |
| **Broadcasting** | Via explorer | Via curl/elements-cli |
| **Confidential Txs** | No | Yes (with Elements) |
| **Custom Assets** | No | Yes |
| **Multiple Inputs** | No | Yes |
| **Mainnet** | Testnet only | Any network |
| **Offline Signing** | No | Yes |
| **Best For** | Learning, testing | Production, custom needs |

**Recommendation:**
- **Beginners**: Start with Web IDE
- **Learning**: Use Web IDE to understand concepts
- **Development**: Web IDE for rapid iteration
- **Production**: Use CLI tools for security and flexibility
- **Custom txs**: Use CLI for complex transactions

---

## Next Steps

### a) Examples on GitHub

Explore more advanced contract examples:

**SimplicityHL Examples Repository:**
```
https://github.com/BlockstreamResearch/SimplicityHL/tree/master/examples
```

**Example Contracts:**
- **p2pk.simf** - Pay to public key ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/p2pk.simf))
- **p2pkh.simf** - Pay to public key hash ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/p2pkh.simf))
- **p2ms.simf** - Pay to multisig ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/p2ms.simf))
- **htlc.simf** - Hash Time-Locked Contract ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/htlc.simf))
- **hodl_vault.simf** - Time-locked vault ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/hodl_vault.simf))
- **ctv.simf** - CheckTemplateVerify covenant ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/ctv.simf))
- **escrow_with_delay.simf** - Escrow with timeout ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/escrow_with_delay.simf))
- **last_will.simf** - Inheritance contract ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/last_will.simf))
- **sighash_all_anyonecanpay.simf** - Custom sighash modes ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/sighash_all_anyonecanpay.simf))
- **non_interactive_fee_bump.simf** - Fee bumping without cooperation ([code](https://github.com/BlockstreamResearch/SimplicityHL/blob/master/examples/non_interactive_fee_bump.simf))

**Study the Code:**
Each example includes corresponding `.wit` (witness) files showing how to provide the required witness data. The examples demonstrate practical patterns you can adapt for your own contracts.

**Simplicity Web IDE:**
```
https://ide.simplicity-lang.org
```
- Visual contract development
- Built-in sighash computation
- Transaction builder
- Live on-chain deployment

### b) What Can You Build?

**Important**: Simplicity is a **stateless** contracting system. Each contract execution is independent and doesn't maintain persistent state between transactions. This is by design for security and formal verification.

Despite being stateless, Simplicity enables powerful and interesting use cases:

#### Realistic Use Cases Today

**1. Advanced Payment Conditions**
- **Multisignature**: M-of-N signature requirements
- **Timelocks**: Absolute or relative time/height locks
- **Hash Time-Locked Contracts (HTLCs)**: Lightning Network-style contracts
- **Covenant Restrictions**: Control where funds can be sent

**2. Vaults and Security**
- **Delayed Withdrawals**: Require waiting period for large withdrawals
- **Emergency Recovery**: Backup keys that activate after timelock
- **Decaying Security**: Multisig that reduces signatures needed over time

**3. Inheritance and Estate Planning**
- **Time-Locked Inheritance**: Funds unlock to heirs after inactivity period
- **Multi-Beneficiary Distribution**: Split funds between multiple heirs
- **Conditional Release**: Release funds based on multiple criteria

**4. Atomic Swaps**
- **Cross-Asset Swaps**: Trustless swaps between different assets on Liquid
- **Cross-Chain Swaps**: Atomic swaps with other UTXO chains
- **Hash-Locked Contracts**: Trustless exchange using hash preimages

**5. Oracle Integration**
- **Signature Verification**: Verify signed data from trusted oracles
- **Price-Based Conditions**: Execute only if price is within bounds
- **Time-Stamped Data**: Verify oracle data with timestamps

**6. Covenant Applications**
- **Spending Restrictions**: Limit where and how funds can move
- **Output Templates**: Enforce specific output patterns (similar to CTV)
- **Fee Bumping**: Non-interactive transaction fee increases

#### Advanced Possibilities

**STARK Proof Verification**: With OP_STARKVERIFY integration, Simplicity contracts can verify zero-knowledge proofs, enabling verification of off-chain computation and potentially bridging to other systems.

**Payment Channels**: Custom payment channel logic with more flexible conditions than standard Lightning.

**Complex Multisig**: Signature requirements that change based on amount, destination, or time.

#### The Potential

While stateless, Simplicity's formal verification capabilities and expressive power enable creating highly secure, auditable smart contracts for specific use cases. As the ecosystem develops, we expect to see interesting combinations of Simplicity contracts with off-chain computation and layer 2 systems.

### c) How to Contribute

#### Report Issues
- **GitHub Issues**: Report bugs or request features
  - SimplicityHL: https://github.com/BlockstreamResearch/SimplicityHL/issues
  - hal-simplicity: https://github.com/apoelstra/hal/issues

#### Contribute Code
1. Fork the repository
2. Create a feature branch: `git checkout -b my-feature`
3. Make your changes with clear commit messages
4. Write tests for new functionality
5. Submit a pull request

#### Write Documentation
- Improve existing docs
- Write tutorials and guides
- Create example contracts
- Translate documentation

#### Join the Community
- **Twitter**: Follow [@SimplicityLang](https://x.com/SimplicityLang) for updates and discussions
- **Telegram**: Join the [Simplicity Telegram group](https://t.me/SimplicityLang) to connect with developers

#### Improve Tooling
- VSCode extension improvements
- Better error messages
- Debugging tools
- Testing frameworks

#### Research and Formal Verification
- Verify contract properties
- Research new jets and opcodes
- Explore new use cases
- Write formal proofs

---

## Useful Command List

### SimplicityHL Compiler (simc)

#### Compile SimplicityHL to Simplicity Bytecode
```bash
simc <program.simf>
```
**Description**: Compiles a `.simf` SimplicityHL program to base64-encoded Simplicity bytecode.

**Example**:
```bash
simc p2pk.simf
```

#### Compile with Witness
```bash
simc <program.simf> <witness.wit>
```
**Description**: Compiles a SimplicityHL program with witness data included.

**Example**:
```bash
simc p2pk.simf p2pk_witness.wit
```

---

### hal-simplicity Commands

#### Parse Simplicity Program
```bash
hal-simplicity simplicity info <base64-program>
```
**Description**: Parse and decode a base64-encoded Simplicity program. Shows type, CMR, address, and structure.

**Options**:
- `--network liquidtestnet` - Generate Liquid testnet address
- `--network liquid` - Generate Liquid mainnet address
- `--witness <hex>` - Include witness data

**Example**:
```bash
hal-simplicity simplicity info "AQAAAABBKg==" --network liquidtestnet
```

#### Compute Sighash
```bash
hal-simplicity simplicity sighash <tx-hex> <input-index> <cmr> <control-block>
```
**Description**: Compute the sighash for a Simplicity transaction. This is the hash that gets signed.

**Required Arguments**:
- `<tx-hex>` - Transaction hex to sign
- `<input-index>` - Index of the input being signed (usually 0)
- `<cmr>` - CMR (Commitment Merkle Root) of the Simplicity program (hex)
- `<control-block>` - Taproot control block (hex)

**Options**:
- `-v, --utxo-value <satoshis>` - Value of UTXO being spent
- `-a, --utxo-asset <hex>` - Asset ID of UTXO (L-BTC on Liquid testnet)
- `--utxo-script <hex>` - scriptPubKey of UTXO being spent
- `-g, --genesis-hash <hex>` - Genesis hash of blockchain
- `-s, --secret-key <hex>` - Secret key to sign with (outputs signature)
- `--output json` - Output as JSON

**Example**:
```bash
hal-simplicity simplicity sighash \
  "020000000001..." \
  0 \
  "9db31454dc6d936896842e6691d3b3c38f24e98a7f4fec9e17a65f1aacda2c9b" \
  "c0be..." \
  -v 100000 \
  -a "144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49" \
  -g "a771da8e52ee6ad581ed1e9a99825e5b3b7992225534eaa2ae23244fe26ab1c1" \
  -s "0000000000000000000000000000000000000000000000000000000000000001"
```

**Under the Hood:**
- This command constructs an `ElementsEnv` with all transaction and UTXO data
- Calls `c_tx_env().sighash_all()` which computes BIP-341 style sighash
- If `-s` is provided, signs the sighash using BIP-340 Schnorr signatures
- Implementation: [`test.rs`](../test.rs#L107-L256) in parent directory

#### Generate Keypair
```bash
hal-simplicity simplicity keypair generate
```
**Description**: Generate a random private/public keypair for use with Simplicity contracts.

**Example**:
```bash
hal-simplicity simplicity keypair generate
```

---

### hal Commands (Bitcoin/Key Management)

#### Generate New Keypair
```bash
hal key generate
```
**Description**: Generate a random ECDSA keypair (private and public keys).

**Example**:
```bash
hal key generate
```

#### Derive Public Key
```bash
hal key derive <privkey>
```
**Description**: Derive the public key from a private key.

**Example**:
```bash
hal key derive 0000000000000000000000000000000000000000000000000000000000000001
```

#### Inspect Key
```bash
hal key inspect <privkey>
```
**Description**: Inspect and display information about a private key.

**Example**:
```bash
hal key inspect cVt4o7BGAig1UXywgGSmARhxMdzP5qvQsxKkSsc1XEkw3tDTQFpy
```

#### Schnorr Sign (BIP-340)
```bash
hal key schnorr-sign <privkey> <message>
```
**Description**: Sign a message using BIP-340 Schnorr signature scheme.

**Options**:
- `--reverse` - Reverse message byte order (for sighash)

**Example**:
```bash
hal key schnorr-sign 0000000000000000000000000000000000000000000000000000000000000001 abcdef123456
```

#### Schnorr Verify
```bash
hal key schnorr-verify <pubkey> <sig> <message>
```
**Description**: Verify a BIP-340 Schnorr signature.

**Example**:
```bash
hal key schnorr-verify 79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798 abcd1234... abcdef123456
```

---

### hal-elements Commands (Liquid/Elements)

#### Create Address
```bash
hal-elements elements address create <pubkey>
```
**Description**: Create a Liquid/Elements address from a public key.

**Example**:
```bash
hal-elements elements address create 0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798
```

#### Create Transaction
```bash
hal-elements elements tx create <tx-json>
```
**Description**: Create a raw Liquid/Elements transaction from JSON.

**Options**:
- `--raw-stdout` - Output raw hex to stdout

**Example**:
```bash
hal-elements elements tx create tx.json --raw-stdout
```

#### Decode Transaction
```bash
hal-elements elements tx decode <tx-hex>
```
**Description**: Decode a raw Liquid/Elements transaction to JSON.

**Example**:
```bash
hal-elements elements tx decode 020000000001...
```

---

### elements-cli Commands (Elements Core RPC)

#### Create Wallet
```bash
elements-cli -chain=liquidtestnet createwallet "<name>"
```
**Description**: Create a new wallet in Elements Core.

**Example**:
```bash
elements-cli -chain=liquidtestnet createwallet "simplicity"
```

#### Generate New Address
```bash
elements-cli -chain=liquidtestnet getnewaddress
```
**Description**: Generate a new address in the wallet.

**Example**:
```bash
elements-cli -chain=liquidtestnet getnewaddress
```

#### Get Address Info
```bash
elements-cli -chain=liquidtestnet getaddressinfo <address>
```
**Description**: Get detailed information about an address, including the unconfidential version.

**Example**:
```bash
elements-cli -chain=liquidtestnet getaddressinfo lq1qqw3e3mk4ng3ks43mh54udznuekaadh9lgwef3mwgzrfzakash...
```

#### Dump Private Key
```bash
elements-cli -chain=liquidtestnet dumpprivkey <address>
```
**Description**: Export the private key for an address (in WIF format).

**Example**:
```bash
elements-cli -chain=liquidtestnet dumpprivkey tex1q9h8yffp8jc8u4s7q7...
```

#### Get Transaction
```bash
elements-cli -chain=liquidtestnet getrawtransaction <txid> true
```
**Description**: Get a transaction by ID. Use `true` for JSON output.

**Example**:
```bash
elements-cli -chain=liquidtestnet getrawtransaction abc123... true
```

#### Send Raw Transaction
```bash
elements-cli -chain=liquidtestnet sendrawtransaction <tx-hex>
```
**Description**: Broadcast a raw transaction to the network.

**Example**:
```bash
elements-cli -chain=liquidtestnet sendrawtransaction 020000000001...
```

#### Get Blockchain Info
```bash
elements-cli -chain=liquidtestnet getblockchaininfo
```
**Description**: Get current blockchain status and info.

**Example**:
```bash
elements-cli -chain=liquidtestnet getblockchaininfo
```

---

### Blockstream API (curl)

#### Get Transaction
```bash
curl "https://blockstream.info/liquidtestnet/api/tx/<txid>"
```
**Description**: Get transaction details from Blockstream's Esplora API.

**Example**:
```bash
curl "https://blockstream.info/liquidtestnet/api/tx/abc123def456..."
```

#### Get Address Transactions
```bash
curl "https://blockstream.info/liquidtestnet/api/address/<address>/txs"
```
**Description**: Get all transactions for an address.

**Example**:
```bash
curl "https://blockstream.info/liquidtestnet/api/address/tex1p9jcvyz..."
```

#### Get Address UTXOs
```bash
curl "https://blockstream.info/liquidtestnet/api/address/<address>/utxo"
```
**Description**: Get unspent transaction outputs for an address.

**Example**:
```bash
curl "https://blockstream.info/liquidtestnet/api/address/tex1p9jcvyz..."
```

#### Get Transaction Status
```bash
curl "https://blockstream.info/liquidtestnet/api/tx/<txid>/status"
```
**Description**: Get transaction confirmation status.

**Example**:
```bash
curl "https://blockstream.info/liquidtestnet/api/tx/abc123.../status"
```

#### Broadcast Transaction
```bash
curl -X POST "https://blockstream.info/liquidtestnet/api/tx" -d "<tx-hex>"
```
**Description**: Broadcast a raw transaction to Liquid testnet.

**Example**:
```bash
curl -X POST "https://blockstream.info/liquidtestnet/api/tx" -d "020000000001..."
```

#### Fund Address (Faucet)
```bash
curl "https://liquidtestnet.com/faucet?address=<address>&action=lbtc"
```
**Description**: Request testnet L-BTC from the faucet (100,000 sats).

**Example**:
```bash
curl "https://liquidtestnet.com/faucet?address=tex1p9jcvyz...&action=lbtc"
```

---

### Useful Constants

**Liquid Testnet:**
- **Genesis Hash**: `a771da8e52ee6ad581ed1e9a99825e5b3b7992225534eaa2ae23244fe26ab1c1`
- **L-BTC Asset ID**: `144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49`
- **Address Prefix**: `tex1` (unconfidential), `tlq1` (confidential)
- **Faucet Amount**: 100,000 satoshis per request
- **Block Time**: ~1 minute

**Liquid Mainnet:**
- **Genesis Hash**: `1467c1b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5`
- **L-BTC Asset ID**: `6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d`
- **Address Prefix**: `ex1` (unconfidential), `lq1` (confidential)

---

## Troubleshooting

### Common Errors

#### "invalid Simplicity program"
- **Cause**: Incorrect base64 encoding or corrupted program
- **Solution**: Re-compile with `simc` and verify base64 output

#### "Assertion failed inside jet"
- **Cause**: Witness data doesn't satisfy program constraints (wrong signature, etc.)
- **Solution**: Verify sighash computation and signature are correct

#### "non-mandatory-script-verify-flag"
- **Cause**: Transaction structure issue or incorrect witness
- **Solution**: Check transaction construction and control block

#### "bad-txns-inputs-missingorspent"
- **Cause**: UTXO already spent or doesn't exist
- **Solution**: Verify funding transaction and output index

### Getting Help

- **GitHub Issues**: File bug reports with reproducible examples
- **Documentation**: Check official Simplicity docs
- **Community**: Ask in #simplicity on IRC/Matrix

---

## License

This guide is released under CC0-1.0 (Public Domain).

