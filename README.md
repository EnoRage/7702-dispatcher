# 7702 Dispatcher - Minimal Hook Dispatcher for EIP-7702 (ALMOST FULLY VIBE CODED)

A minimalistic "hook dispatcher" for EIP-7702 and an example of a simple batch-calls hook. All logic fits in ~130 lines and demonstrates how to modularly extend wallet functionality while avoiding storage collisions.

## Features

- **Modularity**: Any new function is added via `setHook` transaction, without contract migrations
- **Security**: Only the account contract itself can modify the hook registry..
- **Minimalism**: Main contract < 200 bytes runtime-bytecode
- **Flexibility**: Hooks can contain any logic (signatures, nonce management, swap callbacks, etc.)

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

## Usage

### 1. Deploy Hook
```solidity
batchHook = deploy BatchCallsHook
```

### 2. Register Hook
```solidity
await wallet.setHook(
    BatchCallsHook.batch.selector,   // 0x5d... (4 bytes)
    batchHook
)
```

### 3. Use
```solidity
wallet.batch([
    {to: USDC, value: 0, data: usdc.approve(spender, amount)},
    {to: UniswapV3Router, value: 0, data: router.exactInput(...)}
])
```

## Why This Works

- **No Storage Collisions**: Each module works via `delegatecall` but uses its own pre-reserved slots
- **Flexibility**: Any new function is added via `setHook` transaction
- **Security**: Only the account contract itself can modify the hook registry
- **Minimalism**: Main contract < 200 bytes runtime-bytecode

## Storage Slots

The project uses standardized transient slots:
- `_SENDER_SLOT`: For replacing `msg.sender` (optional)

## Development

Possible development directions:
- Standardization of "reserved" transient slots list
- Integration with BySig module from 1inch/solidity-utils
- Adding `HookChanged(bytes4 selector, address hook)` event for indexing

## Testing

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test
forge test --match-test test_BatchCallsHook
```

## License

MIT License
