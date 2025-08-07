// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title 7702Dispatcher – Minimal hook registry for account contract (EIP-7702)
/// @author Anton Bukov & community
contract Dispatcher7702 {
    /* --------------------------------------------------------------------- */
    /*                              Structure                                 */
    /* --------------------------------------------------------------------- */

    /// Hooks are bound to 4-byte function selectors
    mapping(bytes4 selector => address hook) public hooks;

    /// Permanent storage slot for "replacing" msg.sender (optional).
    /// Any hook can write address(this) there before internal checks.
    bytes32 internal constant _SENDER_SLOT = bytes32(uint256(keccak256("eip7702.msgsender")) - 1);

    /* --------------------------------------------------------------------- */
    /*                               Errors                                   */
    /* --------------------------------------------------------------------- */

    error AccessDenied(address caller);
    error HookIsZero();
    error NoHook(bytes4 selector);
    error RecursiveHook();

    /* --------------------------------------------------------------------- */
    /*                              Modifier                                  */
    /* --------------------------------------------------------------------- */

    /// "Owner" is the contract itself; meaning, registry changes are only possible
    /// through self-call (i.e., through an already approved 7702 transaction)
    modifier onlySelf() {
        if (msg.sender != address(this)) revert AccessDenied(msg.sender);
        _;
    }

    /* --------------------------------------------------------------------- */
    /*                         Registry Management                            */
    /* --------------------------------------------------------------------- */

    function setHook(bytes4 selector, address hook) external onlySelf {
        if (hook == address(0)) revert HookIsZero();
        if (hook == address(this)) revert RecursiveHook();
        hooks[selector] = hook;
    }

    function clearHook(bytes4 selector) external onlySelf {
        delete hooks[selector];
    }

    /* --------------------------------------------------------------------- */
    /*                     Fallback Hook Dispatcher                          */
    /* --------------------------------------------------------------------- */

    fallback() external payable {
        // Get selector from calldata (first 4 bytes)
        bytes4 sel;
        assembly {
            sel := calldataload(0)
        }

        address hook = hooks[sel];
        if (hook == address(0)) revert NoHook(sel);

        // Make delegatecall to module – it works in wallet's storage
        bool ok;
        assembly {
            // mem[0..calldatasize) = calldata
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            ok := delegatecall(gas(), hook, ptr, calldatasize(), 0, 0)

            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch ok
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    receive() external payable {}
}
