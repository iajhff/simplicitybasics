# SIMPLICITY RELEATE TOOLS/COMMANDS

## Tools Overview

| Tool | Description |
|------|-------------|
| **simply** | SimplicityHL language CLI tool - compiler, runner, and deployment tool |
| **hal** | Bitcoin companion tool for keys, transactions, and signatures |
| **hal-elements** | Elements/Liquid extension for hal |
| **hal-simplicity** | Simplicity extension for hal |
| **simc** | SimplicityHL compiler - outputs base64 Simplicity bytecode |
| **elements-cli** | Elements Core RPC client for Liquid network operations |

---

## Installation

### Install Rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
```

### Install simply
```bash
cargo install --git https://github.com/starkware-bitcoin/simply simply
```

### Install hal
```bash
cargo install hal
```

### Install Elements Core
Download from: https://github.com/ElementsProject/elements/releases

### Install simc (SimplicityHL compiler)
```bash
cargo install --git https://github.com/BlockstreamResearch/SimplicityHL simc
```

---

## SIMPLY Commands

### simply build
Build a Simfony program
```bash
simply build --entrypoint <file>
simply build --entrypoint <file> --target-dir <dir>
simply build --witness <file> --prune
simply build --mcpp-inc-path <path>
simply build --assembly
```

### simply run
Run a Simfony program locally
```bash
simply run --entrypoint <file>
simply run --param <file>
simply run --witness <file>
simply run --param <file> --witness <file>
simply run --logging <level>  # info, debug, trace
```

### simply test
Run tests
```bash
simply test
simply test --logging <level>
```

### simply deposit
Generate a P2TR address to make a deposit
```bash
simply deposit --entrypoint <file>
simply deposit --witness <file>
simply deposit --prune
simply deposit --assembly
simply deposit --target-dir <dir>
```

### simply withdraw
Spend a transaction output
```bash
simply withdraw --entrypoint <file> --txid <txid> --destination <address>
simply withdraw --txid <txid> --destination <address> --witness <file>
simply withdraw --dry-run --txid <txid> --destination <address>
simply withdraw --prune
simply withdraw --assembly
```

---

## HAL Commands

### hal key generate
Generate a new ECDSA keypair
```bash
hal key generate
```

### hal key derive
Generate a public key from a private key
```bash
hal key derive <privkey>
```

### hal key inspect
Inspect private keys
```bash
hal key inspect <privkey>
```

### hal key schnorr-sign
Sign messages using Schnorr (BIP-340)
```bash
hal key schnorr-sign <privkey> <message>
hal key schnorr-sign --reverse <privkey> <message>
```

### hal key schnorr-verify
Verify Schnorr signatures
```bash
hal key schnorr-verify <pubkey> <sig> <message>
```

### hal key ecdsa-sign
Sign messages using ECDSA
```bash
hal key ecdsa-sign <privkey> <message>
```

### hal key ecdsa-verify
Verify ECDSA signatures
```bash
hal key ecdsa-verify <pubkey> <sig> <message>
```

### hal key negate-pubkey
Negate the public key
```bash
hal key negate-pubkey <pubkey>
```

### hal key pubkey-combine
Add a point (public key) to another
```bash
hal key pubkey-combine <pubkey1> <pubkey2>
```

### hal key pubkey-tweak-add
Add a scalar (private key) to a point (public key)
```bash
hal key pubkey-tweak-add <pubkey> <scalar>
```

### hal tx create
Create a raw transaction from JSON
```bash
hal tx create <tx-info-json>
hal tx create --raw-stdout <tx-info-json>
```

### hal tx decode
Decode a raw transaction to JSON
```bash
hal tx decode <tx-hex>
```

### hal address create
Create addresses
```bash
hal address create <pubkey>
```

### hal address inspect
Inspect addresses
```bash
hal address inspect <address>
```

### hal hash sha256
SHA-256 hash
```bash
hal hash sha256 <data>
```

### hal hash sha256d
Double SHA-256 hash
```bash
hal hash sha256d <data>
```

### hal hash ripemd160
RIPEMD-160 hash
```bash
hal hash ripemd160 <data>
```

### hal hash hash160
HASH160 (RIPEMD160(SHA256))
```bash
hal hash hash160 <data>
```

### hal message sign
Create a Bitcoin Signed Message
```bash
hal message sign <privkey> <message>
```

### hal message verify
Verify a Bitcoin Signed Message
```bash
hal message verify <signature> <message>
```

### hal message hash
Calculate Bitcoin Signed Message hash
```bash
hal message hash <message>
```

### hal message recover
Recover the pubkey and address of a Bitcoin Signed Message
```bash
hal message recover <signature> <message>
```

### hal bip32 derive
BIP-32 key derivation
```bash
hal bip32 derive <xpriv> <path>
```

### hal bip32 inspect
Inspect BIP-32 keys
```bash
hal bip32 inspect <xpriv-or-xpub>
```

### hal bip39 generate
Generate BIP-39 mnemonic
```bash
hal bip39 generate
```

### hal bip39 get-seed
Get seed from BIP-39 mnemonic
```bash
hal bip39 get-seed <mnemonic>
```

### hal bech32 encode
Encode data to bech32
```bash
hal bech32 encode <hrp> <data>
```

### hal bech32 decode
Decode bech32 string
```bash
hal bech32 decode <bech32-string>
```

### hal script decode
Decode a Bitcoin script
```bash
hal script decode <script-hex>
```

### hal psbt create
Create a PSBT from JSON
```bash
hal psbt create <psbt-info-json>
```

### hal psbt decode
Decode a PSBT to JSON
```bash
hal psbt decode <psbt-base64>
```

### hal psbt edit
Edit a PSBT
```bash
hal psbt edit <psbt-base64>
```

### hal psbt finalize
Finalize a PSBT
```bash
hal psbt finalize <psbt-base64>
```

### hal random bytes
Generate random bytes
```bash
hal random bytes <count>
```

---

## HAL-ELEMENTS Commands

### hal-elements elements address create
Create Elements addresses
```bash
hal-elements elements address create <pubkey>
```

### hal-elements elements address inspect
Inspect Elements addresses
```bash
hal-elements elements address inspect <address>
```

### hal-elements elements tx create
Create a raw Elements transaction from JSON
```bash
hal-elements elements tx create <tx-info-json>
hal-elements elements tx create --raw-stdout <tx-info-json>
```

### hal-elements elements tx decode
Decode a raw Elements transaction to JSON
```bash
hal-elements elements tx decode <tx-hex>
```

### hal-elements elements block decode
Decode an Elements block
```bash
hal-elements elements block decode <block-hex>
```

---

## HAL-SIMPLICITY Commands

### hal-simplicity simplicity address create
Create Simplicity addresses
```bash
hal-simplicity simplicity address create <program>
```

### hal-simplicity simplicity address inspect
Inspect Simplicity addresses
```bash
hal-simplicity simplicity address inspect <address>
```

### hal-simplicity simplicity keypair generate
Generate a random private/public keypair
```bash
hal-simplicity simplicity keypair generate
```

### hal-simplicity simplicity simplicity info
Parse a base64-encoded Simplicity program and decode it
```bash
hal-simplicity simplicity simplicity info <base64-program>
```

### hal-simplicity simplicity tx create
Create a raw Simplicity transaction from JSON
```bash
hal-simplicity simplicity tx create <tx-info-json>
hal-simplicity simplicity tx create --raw-stdout <tx-info-json>
```

### hal-simplicity simplicity tx decode
Decode a raw Simplicity transaction to JSON
```bash
hal-simplicity simplicity tx decode <tx-hex>
```

### hal-simplicity simplicity block decode
Decode a Simplicity block
```bash
hal-simplicity simplicity block decode <block-hex>
```

---

## SIMC Commands

### simc
Compile SimplicityHL program to base64 Simplicity bytecode
```bash
simc <program.simf>
```

### simc --debug
Compile with debug symbols
```bash
simc --debug <program.simf>
```

**Output:** Base64-encoded Simplicity program

---

## ELEMENTS-CLI Commands

### getnewaddress
Generate a new address
```bash
elements-cli -chain=liquidtestnet getnewaddress
```

### getaddressinfo
Get address information
```bash
elements-cli -chain=liquidtestnet getaddressinfo <address>
```

### dumpprivkey
Dump private key for an address
```bash
elements-cli -chain=liquidtestnet dumpprivkey <address>
```

### createwallet
Create a new wallet
```bash
elements-cli -chain=liquidtestnet createwallet "<name>"
```

### getbalance
Get wallet balance
```bash
elements-cli -chain=liquidtestnet getbalance
```

### sendtoaddress
Send to an address
```bash
elements-cli -chain=liquidtestnet sendtoaddress <address> <amount>
```

### createrawtransaction
Create a raw transaction
```bash
elements-cli -chain=liquidtestnet createrawtransaction '[{"txid":"<txid>","vout":<n>}]' '[{"<address>":<amount>}]'
```

### decoderawtransaction
Decode a raw transaction
```bash
elements-cli -chain=liquidtestnet decoderawtransaction <hex>
```

### getrawtransaction
Get raw transaction
```bash
elements-cli -chain=liquidtestnet getrawtransaction <txid>
elements-cli -chain=liquidtestnet getrawtransaction <txid> true
```

### signrawtransactionwithkey
Sign raw transaction with private key
```bash
elements-cli -chain=liquidtestnet signrawtransactionwithkey <hex> '["<privkey>"]'
```

### signrawtransactionwithwallet
Sign raw transaction with wallet
```bash
elements-cli -chain=liquidtestnet signrawtransactionwithwallet <hex>
```

### sendrawtransaction
Broadcast a raw transaction
```bash
elements-cli -chain=liquidtestnet sendrawtransaction <hex>
```

### combinerawtransaction
Combine multiple raw transactions
```bash
elements-cli -chain=liquidtestnet combinerawtransaction '["<hex1>","<hex2>"]'
```
