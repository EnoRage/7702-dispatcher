# 7702 Dispatcher

Simple EIP-7702 dispatcher with hooks.

## What is EIP-7702?

EIP-7702 is a standard for modular account contracts. Instead of one big contract, you have:
- **One dispatcher** that routes calls
- **Multiple hooks** that do the actual work
- **Each user gets their own account** - no shared state

## The Problem

When multiple contracts share storage, they can overwrite each other's data.

## The Solution

Each hook gets its own unique storage key:
```solidity
bytes32 public immutable STORAGE_KEY = keccak256("HookName");
```

This ensures:
- Hook A can't overwrite Hook B's data
- User A can't overwrite User B's data
- Complete isolation between everything

## How Dispatcher Works

1. **User calls function** on their account
2. **Dispatcher checks** if hook is registered for that function
3. **If found** - calls the hook via `delegatecall`
4. **If not found** - reverts with "NoHook"

```solidity
// User calls: account.someFunction()
// Dispatcher looks up: hooks[someFunction.selector]
// If found: delegatecall to hook
// If not: revert
```

## Storage + Hooks + Dispatcher

### Storage Pattern
```solidity
contract Hook {
    bytes32 public immutable STORAGE_KEY = keccak256("HookName");
    
    struct Storage {
        uint256 value;
        address owner;
        // ... other data
    }
    
    mapping(bytes32 => Storage) private _storage;
    
    function _s() internal view returns (Storage storage) {
        return _storage[STORAGE_KEY];
    }
}
```

### How They Work Together
1. **Dispatcher** receives call → looks up hook
2. **Hook** gets called via `delegatecall` → uses its own storage key
3. **Storage** is isolated per hook + per account

### Example Flow
```solidity
// User calls: account.increment()
// 1. Dispatcher finds CounterHook registered for increment()
// 2. delegatecall to CounterHook.increment()
// 3. CounterHook uses STORAGE_KEY = keccak256("CounterHook")
// 4. Storage is isolated from other hooks and users
```

## Structure

```
src/
├── dispatcher/     # Main dispatcher
├── hooks/         # Hook contracts  
└── utils/         # Helper contracts
```

## How it works

1. **Each user gets their own account contract**
2. **Register hooks** for functions you want to use
3. **Call functions** - dispatcher routes to your hooks

## Example

```solidity
// Deploy your account
Dispatcher7702 account = new Dispatcher7702();

// Register a hook
account.setHook(selector, hookAddress);

// Use it
account.someFunction();
```

## Test

```bash
forge test
```

## Deploy

```bash
forge script script/Deploy.s.sol --rpc-url <RPC> --private-key <KEY> --broadcast
```
