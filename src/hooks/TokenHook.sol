// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseHook} from "./base/BaseHook.sol";

contract TokenHook is BaseHook {
    constructor() BaseHook() {
        Storage storage s = _s();
        s.owner = msg.sender;
        s.name = "Test Token";
        s.symbol = "TEST";
        s.decimals = 18;
    }

    function _getHookName() internal pure override returns (string memory) {
        return "TokenHook";
    }

    struct Storage {
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
        string name;
        string symbol;
        uint8 decimals;
        address owner;
        bool paused;
    }

    mapping(bytes32 => Storage) private _storage;

    function _s() internal view returns (Storage storage) {
        return _storage[STORAGE_KEY];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        Storage storage s = _s();

        require(!s.paused, "Token is paused");

        // In delegatecall context, msg.sender is the calling contract (Dispatcher7702)
        // We need to get the actual account address from the storage context
        address sender = msg.sender;

        require(s.balances[sender] >= amount, "Insufficient balance");

        s.balances[sender] -= amount;
        s.balances[to] += amount;

        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        Storage storage s = _s();

        require(!s.paused, "Token is paused");
        s.allowances[msg.sender][spender] = amount;

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        Storage storage s = _s();

        require(!s.paused, "Token is paused");
        require(s.balances[from] >= amount, "Insufficient balance");
        require(s.allowances[from][msg.sender] >= amount, "Insufficient allowance");

        s.balances[from] -= amount;
        s.balances[to] += amount;
        s.allowances[from][msg.sender] -= amount;

        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        Storage storage s = _s();
        return s.balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        Storage storage s = _s();
        return s.allowances[owner][spender];
    }

    function mint(address to, uint256 amount) external {
        Storage storage s = _s();

        // Set owner on first call if not set
        if (s.owner == address(0)) {
            s.owner = msg.sender;
        }

        require(msg.sender == s.owner, "Only owner can mint");

        s.balances[to] += amount;
        s.totalSupply += amount;
    }

    function pause() external {
        Storage storage s = _s();
        require(msg.sender == s.owner, "Only owner can pause");
        s.paused = true;
    }

    function unpause() external {
        Storage storage s = _s();
        require(msg.sender == s.owner, "Only owner can unpause");
        s.paused = false;
    }
}
