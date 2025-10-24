# Simplicity No Signature Contract

- Requirements: hal-simplicity (https://github.com/apoelstra/hal-simplicity/tree/2025-10/sighash), curl, jq, base64, xxd

## Helpful Constants

- Internal Key: `f5919fa64ce45f8306849072b26c1bfdd2937e6b81774796ff372bd1eb5362d2` (x-only pub key (not spendable))
- Control Block: `bef5919fa64ce45f8306849072b26c1bfdd2937e6b81774796ff372bd1eb5362d2` (derived from internal key (single leaf only))
- Testnet L-BTC Asset ID: `144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49`
- Testnet Genesis Hash: `a771da8e52ee6ad581ed1e9a99825e5b3b7992225534eaa2ae23244fe26ab1c1`

---

## Step 1: Create Program
```bash
cat > contract.simf << 'EOF'
fn main() {
    // Anyone can spend
}
EOF
```

---

## Step 2: Generate BASE64
```bash
simc contract.simf
Program:
JA==
```

## Step 3: Get Program Information 
```bash
hal-simplicity simplicity simplicity info JA==
{
  "jets": "core",
  "commit_base64": "JA==",
  "commit_decode": "unit",
  "type_arrow": "1 → 1",
  "cmr": "c40a10263f7436b4160acbef1c36fba4be4d95df181a968afeab5eac247adff7",
  "liquid_address_unconf": "ex1pjj4anx9xlvl05v3g9vwtcez5xsdvseprv53vnhv4f2deymtnd5rsxc3lpt",
  "liquid_testnet_address_unconf": "tex1pjj4anx9xlvl05v3g9vwtcez5xsdvseprv53vnhv4f2deymtnd5rs8prcsy",
  "is_redeem": false
}%  
```

---

## Step 4: Set Variables for Program Information
```bash
PROGRAM_B64=$(simc contract.simf 2>&1 | grep -A1 "Program:" | tail -1)
echo "Program (base64): $PROGRAM_B64"
CMR=$(hal-simplicity simplicity simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.cmr')
echo "CMR: $CMR"
ADDRESS=$(hal-simplicity simplicity simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.liquid_testnet_address_unconf')
echo "Address: $ADDRESS"
PROGRAM_HEX=$(echo -n "$PROGRAM_B64" | base64 -d | xxd -p | tr -d '\n')
echo "Program (hex): $PROGRAM_HEX"
CONTROL_BLOCK="bef5919fa64ce45f8306849072b26c1bfdd2937e6b81774796ff372bd1eb5362d2"
```

---

## Step 5: Verify Values

```bash
echo "=== All Values ==="
echo "Program (hex): $PROGRAM_HEX"
echo "CMR:           $CMR"
echo "Control Block: $CONTROL_BLOCK"
echo "Address:       $ADDRESS"
```

---

## Step 6: Fund Contract Address
```bash
curl "https://liquidtestnet.com/faucet?address=${ADDRESS}&action=lbtc"
```

**Wait 15-30 seconds (testnet confirmations are fast) and check for the UTXO from your funding transaction**
```bash
curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq '.'
```

---

## Step 7: Get UTXO of Transaction
```bash
curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq '.'
```

**Extract UTXO details and set as variables for easier use:**

```bash
TXID=$(curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq -r '.[0].txid')
VOUT=$(curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq -r '.[0].vout')
INPUT_VALUE=$(curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq -r '.[0].value')
FEE=500
AMOUNT=$((INPUT_VALUE - FEE))
ASSET_ID="144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49"
DESTINATION="tex1qjnr7j6u7tzh4q7djumh9rtldv5q7yllxuhaasp"
```

## Step 8: Create Transaction JSON

```bash
cat > transaction.json << EOF
{
  "version": 2,
  "locktime": {"Blocks": 0},
  "inputs": [{
    "txid": "$TXID",
    "vout": $VOUT,
    "script_sig": {"hex": ""},
    "sequence": 0,
    "is_pegin": false,
    "has_issuance": false,
    "witness": {
      "script_witness": [
        "",
        "$PROGRAM_HEX",
        "$CMR",
        "$CONTROL_BLOCK"
      ]
    }
  }],
  "outputs": [
    {
      "script_pub_key": {"address": "$DESTINATION"},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $AMOUNT},
      "nonce": {"type": "null"}
    },
    {
      "script_pub_key": {"hex": ""},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $FEE},
      "nonce": {"type": "null"}
    }
  ]
}
EOF
```

---

## Step 9: Create Transaction HEX
```bash
TX_HEX=$(cat transaction.json | hal-simplicity simplicity tx create)
```

---

## Step 10: Broadcast Your Transaction
```bash
RESULT=$(echo "$TX_HEX" | curl -s -X POST "https://blockstream.info/liquidtestnet/api/tx" -d @-)
echo "$RESULT"
```

# Simplicity P2PK Transaction with Sighash and Witness

## Step 1: Generate Test Keypair

```bash
# Generate a new keypair using hal-simplicity
KEYPAIR=$(hal-simplicity simplicity keypair generate)
echo "$KEYPAIR" | jq '.'
```

**Extract the keys:**
```bash
TEST_PRIVKEY=$(echo "$KEYPAIR" | jq -r '.secret')
TEST_PUBKEY=$(echo "$KEYPAIR" | jq -r '.x_only')

echo "Private Key: $TEST_PRIVKEY"
echo "Public Key (x-only): $TEST_PUBKEY"
```

---

## Step 2: Create P2PK Contract Source

**Important: Run this in the same terminal session where you set the variables!**

```bash
cat > p2pk_contract.simf <<EOF
fn main() {
    let pubkey: Pubkey = 0x${TEST_PUBKEY};
    let msg: u256 = jet::sig_all_hash();
    let sig: Signature = witness::SIG;
    jet::bip_0340_verify((pubkey, msg), sig);
}
EOF
```

**Verify contract:**
```bash
cat p2pk_contract.simf
```

**Expected:** Should show your public key in the 0x... field

---

## Step 3: Compile Contract

```bash
simc p2pk_contract.simf
```

---

## Step 4: Generate CMR and Address

```bash
PROGRAM_B64=$(simc p2pk_contract.simf 2>&1 | awk 'NR==2')
CMR=$(hal-simplicity simplicity simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.cmr')
ADDRESS=$(hal-simplicity simplicity simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.liquid_testnet_address_unconf')
PROGRAM_HEX=$(echo -n "$PROGRAM_B64" | base64 -d | xxd -p | tr -d '\n')
CONTROL_BLOCK="bef5919fa64ce45f8306849072b26c1bfdd2937e6b81774796ff372bd1eb5362d2"

echo "=== Contract Values ==="
echo "CMR:     $CMR"
echo "Address: $ADDRESS"
echo "Program: ${PROGRAM_HEX:0:50}..."
```

---

## Step 5: Fund the Address

```bash
curl "https://liquidtestnet.com/faucet?address=${ADDRESS}&action=lbtc"
```

**Wait 15-30 seconds for confirmation:**

---

## Step 6: Get UTXO Details

```bash
TXID=$(curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq -r '.[0].txid')
VOUT=$(curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq -r '.[0].vout')
INPUT_VALUE=$(curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq -r '.[0].value')

echo "TXID:  $TXID"
echo "VOUT:  $VOUT"
echo "VALUE: $INPUT_VALUE"
```

---

## Step 7: Set Transaction Parameters

```bash
DESTINATION="tex1qjnr7j6u7tzh4q7djumh9rtldv5q7yllxuhaasp"
FEE=500
AMOUNT=$((INPUT_VALUE - FEE))
ASSET_ID="144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49"

echo "Destination: $DESTINATION"
echo "Amount: $AMOUNT"
echo "Fee: $FEE"
```

---

## Step 8: Create Unsigned Transaction JSON

```bash
cat > unsigned_tx.json <<EOF
{
  "version": 2,
  "locktime": {"Blocks": 0},
  "inputs": [{
    "txid": "$TXID",
    "vout": $VOUT,
    "script_sig": {"hex": ""},
    "sequence": 0,
    "is_pegin": false,
    "has_issuance": false,
    "witness": {
      "script_witness": [
        "",
        "$PROGRAM_HEX",
        "$CMR",
        "$CONTROL_BLOCK"
      ]
    }
  }],
  "outputs": [
    {
      "script_pub_key": {"address": "$DESTINATION"},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $AMOUNT},
      "nonce": {"type": "null"}
    },
    {
      "script_pub_key": {"hex": ""},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $FEE},
      "nonce": {"type": "null"}
    }
  ]
}
EOF
```

---

## Step 9: Calculate Sighash and Sign

**Get the scriptPubKey from blockchain:**
```bash
# Query the funding transaction to get scriptPubKey
SCRIPT_PUBKEY=$(curl -s "https://blockstream.info/liquidtestnet/api/tx/${TXID}" | jq -r '.vout[0].scriptpubkey')
echo "ScriptPubKey: $SCRIPT_PUBKEY"
```

**Convert unsigned transaction to hex:**
```bash
UNSIGNED_TX_HEX=$(cat unsigned_tx.json | hal-simplicity simplicity tx create)
```

**Calculate sighash AND sign**
```bash
SIGHASH_RESULT=$(hal-simplicity simplicity simplicity sighash \
  "$UNSIGNED_TX_HEX" \
  0 \
  "$CMR" \
  "$CONTROL_BLOCK" \
  -i "${SCRIPT_PUBKEY}:${ASSET_ID}:0.001" \
  -x "$TEST_PRIVKEY" \
  -p "$TEST_PUBKEY")

echo "$SIGHASH_RESULT" | jq '.'
```

**Expected output:**
```json
{
  "sighash": "abc123...",
  "signature": "def456...",
  "valid_signature": null
}
```

**Extract the signature:**
```bash
SIGNATURE=$(echo "$SIGHASH_RESULT" | jq -r '.signature')
echo "Signature: $SIGNATURE"
```

**Expected:** 128 hex characters (64 bytes - Schnorr signature)

---

## Step 11: Create Final Transaction with Witness

```bash
cat > final_tx.json <<EOF
{
  "version": 2,
  "locktime": {"Blocks": 0},
  "inputs": [{
    "txid": "$TXID",
    "vout": $VOUT,
    "script_sig": {"hex": ""},
    "sequence": 0,
    "is_pegin": false,
    "has_issuance": false,
    "witness": {
      "script_witness": [
        "$SIGNATURE",
        "$PROGRAM_HEX",
        "$CMR",
        "$CONTROL_BLOCK"
      ]
    }
  }],
  "outputs": [
    {
      "script_pub_key": {"address": "$DESTINATION"},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $AMOUNT},
      "nonce": {"type": "null"}
    },
    {
      "script_pub_key": {"hex": ""},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $FEE},
      "nonce": {"type": "null"}
    }
  ]
}
EOF
```

**Verify witness stack:**
```bash
cat final_tx.json | jq '.inputs[0].witness.script_witness | map(length)'
```

**Expected:** `[128, <varies>, 64, 66]` (signature is 128 hex chars)

---

## Step 12: Convert to Raw Hex

```bash
TX_HEX=$(cat final_tx.json | hal-simplicity simplicity tx create)
echo "Transaction hex length: ${#TX_HEX}"
echo "First 100 chars: ${TX_HEX:0:100}..."
```

---

## Step 13: Broadcast Transaction

```bash
RESULT=$(echo "$TX_HEX" | curl -s -X POST "https://blockstream.info/liquidtestnet/api/tx" -d @-)
echo "$RESULT"
```

## Alternative: Using .wit Files (SimplicityHL Method)

**This shows how SimplicityHL officially handles witnesses**

### Create Witness File

**After getting the sighash, create witness.wit:**

```bash
cat > witness.wit <<EOF
{
  "SIG": {
    "value": "$SIGNATURE"
  }
}
EOF
```

**For our P2PK contract:**
```json
{
  "SIG": {
    "value": "abc123...def456..."
  }
}
```

**The witness name `SIG` matches the contract:**
```rust
fn main() {
    let sig: Signature = witness::SIG;  // ← Must match!
    ...
}
```

### Compile with Witness

```bash
simc p2pk_contract.simf witness.wit
```

**Output:**
```
Program:
<base64_program>

Witness:
<base64_witness>
```
