# 7702 Dispatcher

Simple EIP-7702 dispatcher with hooks.


## The Problem

With EIP-7702 it’s now possible to make an EOA behave like a smart contract.
It works simply: you attach a dispatcher contract to your address, and this dispatcher uses delegatecall to run code from external “hook” contracts.

But there’s a catch:
delegatecall executes the hook’s code in the storage context of your account.
If multiple hooks use the same storage slots (e.g., slot 0), they will overwrite each other’s data — even if they are completely unrelated.

Result: one piece of logic can accidentally (or maliciously) corrupt another’s state.

```
┌──────────────────────────────┐        ┌──────────────────────────────┐
│ 7702 Code Attached (X)       │        │ 7702 Code Attached (Y)        │				
│ uses storage slot 0          │        │ also uses storage slot 0      │
│ delegatecall → writes 100     │        │ delegatecall → writes 500    │
└──────────────────────────────┘        └──────────────────────────────┘
             │                                        │
             └────────────── both modify ─────────────┘
                                  ▼
              ┌──────────────────────────────────────┐
              │ EOA (Alice) Storage                  │
              │ Slot 0 → ❌ overwritten (500)        │
              │ Data from X replaced by data from Y  │
              └──────────────────────────────────────┘

```

When multiple contracts share storage, they can overwrite each other's data. Additionally, in `delegatecall` contexts, `msg.sender` becomes the calling contract, not the original caller.

## The Solution
```
┌─────────────┐   ┌───────────────────────┐   ┌──────────────────────┐   ┌─────────────────────┐
│ 👤 EOA      │──▶│  📬 Dispatcher7702    │──▶│    📇 Hook Lookup     │──▶│   🔧 CounterHook ✅  │
│ (Alice)     │   │ selector = 0x1234     │   │ 0x1234 → Counter     │   │ increment()          │
│ via EIP7702 │   │ _SENDER_SLOT=Alice    │   │ 0xa905 → Token       │   └─────────────────────┘
└─────────────┘   │ hooks[sel], delegate  │   │ 0xdead → Access      │
                  └──────────────────────┘   └──────────────────────┘
                                     │
                                     ▼
                         ┌────────────────────────────┐
                         │     🔒 Storage Pattern     │
                         │ base=keccak256("Counter")  │
                         │ user = Alice.address       │
                         │ slot=keccak256(base,user)  │
                         │ ✅ per-user / per-hook     │
                         └─────────────┬──────────────┘
                                       ▼
                          ┌──────────────────────────┐
                          │   📦 Isolated Slot #5    │
                          │ e.g. physical slot #5    │
                          └──────────────────────────┘

```

### Minimalistic Dispatcher
We replace the “shared storage mess” with a single lightweight dispatcher that:
1.	Routes calls to the correct hook based on the function selector
(selector → hook address)
2.	Preserves identity of the original caller via _SENDER_SLOT
3.	Guarantees storage isolation by giving each hook a unique storage key:
slot = keccak256(hookName, userAddress)

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

## Demo

### Prerequisites

Before running the demo, ensure you have the following installed:

- **Foundry** - Ethereum development toolkit
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

### Running the Demo

The demo showcases the complete 7702 Dispatcher functionality with storage isolation and hook management.

#### Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd 7702-dispatcher

# Run the demo
./demo/run_demo.sh
```

#### Demo Flow - Step by Step

The demo executes the following sequence of operations:

**Phase 1: Setup & Deployment**
1. **Start Anvil** - Local Ethereum node with Prague hardfork (EIP-7702 support)
2. **Deploy Dispatcher** - Deploy the main `Dispatcher7702` contract
3. **Deploy Hooks** - Deploy `CounterHook` and `TokenHook` contracts
4. **Log Addresses** - Display all deployed contract addresses

**Phase 2: EIP-7702 Delegation**
5. **Attach Dispatcher to EOA** - Use `vm.signAndAttachDelegation()` to attach dispatcher code to Alice's EOA
6. **Verify Delegation** - Confirm the EOA now has dispatcher functionality

**Phase 3: Hook Configuration**
7. **Set Counter Hook** - Configure `increment()` and `getValue()` selectors to point to `CounterHook`
8. **Set Token Hook** - Configure `mint()` and `balanceOf()` selectors to point to `TokenHook`
9. **Verify Hook Setup** - Confirm all function selectors are properly mapped

**Phase 4: Basic Functionality Testing**
10. **Test Counter Increment** - Call `increment()` through EOA with attached dispatcher
11. **Verify Counter Value** - Check that counter value increased correctly
12. **Test Token Mint** - Mint 1000 tokens to Alice's address
13. **Verify Token Balance** - Confirm token balance is updated correctly

**Phase 5: Storage Isolation Demonstration**
14. **Increment Counter Again** - Call `increment()` to show counter persistence
15. **Mint More Tokens** - Mint additional 500 tokens
16. **Verify Both States** - Confirm both counter and token states are maintained independently
17. **Final Counter Check** - Verify counter value is 3 (from 3 increments)
18. **Final Token Check** - Verify token balance is 1500 (from 2 mints)

**Phase 6: Storage Analysis**
19. **Calculate Storage Keys** - Generate unique storage keys for each hook
20. **Verify Key Uniqueness** - Confirm `CounterHook` and `TokenHook` use different storage slots
21. **Read Storage Values** - Display actual storage slot values from the EOA
22. **Confirm Isolation** - Verify no storage conflicts between hooks

**Phase 7: Validation**
23. **Storage Slot Analysis** - Show that hooks use isolated storage patterns
24. **Final State Verification** - Confirm all operations completed successfully
25. **Demo Completion** - Display success message with isolation confirmation

#### Demo Output

The demo will show:
- Contract deployment addresses
- Hook configuration
- Counter increment operations
- Token minting and balance checks
- Storage isolation verification
- Final state validation

#### Demo Features Demonstrated

- ✅ **EIP-7702 Delegation** - Attaching dispatcher code to EOA
- ✅ **Hook Management** - Setting function selectors to hook addresses
- ✅ **Storage Isolation** - Multiple hooks coexisting without conflicts
- ✅ **Real Transactions** - Actual blockchain transactions with delegation
- ✅ **Storage Analysis** - Verification of isolated storage slots

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
