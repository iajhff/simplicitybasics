# Simplicity on Liquid: Getting Started

The easiest way to deploy Simplicity smart contracts on Liquid testnet using the Web IDE. (Guide Not directly affiliated with Blockstream or Simplicity-Lang)

-[Developer Documentation](https://docs.simplicity-lang.org/documentation/how-simplicity-works/)
-[SimplicityHL Rust Docs](https://docs.rs/simplicityhl/latest/simplicityhl/)
-[SimplicityHL Repo](https://github.com/BlockstreamResearch/SimplicityHL)
-[SimplicityHL Code Examples](https://github.com/BlockstreamResearch/SimplicityHL/tree/master/examples)

---

## Table of Contents

1. [Simplicity Introduction](#simplicity-introduction)
2. [Using the Simplicity Web IDE](#using-the-simplicity-web-ide)
3. [Advanced: Command Line Guide](#advanced-command-line-guide)
4. [Next Steps](#next-steps)

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
- **Bitcoin**: Simplicity is compatible with Bitcoin but requires a soft fork activation (future)

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

---

## Using the Simplicity Web IDE

**This is the easiest way to get started with Simplicity on testnet!** No installation required, works in your browser.

 https://ide.simplicity-lang.org

**Advantages:**
- No installation required (browser-based)
- Automatic sighash computation
- Built-in key management
- Visual transaction builder
- Automatic witness encoding  
- Direct broadcast to testnet
- Real-time error checking

**Source**: https://github.com/BlockstreamResearch/simplicity-webide

---

### Step-by-Step Guide

#### Step 1: Write Your Contract

Open https://ide.simplicity-lang.org in your browser. You'll see a default P2PK contract.

You can customize it or use example contracts like:

**Simple contract (always succeeds):**
```rust
fn main() {
    ()  // Always returns true
}
```

![Web IDE Editor](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide0.png)

---

#### Step 2: Generate Address

Click the **"Address"** button. The address is copied to your clipboard.

Keep the Web IDE tab open!

![Web IDE Address](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide1.png)

---

#### Step 3: Fund the Address

1. Go to https://liquidtestnet.com/faucet
2. Paste your address
3. Click **"Send assets"**
4. Copy the transaction ID

![Faucet](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/faucet1.png)

---

#### Step 4: Look Up Funding Transaction

1. Go to https://blockstream.info/liquidtestnet
2. Paste the transaction ID
3. Wait for confirmation (~1 minute)
4. Note the **vout** and **value** (usually vout=1, value=100000)

![Explorer](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/esplora2.png)

---

#### Step 5: Enter UTXO Data

Go back to the Web IDE, scroll to **"Transaction"** section:

1. **Txid**: Paste funding transaction ID
2. **Vout**: Enter output index (e.g., `1`)
3. **Value**: Enter amount (e.g., `100000`)

Leave other fields as defaults.

![Web IDE Transaction Form](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide2.png)

---

#### Step 6: Generate Signature (if needed)

For contracts with signatures (like P2PK):

1. Click **"Sig 0"** button
2. Signature is copied to clipboard
3. Paste into your witness section

![Web IDE Signature](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide3.png)

Update your code:
```rust
mod witness {
    const SIGNATURE: Signature = 0xf74b3ca574647f8595624b129324afa2...;
}
```

---

#### Step 7: Build Transaction

Click the **"Transaction"** button. The complete transaction hex is copied to clipboard.

![Web IDE Transaction](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/webide5.png)

---

#### Step 8: Broadcast

1. Go to https://blockstream.info/liquidtestnet/tx/push
2. Paste transaction hex
3. Click **"Broadcast transaction"**

**Success!** View your transaction on the explorer.

![Broadcast Result](https://raw.githubusercontent.com/BlockstreamResearch/simplicity-webide/master/doc/esplora3.png)

---

## Advanced: Command Line Guide

For advanced users who want command-line control and access to the hal-simplicity, see:

**[CLI_GUIDE.md](./CLI_GUIDE.md)** - Complete command-line deployment guide (Work in Progress)

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
1. Fork a core repository [Blockstream Research](https://github.com/BlockstreamResearch/)

#### Write Documentation
- Improve existing docs
- Write tutorials and guides
- Create example contracts
- Translate documentation

#### Join the Community
- **Twitter**: Follow [@SimplicityLang](https://x.com/SimplicityLang) for updates and discussions
- **Telegram**: Join the [Simplicity Telegram group](https://t.me/SimplicityLang) to connect with developers

#### Improve Tooling
- Better error messages
- Debugging tools
- Testing frameworks

---

## License

This guide is released under CC0-1.0 (Public Domain).

