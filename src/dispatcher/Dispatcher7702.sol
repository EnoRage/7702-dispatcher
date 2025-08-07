// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title 7702Dispatcher – Ultra-minimal hook registry
/// @notice Minimal dispatcher that routes calls to hooks
contract Dispatcher7702 {
    mapping(bytes4 => address) public hooks;

    /// Permanent storage slot for "replacing" msg.sender (optional).
    /// Any hook can write address(this) there before internal checks.
    bytes32 internal constant _SENDER_SLOT = bytes32(uint256(keccak256("eip7702.msgsender")) - 1);

    event HookSet(bytes4 indexed selector, address indexed hook);
    event HookCleared(bytes4 indexed selector, address indexed hook);

    error AccessDenied(address caller);
    error HookIsZero();
    error NoHook(bytes4 selector);
    error RecursiveHook();

    modifier onlySelf() {
        if (msg.sender != address(this)) revert AccessDenied(msg.sender);
        _;
    }

    function setHook(bytes4 selector, address hook) external onlySelf {
        if (hook == address(0)) revert HookIsZero();
        if (hook == address(this)) revert RecursiveHook();

        hooks[selector] = hook;
        emit HookSet(selector, hook);
    }

    function clearHook(bytes4 selector) external onlySelf {
        address hook = hooks[selector];
        if (hook == address(0)) revert NoHook(selector);

        delete hooks[selector];
        emit HookCleared(selector, hook);
    }

    fallback() external payable {
        bytes4 sel;
        assembly {
            sel := calldataload(0)
        }

        address hook = hooks[sel];
        if (hook == address(0)) revert NoHook(sel);

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            let success := delegatecall(gas(), hook, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            if success { return(ptr, size) }
            revert(ptr, size)
        }
    }

    receive() external payable {}
}
