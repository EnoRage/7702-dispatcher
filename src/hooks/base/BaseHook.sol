// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IHook} from "../../interfaces/IHook.sol";

/// @title BaseHook - Abstract base contract for 7702 dispatcher hooks
/// @notice Provides standardized storage pattern with guaranteed isolation
abstract contract BaseHook is IHook {
    /// @notice The unique storage key for this hook
    bytes32 public immutable STORAGE_KEY;

    /// @notice The version of this hook
    uint256 public constant VERSION = 1;

    /// @notice Constructor automatically sets storage key from derived contract name
    constructor() {
        STORAGE_KEY = keccak256(abi.encodePacked(_getHookName()));
    }

    /// @notice Virtual function to get hook name - override in derived contracts
    function _getHookName() internal pure virtual returns (string memory);

    /// @notice External function to get hook name (implements interface)
    function getHookName() external pure override returns (string memory) {
        return _getHookName();
    }

    /// @notice Get the storage key for this hook
    /// @return The unique storage key
    function getStorageKey() external view override returns (bytes32) {
        return STORAGE_KEY;
    }

    /// @notice Get the hook version
    /// @return The version number
    function getVersion() external pure override returns (uint256) {
        return VERSION;
    }

    /// @notice Default validation - accepts all calls
    /// @param selector The function selector
    /// @param data The calldata
    /// @return True if the call is valid
    function validateCall(bytes4 selector, bytes calldata data) external view virtual override returns (bool) {
        // Default implementation accepts all calls
        // Override in derived contracts for specific validation
        selector; // silence unused parameter warning
        data; // silence unused parameter warning
        return true;
    }

    /// @notice Get storage slot for this hook
    /// @param slot The storage slot key
    /// @return The storage value
    function _getStorage(bytes32 slot) internal view returns (bytes32) {
        return _getStorageSlot(STORAGE_KEY, slot);
    }

    /// @notice Set storage slot for this hook
    /// @param slot The storage slot key
    /// @param value The value to store
    function _setStorage(bytes32 slot, bytes32 value) internal {
        _setStorageSlot(STORAGE_KEY, slot, value);
    }

    /// @notice Get storage slot for this hook (unchecked)
    /// @param slot The storage slot key
    /// @return The storage value
    function _getStorageUnchecked(bytes32 slot) internal view returns (bytes32) {
        return _getStorageSlot(STORAGE_KEY, slot);
    }

    /// @notice Set storage slot for this hook (unchecked)
    /// @param slot The storage slot key
    /// @param value The value to store
    function _setStorageUnchecked(bytes32 slot, bytes32 value) internal {
        _setStorageSlot(STORAGE_KEY, slot, value);
    }

    /// @notice Internal function to get storage slot
    /// @param storageKey The storage key for this hook
    /// @param slot The storage slot key
    /// @return The storage value
    function _getStorageSlot(bytes32 storageKey, bytes32 slot) internal view returns (bytes32) {
        bytes32 finalSlot = keccak256(abi.encodePacked(storageKey, slot));
        assembly {
            return(sload(finalSlot), 32)
        }
    }

    /// @notice Internal function to set storage slot
    /// @param storageKey The storage key for this hook
    /// @param slot The storage slot key
    /// @param value The value to store
    function _setStorageSlot(bytes32 storageKey, bytes32 slot, bytes32 value) internal {
        bytes32 finalSlot = keccak256(abi.encodePacked(storageKey, slot));
        assembly {
            sstore(finalSlot, value)
        }
    }
}
