// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title HookStorage - Struct-based storage system for hooks
/// @notice Provides a standardized pattern for hooks to use isolated storage
library HookStorage {
    /// @notice Get storage key for hook
    /// @param hookName Hook name
    function getStorageKey(string memory hookName) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hookName, ".Storage"));
    }

    /// @notice Get storage slot for hook
    /// @param hookName Hook name
    /// @param slotName Slot name
    function getSlot(string memory hookName, string memory slotName) internal pure returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encodePacked("hook", hookName, slotName))) - 1);
    }

    /// @notice Write value to hook storage
    function write(string memory hookName, string memory slotName, bytes32 value) internal {
        bytes32 slot = getSlot(hookName, slotName);
        assembly {
            sstore(slot, value)
        }
    }

    /// @notice Read value from hook storage
    function read(string memory hookName, string memory slotName) internal view returns (bytes32) {
        bytes32 slot = getSlot(hookName, slotName);
        assembly {
            return(sload(slot), 32)
        }
    }
}
