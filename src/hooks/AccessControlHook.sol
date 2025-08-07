// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseHook} from "./base/BaseHook.sol";

/// @title AccessControlHook - Demonstrates _SENDER_SLOT usage
/// @notice Shows how to "rewrite" msg.sender for advanced access control
contract AccessControlHook is BaseHook {
    mapping(bytes32 => mapping(address => bool)) private _authorized;
    mapping(bytes32 => mapping(address => uint256)) private _balances;
    mapping(bytes32 => address) private _owner;

    function _getHookName() internal pure override returns (string memory) {
        return "AccessControlHook";
    }

    function _s() internal view returns (bytes32) {
        return STORAGE_KEY;
    }

    /// @notice Set owner (only once)
    function setOwner(address owner) external {
        require(_owner[_s()] == address(0), "Owner set");
        _owner[_s()] = owner;
    }

    /// @notice Add authorized user (only owner)
    function addUser(address user) external {
        require(_getActualSender() == _owner[_s()], "Not owner");
        _authorized[_s()][user] = true;
    }

    /// @notice Check if user is authorized
    function isAuthorized(address user) external view returns (bool) {
        return _authorized[_s()][user];
    }

    /// @notice Get user balance
    function getBalance(address user) external view returns (uint256) {
        return _balances[_s()][user];
    }

    /// @notice Get actual sender from _SENDER_SLOT
    function _getActualSender() internal view returns (address) {
        bytes32 slot = bytes32(uint256(keccak256("eip7702.msgsender")) - 1);
        bytes32 stored;
        assembly {
            stored := sload(slot)
        }
        return stored == bytes32(0) ? msg.sender : address(uint160(uint256(stored)));
    }

    /// @notice Set actual sender in _SENDER_SLOT
    function _setActualSender(address sender) internal {
        bytes32 slot = bytes32(uint256(keccak256("eip7702.msgsender")) - 1);
        assembly {
            sstore(slot, sender)
        }
    }

    /// @notice Deposit (only authorized users)
    function deposit() external payable {
        _setActualSender(msg.sender);
        address actualSender = _getActualSender();
        require(_authorized[_s()][actualSender], "Not authorized");
        _balances[_s()][actualSender] += msg.value;
    }

    /// @notice Withdraw (only authorized users)
    function withdraw(uint256 amount) external {
        _setActualSender(msg.sender);
        address actualSender = _getActualSender();
        require(_authorized[_s()][actualSender], "Not authorized");
        require(_balances[_s()][actualSender] >= amount, "Insufficient balance");
        _balances[_s()][actualSender] -= amount;
    }
}
