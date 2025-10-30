# Complete Simplicity 2-of-3 Multisig Guide

**Everything you need to deploy and spend a Simplicity multisig contract on Liquid testnet**

No prior setup required. Follow this guide from top to bottom.

---

## Table of Contents

1. [Installation](#installation)
2. [Setup Elements Wallet](#setup-elements-wallet)
3. [The Contract Source Code](#the-contract-source-code)
4. [Compile Contract](#compile-contract)
5. [Get Contract Address](#get-contract-address)
6. [Fund Contract](#fund-contract)
7. [Create Spending PSET](#create-spending-pset)
8. [Sign Transaction](#sign-transaction)
9. [Finalize and Broadcast](#finalize-and-broadcast)

---

## Installation

### 1. Install Elements (Liquid/Elements Client)

**Option A: Download Pre-Built Binaries (Recommended - Fastest)**

```bash
# Visit GitHub releases page:
# https://github.com/ElementsProject/elements/releases

# Download the latest release for your OS (macOS example):
# elements-<version>-osx64.tar.gz

# Extract and install
tar -xzf elements-*-osx64.tar.gz
sudo cp -r elements-*/bin/* /usr/local/bin/

# Verify
which elementsd
which elements-cli
elementsd --version
```

**Option B: Build from Source**

```bash
# Clone Elements repository
git clone https://github.com/ElementsProject/elements.git
cd elements

# Build
./autogen.sh
./configure --disable-tests --disable-bench --without-gui
make -j$(sysctl -n hw.ncpu)
sudo make install

# Verify
which elementsd
which elements-cli
```

**Recommendation:** Use Option A (pre-built) unless you need to modify Elements code.

### 2. Install SimplicityHL Compiler (simc)

```bash
# Install SimplicityHL from crates.io (includes simc compiler)
cargo install simplicityhl

# Verify simc is installed
simc --help
```

**Note:** Installing `simplicityhl` from crates.io installs the `simc` compiler binary to `~/.cargo/bin/simc` automatically.

### 3. Install hal-simplicity (PSET-enabled version)

```bash
# Clone the PSET-enabled fork
git clone https://github.com/apoelstra/hal-simplicity.git
cd hal-simplicity
git checkout 2025-10/pset-signer

# Build
cargo build --release

# Install as hal-simplicity (replaces any older version)
cp target/release/hal-simplicity ~/.cargo/bin/hal-simplicity

# Verify
hal-simplicity --version
hal-simplicity simplicity pset --help
```

---

## Setup Elements Wallet

### 1. Start elementsd

```bash
# Start Elements daemon in Liquid testnet mode
elementsd -chain=liquidtestnet -daemon

# Wait for it to load

# Check it's ready
elements-cli -chain=liquidtestnet getblockchaininfo
```

**Note:** You don't need full sync - just wait for the index to load!

### 2. Create Wallet

```bash
# Create a new wallet
elements-cli -chain=liquidtestnet createwallet "simplicity_test"

# Verify
elements-cli -chain=liquidtestnet listwallets
```

### 3. Generate Signing Keys

We need 3 private keys for our 2-of-3 multisig.

**Option A: Use Test Keys (Simplest - matches p2ms.simf)**

```bash
# Use well-known test keys (DO NOT use in production!)
PRIVKEY_1="0000000000000000000000000000000000000000000000000000000000000001"
PRIVKEY_2="0000000000000000000000000000000000000000000000000000000000000002"
PRIVKEY_3="0000000000000000000000000000000000000000000000000000000000000003"

echo "Using test keys (matches contract hardcoded pubkeys)"
```

**Option B: Generate Real Keys with elements-cli (More Secure)**

```bash
# Generate 3 addresses and extract their private keys
KEY1_ADDR=$(elements-cli -chain=liquidtestnet getnewaddress "" "bech32")
KEY2_ADDR=$(elements-cli -chain=liquidtestnet getnewaddress "" "bech32")
KEY3_ADDR=$(elements-cli -chain=liquidtestnet getnewaddress "" "bech32")

# Dump private keys from wallet
PRIVKEY_1=$(elements-cli -chain=liquidtestnet dumpprivkey "$KEY1_ADDR")
PRIVKEY_2=$(elements-cli -chain=liquidtestnet dumpprivkey "$KEY2_ADDR")
PRIVKEY_3=$(elements-cli -chain=liquidtestnet dumpprivkey "$KEY3_ADDR")

# Get public keys (x-only for Schnorr)
PUBKEY_1=$(elements-cli -chain=liquidtestnet getaddressinfo "$KEY1_ADDR" | jq -r '.pubkey' | tail -c 65)
PUBKEY_2=$(elements-cli -chain=liquidtestnet getaddressinfo "$KEY2_ADDR" | jq -r '.pubkey' | tail -c 65)
PUBKEY_3=$(elements-cli -chain=liquidtestnet getaddressinfo "$KEY3_ADDR" | jq -r '.pubkey' | tail -c 65)

echo "Generated 3 keypairs:"
echo "Key 1 pubkey: $PUBKEY_1"
echo "Key 2 pubkey: $PUBKEY_2"
echo "Key 3 pubkey: $PUBKEY_3"

# NOTE: If using real keys, you MUST update p2ms.simf with your public keys!
```

**For this guide, we'll use Option A (test keys) since they match the contract.**

---

## The Contract Source Code

### 2-of-3 Multisig Contract (p2ms.simf)

Create this file: `p2ms.simf`

```rust
/*
 * PAY TO MULTISIG (2-of-3)
 *
 * The coins move if 2 of 3 people agree to move them. These people provide
 * their signatures, of which exactly 2 are required.
 */

fn not(bit: bool) -> bool {
    <u1>::into(jet::complement_1(<bool>::into(bit)))
}

fn checksig(pk: Pubkey, sig: Signature) {
    let msg: u256 = jet::sig_all_hash();
    jet::bip_0340_verify((pk, msg), sig);
}

fn checksig_add(counter: u8, pk: Pubkey, maybe_sig: Option<Signature>) -> u8 {
    match maybe_sig {
        Some(sig: Signature) => {
            checksig(pk, sig);
            let (carry, new_counter): (bool, u8) = jet::increment_8(counter);
            assert!(not(carry));
            new_counter
        }
        None => counter,
    }
}

fn check2of3multisig(pks: [Pubkey; 3], maybe_sigs: [Option<Signature>; 3]) {
    let [pk1, pk2, pk3]: [Pubkey; 3] = pks;
    let [sig1, sig2, sig3]: [Option<Signature>; 3] = maybe_sigs;

    let counter1: u8 = checksig_add(0, pk1, sig1);
    let counter2: u8 = checksig_add(counter1, pk2, sig2);
    let counter3: u8 = checksig_add(counter2, pk3, sig3);

    let threshold: u8 = 2;
    assert!(jet::eq_8(counter3, threshold));
}

fn main() {
    let pks: [Pubkey; 3] = [
        0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798, // 1*G
        0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5, // 2*G
        0xf9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9, // 3*G
    ];
    check2of3multisig(pks, witness::MAYBE_SIGS);
}
```

**Save this to:** `p2ms.simf`

### What This Contract Does

- Requires **2 signatures out of 3** possible keys
- Uses Schnorr signatures (BIP-340)
- Counts valid signatures (increment counter)
- Fails if counter ≠ 2

---

## Compile Contract

```bash

# Compile the contract
simc p2ms.simf
```

**Output:**
```
Program:
5lk2l5vmZ++dy7rFWgYpXOhwsHApv82y3OKNlZ8oFbFvgXmAR...
```

**Extract compiled program:**
```bash
# Get just the last line (the base64-encoded Simplicity bytecode)
COMPILED_PROGRAM=$(simc p2ms.simf | tail -1)
echo "Compiled Program: ${COMPILED_PROGRAM:0:100}..."
```

**What this is:**
- **Simplicity bytecode:** The compiled program in binary form
- **Base64 encoded:** For easier handling in shell scripts
- **Committed program:** No witness data yet (that comes later)

---

## Get Contract Address

```bash
# Get contract info
hal-simplicity simplicity info "$COMPILED_PROGRAM"
```

**Output:**
```json
{
  "cmr": "af5b897effb80a06fa19362347b7807dc0e774eaf4271d6526545965b44ddc3e",
  "liquid_testnet_address_unconf": "tex1p8asjc8876dzv7xrpw7rymfygnrdtvtlgmfed2kt4hw4mqwwyxhmqzann4n"
}
```

**Extract values:**
```bash
# Extract CMR (32-byte commitment hash that uniquely identifies this program)
CMR=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" | jq -r .cmr)

# Extract Taproot address (where to send funds to lock them in this contract)
CONTRACT_ADDRESS=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" | jq -r .liquid_testnet_address_unconf)

echo "CMR: $CMR"
echo "Contract Address: $CONTRACT_ADDRESS"
```

**What these are:**
- **CMR:** Commitment Merkle Root - SHA256-based hash of the program DAG
- **Address:** Bech32m Taproot address (tex1p...) derived from CMR + internal key

---

## Fund Contract

### Request funds from Liquid testnet faucet:

```bash
curl "https://liquidtestnet.com/faucet?address=${CONTRACT_ADDRESS}&action=lbtc"
```

**Output:**
```
Sent 100000 sats to address tex1p... with transaction abc123...
```

**Extract funding transaction ID:**
```bash
# Parse HTML response for txid (crude but works)
FAUCET_TX=$(curl -s "https://liquidtestnet.com/faucet?address=${CONTRACT_ADDRESS}&action=lbtc" | \
  grep -oE 'transaction [a-f0-9]{64}' | awk '{print $2}')

echo "Funding TX: $FAUCET_TX"
```

**Or manually copy from the faucet page and set:**
```bash
FAUCET_TX="<txid_from_faucet>"
```

**Wait for confirmation:**
```bash
echo "Waiting 60 seconds for confirmation..."
sleep 60
```

---

## Create Spending PSET

### 1. Set Destination (Faucet Return Address)

```bash
FAUCET_ADDRESS="tlq1qq2g07nju42l0nlx0erqa3wsel2l8prnq96rlnhml262mcj7pe8w6ndvvyg237japt83z24m8gu4v3yfhaqvrqxydadc9scsmw"
```

### 2. Create PSET with elements-cli

```bash
# Create Partially Signed Elements Transaction (PSET)
# Input: The contract UTXO we're spending
# Output 1: Send 99,900 sats to faucet address  
# Output 2: Fee of 100 sats
PSET=$(elements-cli -chain=liquidtestnet createpsbt \
  '[{"txid":"'$FAUCET_TX'","vout":0}]' \
  '[{"'$FAUCET_ADDRESS'":0.00099900},{"fee":0.00000100}]')

echo "Base PSET: $PSET"
```

**What this creates:**
- **PSET:** Partially Signed Elements Transaction (like Bitcoin's PSBT)
- **Unsigned:** No witness data yet - just the transaction template
- **Base64 encoded:** PSET format for adding metadata before signing

### 3. Get UTXO Data from Blockchain

**Option A: Using API (No sync required)**

```bash
# Query Blockstream API for transaction details
TX_DATA=$(curl -s "https://blockstream.info/liquidtestnet/api/tx/${FAUCET_TX}")

# Extract scriptPubKey (the locking script for the output)
SCRIPTPUBKEY=$(echo "$TX_DATA" | jq -r '.vout[0].scriptpubkey')

# Extract asset ID (L-BTC on testnet)
ASSET=$(echo "$TX_DATA" | jq -r '.vout[0].asset')

# Value in BTC (100,000 sats = 0.001 BTC)
VALUE="0.001"

echo "ScriptPubKey: $SCRIPTPUBKEY"
echo "Asset: $ASSET"  
echo "Value: $VALUE"
```

**Option B: Using elements-cli (If chain is synced)**

```bash
# Query local elementsd for UTXO data
UTXO_DATA=$(elements-cli -chain=liquidtestnet gettxout "$FAUCET_TX" 0)

# Extract same fields from local node
SCRIPTPUBKEY=$(echo "$UTXO_DATA" | jq -r '.scriptPubKey.hex')
ASSET=$(echo "$UTXO_DATA" | jq -r '.asset')
VALUE=$(echo "$UTXO_DATA" | jq -r '.value')

echo "ScriptPubKey: $SCRIPTPUBKEY"
echo "Asset: $ASSET"
echo "Value: $VALUE"
```

**What these values are:**
- **scriptPubKey:** The Taproot locking script (OP_1 + 32-byte tweaked key)
- **asset:** L-BTC asset ID (identifies which asset is being spent)
- **value:** Amount in BTC decimal (0.001 = 100,000 satoshis)

### 4. Update PSET with Simplicity Data

```bash
# Unspendable internal key - forces script-path spending only
# This is a NUMS (Nothing Up My Sleeve) point with no known private key
INTERNAL_KEY="50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0"

# Update PSET input 0 with:
# -i: UTXO being spent (scriptPubKey:assetID:amount)
# -c: CMR (commitment to the Simplicity program)
# -p: Internal key (used to build Taproot address)
UPDATED=$(hal-simplicity simplicity pset update-input "$PSET" 0 \
  -i "${SCRIPTPUBKEY}:${ASSET}:${VALUE}" \
  -c "$CMR" \
  -p "$INTERNAL_KEY")

# Extract the updated PSET from JSON response
PSET=$(echo "$UPDATED" | jq -r .pset)

echo "Updated PSET: ${PSET:0:100}..."
```

**What this does:**
- Attaches UTXO data to PSET (what we're spending)
- Attaches CMR (identifies our Simplicity program)
- Attaches internal key (needed for Taproot address reconstruction)
- **Result:** PSET now has everything needed for sighash calculation

---

## Sign Transaction

### 1. Calculate Sighash and Sign with Key 1

```bash
# hal-pset calculates sighash AND signs in one command:
# - Reads PSET to get transaction data
# - Computes SIGHASH_ALL hash (32 bytes)
# - Signs hash with PRIVKEY_1 using Schnorr (BIP-340)
# - Returns 64-byte signature
SIGNATURE_1=$(hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1" | jq -r .signature)

echo "Signature 1: ${SIGNATURE_1:0:64}..."
```

**What this is:**
- **sighash:** 32-byte hash of transaction data (what gets signed)
- **-x flag:** Automatically signs the hash with the private key
- **Signature:** 64-byte Schnorr signature (BIP-340 format)

### 2. Calculate Sighash and Sign with Key 3

```bash
# Sign with private key 3 (we'll use keys 1 and 3, skip key 2 for 2-of-3)
SIGNATURE_3=$(hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_3" | jq -r .signature)

echo "Signature 3: ${SIGNATURE_3:0:64}..."
```

**Why 2 signatures:**
- Contract requires **2-of-3** signatures
- We provide signatures from key #1 and key #3
- Key #2 signature is omitted (None in witness)

---

## Create Witness File

```bash
# Download the witness template from GitHub
curl -o p2ms.wit https://raw.githubusercontent.com/BlockstreamResearch/SimplicityHL/master/examples/p2ms.wit

# Copy template and substitute signatures
cp p2ms.wit p2ms_signed.wit

# Replace first Some(...) with first signature
sed -i '' "s/Some([^)]*)/Some(0x$SIGNATURE_1)/" p2ms_signed.wit

# Replace last Some(...)] with second signature
sed -i '' "s/Some([^)]*)]/Some(0x$SIGNATURE_3)]/" p2ms_signed.wit

# Verify
cat p2ms_signed.wit
```

**Expected output:**
```json
{
    "MAYBE_SIGS": {
        "value": "[Some(0xabc123...), None, Some(0xdef456...)]",
        "type": "[Option<Signature>; 3]"
    }
}
```

**Why this method:**
- The `value` field must be a **string** containing the array representation
- Not a JSON array directly
- This matches SimplicityHL's expected format

---

## Compile with Witness

```bash
# Compile contract WITH witness to create "satisfied" program
# This combines the program logic with the runtime witness data
simc p2ms.simf p2ms_signed.wit
```

**Output:**
```
Program:
<base64_program>

Witness:
<base64_witness>
```

**What these are:**
- **Program:** The Simplicity bytecode (what the contract does)
- **Witness:** The runtime inputs (the 2 signatures in this case)
- Both are base64-encoded for the witness stack

**Extract both:**
```bash
COMPILED_WITH_WITNESS=$(simc p2ms.simf p2ms_signed.wit)

# Extract program (line 2 of simc output)
PROGRAM=$(echo "$COMPILED_WITH_WITNESS" | sed -n '2p')

# Extract witness (line 4 of simc output)
WITNESS=$(echo "$COMPILED_WITH_WITNESS" | sed -n '4p')

echo "Program: ${PROGRAM:0:100}..."
echo "Witness: ${WITNESS:0:100}..."
```

---

## Finalize and Broadcast

### 1. Finalize PSET

```bash
# Attach Simplicity program and witness to PSET input 0
# This adds the complete witness stack needed to spend the Simplicity contract
FINALIZED=$(hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS")

# Extract the finalized PSET
FINAL_PSET=$(echo "$FINALIZED" | jq -r .pset)

echo "Finalized PSET: ${FINAL_PSET:0:100}..."
```

**What this does:**
- Adds the **witness stack** to PSET input 0:
  - Witness data (the 2 signatures)
  - Simplicity program (the bytecode)
  - CMR (commitment hash)
  - Control block (Taproot proof)
- **Result:** PSET is now complete and ready to extract as raw transaction

### 2. Extract Raw Transaction

```bash
# Convert PSET to raw hex transaction
# finalizepsbt checks the PSET is complete and extracts the transaction
RAW_TX=$(elements-cli -chain=liquidtestnet finalizepsbt "$FINAL_PSET" | jq -r .hex)

echo "Raw Transaction: ${RAW_TX:0:100}..."
echo "Transaction Length: ${#RAW_TX} chars"
```

**What this does:**
- **finalizepsbt:** Validates PSET has all required signatures/witnesses
- **Extracts:** Raw transaction hex (ready to broadcast)
- **Output:** Serialized Elements transaction (can be sent to network)

### 3. Broadcast to Network

**Option A: Using API (No sync required)**

```bash
# Submit transaction to Blockstream API
# The API validates and broadcasts to Liquid testnet
TXID=$(curl -X POST "https://blockstream.info/liquidtestnet/api/tx" -d "$RAW_TX")

echo "Transaction ID: $TXID"
echo "View on explorer: https://blockstream.info/liquidtestnet/tx/$TXID"
```

**Option B: Using elements-cli (If chain is synced)**

```bash
# Broadcast via local elementsd node
# Node validates and relays to Liquid testnet P2P network
TXID=$(elements-cli -chain=liquidtestnet sendrawtransaction "$RAW_TX")

echo "Transaction ID: $TXID"
echo "View on explorer: https://blockstream.info/liquidtestnet/tx/$TXID"
```

**What this does:**
- **Broadcasts:** Sends transaction to Liquid testnet network
- **Validates:** Network checks signatures, scripts, amounts
- **Returns:** Transaction ID (64-character hex) if successful
- **Confirms:** Transaction propagates to miners for inclusion in next block

---

## Verification

### Check Transaction Status

```bash
# Wait a bit
sleep 30

# Check if confirmed
curl -s "https://blockstream.info/liquidtestnet/api/tx/${TXID}" | jq '.status'
```

**Expected:**
```json
{
  "confirmed": true,
  "block_height": XXX
}
```

---
