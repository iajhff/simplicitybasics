# Simplicity CLI Deployment Guide

**Status: Work in Progress, Better Tool-chain is being developed**
- Not affiliated with Blockstream or Simplicity-lang 

This guide is for advanced users who want command-line control over Simplicity contract deployment. It demonstrates the **hal-simplicity sighash method** and provides full control over the deployment process.

**For most users:** We recommend using the [Web IDE](./README.md) instead - it's much easier and works immediately in your browser!

- For an alternative developer tool visit: https://github.com/starkware-bitcoin/simply Simply uses a different internal key so do not mix and match with other tools.

---

## 3. Installing the CLI Toolchain

**Note:** This section is for advanced users who want command-line control. If you just want to deploy contracts, use the **Web IDE** (Section 2) instead.

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
  cargo install simplcityhl

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

## 4. Deploying Simple Contract (CLI)

  This section covers deploying a simple Simplicity contract that requires no witness data (always evaluates to `true`).

  ### a) Writing the Contract

  Create a simple contract that always succeeds:

  ```bash
  cat > simple.simf << 'EOF'
  fn main() {
      ()  
  }
  EOF
  ```

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

## 5. Deploying Contract with Witness (CLI)

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

  **Compute sighash:** (may not merged into main yet)
  ```bash
  hal-simplicity simplicity sighash <tx_hex> 0 <cmr> <control_block> -v 100000 -a 144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49 --utxo-script <funding_scriptpubkey> -g a771da8e52ee6ad581ed1e9a99825e5b3b7992225534eaa2ae23244fe26ab1c1 -s <private_key>
  ```
OR

```bash
simplicity_tx_tool sighash <contract.simf> <txid> <vout> <value> <destination> <fee>
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


  **Important:** Make sure whatever tool you use has the same internal key accross the tool-chain!

---

