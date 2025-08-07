# 7702 Dispatcher

Simple EIP-7702 dispatcher with hooks.

## What is EIP-7702?

EIP-7702 is a standard for modular account contracts. Instead of one big contract, you have:
- **One dispatcher** that routes calls
- **Multiple hooks** that do the actual work
- **Each user gets their own account** - no shared state

## The Problem

When multiple contracts share storage, they can overwrite each other's data. Additionally, in `delegatecall` contexts, `msg.sender` becomes the calling contract, not the original caller.

## The Solution

### Storage Isolation
Each hook gets its own unique storage key:
```solidity
bytes32 public immutable STORAGE_KEY = keccak256("HookName");
```

This ensures:
- Hook A can't overwrite Hook B's data
- User A can't overwrite User B's data
- Complete isolation between everything

### Sender Preservation
The dispatcher reserves a special storage slot for hooks to preserve the original caller:
```solidity
bytes32 constant _SENDER_SLOT = bytes32(uint256(keccak256("eip7702.msgsender")) - 1);
```

This allows hooks to:
- Store the original caller in `_SENDER_SLOT`
- Retrieve the actual sender during `delegatecall`
- Implement advanced access control patterns

## How Dispatcher Works

The dispatcher is ultra-minimal and elegant:

```solidity
contract Dispatcher7702 {
    mapping(bytes4 => address) public hooks;
    bytes32 constant _SENDER_SLOT = bytes32(uint256(keccak256("eip7702.msgsender")) - 1);

    function setHook(bytes4 selector, address hook) external onlySelf {
        hooks[selector] = hook;
        emit HookSet(selector, hook);
    }

    fallback() external payable {
        bytes4 sel;
        assembly { sel := calldataload(0) }
        
        address hook = hooks[sel];
        if (hook == address(0)) revert NoHook(sel);

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            
            let success := delegatecall(gas(), hook, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            
            if success {
                return(ptr, size)
            }
            revert(ptr, size)
        }
    }
}
```

### Flow
1. **User calls function** on their account
2. **Dispatcher extracts selector** from calldata
3. **Looks up hook** for that function selector
4. **If found** - `delegatecall` to the hook
5. **If not found** - reverts with `NoHook`

## Advanced Features

### _SENDER_SLOT Usage

The `AccessControlHook` demonstrates advanced access control using `_SENDER_SLOT`:

```solidity
contract AccessControlHook is BaseHook {
    function _getActualSender() internal view returns (address) {
        bytes32 slot = bytes32(uint256(keccak256("eip7702.msgsender")) - 1);
        bytes32 stored;
        assembly { stored := sload(slot) }
        return stored == bytes32(0) ? msg.sender : address(uint160(uint256(stored)));
    }

    function _setActualSender(address sender) internal {
        bytes32 slot = bytes32(uint256(keccak256("eip7702.msgsender")) - 1);
        assembly { sstore(slot, sender) }
    }

    function deposit() external payable {
        _setActualSender(msg.sender);  // Store original caller
        address actualSender = _getActualSender();  // Retrieve it
        require(_authorized[_s()][actualSender], "Not authorized");
        _balances[_s()][actualSender] += msg.value;
    }
}
```

This pattern allows hooks to:
- **Rewrite `msg.sender`** in `delegatecall` contexts
- **Implement proper access control** based on the original caller
- **Maintain security** while preserving functionality

## Storage Pattern

### Base Hook Structure
```solidity
abstract contract BaseHook is IHook {
    bytes32 public immutable STORAGE_KEY;
    
    constructor() {
        STORAGE_KEY = keccak256(abi.encodePacked(_getHookName()));
    }
    
    function _s() internal view returns (bytes32) {
        return STORAGE_KEY;
    }
}
```

### Hook Implementation
```solidity
contract MyHook is BaseHook {
    mapping(bytes32 => mapping(address => uint256)) private _balances;
    
    function _getHookName() internal pure override returns (string memory) {
        return "MyHook";
    }
    
    function deposit() external payable {
        _balances[_s()][msg.sender] += msg.value;
    }
}
```

## Included Hooks

### Core Hooks
- **`CounterHook`** - Simple counter with storage isolation
- **`TokenHook`** - ERC20-like token functionality
- **`BatchCallsHook`** - Execute multiple calls atomically

### Advanced Hooks
- **`AccessControlHook`** - Demonstrates `_SENDER_SLOT` usage for advanced access control

## Project Structure

```
src/
├── dispatcher/
│   └── Dispatcher7702.sol      # Ultra-minimal dispatcher
├── hooks/
│   ├── base/
│   │   └── BaseHook.sol        # Abstract base for all hooks
│   ├── CounterHook.sol         # Simple counter example
│   ├── TokenHook.sol           # Token functionality
│   ├── BatchCallsHook.sol      # Batch execution
│   └── AccessControlHook.sol   # Advanced access control
└── interfaces/
    └── IHook.sol               # Hook interface
```

## Testing

Comprehensive test coverage with 31 tests across 4 test suites:

```bash
# Run all tests
forge test

# Run specific test suite
forge test --match-contract AccessControlHookTest -v
```

### Test Coverage
- ✅ **Dispatcher Tests** (9 tests) - Core functionality, hook management, error handling
- ✅ **Storage Isolation Tests** (4 tests) - Storage key uniqueness, account isolation
- ✅ **User Account Tests** (12 tests) - Real-world scenarios, account management
- ✅ **Access Control Tests** (6 tests) - `_SENDER_SLOT` functionality, advanced patterns

## Key Features

### ✅ **Ultra-Minimal Design**
- Clean, elegant dispatcher with minimal code
- No unnecessary features or complexity
- Gas-optimized assembly for core operations

### ✅ **Storage Isolation**
- Each hook has unique `STORAGE_KEY`
- Complete isolation between hooks and users
- No storage conflicts possible

### ✅ **Advanced Access Control**
- `_SENDER_SLOT` for preserving original caller
- Proper access control in `delegatecall` contexts
- Demonstrates advanced EIP-7702 patterns

### ✅ **Production Ready**
- Comprehensive test coverage (31 tests)
- Proper error handling and events
- Gas-optimized implementation

### ✅ **Observability**
- Detailed error messages with parameters
- Events for hook management
- Clear debugging information

## Usage Example

```solidity
// Deploy your account
Dispatcher7702 account = new Dispatcher7702();

// Register hooks
account.setHook(CounterHook.increment.selector, counterHook);
account.setHook(AccessControlHook.deposit.selector, accessHook);

// Use functionality
account.increment();  // Routes to CounterHook
account.deposit{value: 1 ether}();  // Routes to AccessControlHook
```

## Deploy

```bash
forge script script/Deploy.s.sol --rpc-url <RPC> --private-key <KEY> --broadcast
```

## License

MIT
