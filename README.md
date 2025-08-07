# 7702 Dispatcher - Minimal Hook Dispatcher for EIP-7702

A minimalistic "hook dispatcher" for EIP-7702 and an example of a simple batch-calls hook. All logic fits in ~130 lines and demonstrates how to modularly extend wallet functionality while avoiding storage collisions.

## Key Concept: Individual Account Contracts

In EIP-7702, **each user gets their own account contract**. This means:
- Alice has her own `Dispatcher7702` instance
- Bob has his own `Dispatcher7702` instance  
- Charlie has his own `Dispatcher7702` instance
- Each account is completely isolated and independently configurable

## Features

- **Individual Accounts**: Each user has their own account contract instance
- **Modularity**: Any new function is added via `setHook` transaction, without contract migrations
- **Security**: Only the account contract itself can modify the hook registry
- **Minimalism**: Main contract < 200 bytes runtime-bytecode
- **Flexibility**: Hooks can contain any logic (signatures, nonce management, swap callbacks, etc.)
- **Hook Reusability**: Same hooks can be used by multiple accounts

## Architecture

### Dispatcher7702.sol
Main dispatcher contract that:
- Stores mapping of function selectors to hook addresses
- Provides fallback function for delegating calls to appropriate hooks
- Allows hook registry management only through self-calls

### BatchCallsHook.sol
Example hook for executing batch-calls:
- Executes a series of calls in a single EVM context
- Returns an array of results
- Bubble-up revert data on errors

### Types.sol
Shared type definitions used across the project.

### MockToken.sol
Mock token contract for testing scenarios.

## Installation and Setup

```bash
# Clone repository
git clone <repository-url>
cd 7702-dispatcher

# Install dependencies
forge install

# Compile
forge build

# Run tests
forge test

# Deploy (requires PRIVATE_KEY in .env)
forge script script/Deploy.s.sol --rpc-url <your-rpc-url> --broadcast
```

## Usage Examples

### Basic Usage

#### 1. Deploy Hook
```solidity
batchHook = deploy BatchCallsHook
```

#### 2. Register Hook in User's Account
```solidity
// Each user registers the hook in their own account
await aliceAccount.setHook(
    BatchCallsHook.batch.selector,   // 0x5d... (4 bytes)
    batchHook
)
```

#### 3. Use
```solidity
aliceAccount.batch([
    {to: USDC, value: 0, data: usdc.approve(spender, amount)},
    {to: UniswapV3Router, value: 0, data: router.exactInput(...)}
])
```

### Individual Account Example

```solidity
// Each user gets their own account contract
Dispatcher7702 aliceAccount = new Dispatcher7702();
Dispatcher7702 bobAccount = new Dispatcher7702();
Dispatcher7702 charlieAccount = new Dispatcher7702();

// Shared hook (can be used by multiple accounts)
BatchCallsHook sharedHook = new BatchCallsHook();

// Alice registers the hook in her account
aliceAccount.setHook(BatchCallsHook.batch.selector, address(sharedHook));

// Bob registers the same hook in his account
bobAccount.setHook(BatchCallsHook.batch.selector, address(sharedHook));

// Charlie doesn't register any hooks

// Each account works independently
aliceAccount.batch([...]); // ✅ Works
bobAccount.batch([...]);   // ✅ Works  
charlieAccount.batch([...]); // ❌ Fails - no hook registered
```

## Why This Works

- **Individual Storage**: Each account contract has its own storage space
- **No Storage Collisions**: Each module works via `delegatecall` but uses its own pre-reserved slots
- **Flexibility**: Any new function is added via `setHook` transaction
- **Security**: Only the account contract itself can modify the hook registry
- **Minimalism**: Main contract < 200 bytes runtime-bytecode
- **Hook Reusability**: Same hooks can be shared across multiple accounts

## Storage Slots

The project uses standardized transient slots:
- `_SENDER_SLOT`: For replacing `msg.sender` (optional)

## Testing

The project includes comprehensive tests demonstrating:

### Basic Functionality Tests
- Hook registration and management
- Access control (only self can modify hooks)
- Batch calls functionality
- Error handling
- ETH receiving capability

### User Account Examples
- **Individual Account Isolation**: Each user has their own account contract
- **Independent Hook Management**: Each account manages hooks independently
- **Shared Hook Reusability**: Same hooks can be used by multiple accounts
- **Real-world Scenarios**: Complex transaction examples

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test suite
forge test --match-contract UserAccountExample

# Run specific test
forge test --match-test test_RealWorldScenario
```

## Development

Possible development directions:
- Standardization of "reserved" transient slots list
- Integration with BySig module from 1inch/solidity-utils
- Adding `HookChanged(bytes4 selector, address hook)` event for indexing
- Additional hook examples (signature validation, nonce management, etc.)

## Real-World Benefits

1. **Individual Control**: Each user has full control over their account configuration
2. **Modular Extensions**: Easy to add new functionality without affecting other users
3. **Shared Ecosystem**: Common hooks can be shared and reused across the ecosystem
4. **No Storage Conflicts**: Each account's storage is completely isolated
5. **Upgradeable**: Individual accounts can be upgraded independently

## License

MIT License
