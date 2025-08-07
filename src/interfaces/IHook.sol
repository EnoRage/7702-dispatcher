// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IHook - Standard interface for 7702 dispatcher hooks
/// @notice Provides a standardized pattern for hooks to implement
interface IHook {
    /// @notice Returns the storage key for this hook
    /// @return The unique storage key for this hook
    function getStorageKey() external view returns (bytes32);

    /// @notice Validates if the hook supports the given function call
    /// @param selector The function selector being called
    /// @param data The calldata for the function call
    /// @return True if the hook supports this call, false otherwise
    function validateCall(bytes4 selector, bytes calldata data) external view returns (bool);

    /// @notice Returns the hook version for upgrade compatibility
    /// @return The version number of this hook
    function getVersion() external pure returns (uint256);

    /// @notice Returns the hook name for identification
    /// @return The name of this hook
    function getHookName() external view returns (string memory);
}
