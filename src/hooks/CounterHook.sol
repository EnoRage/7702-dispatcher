// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseHook} from "./base/BaseHook.sol";

contract CounterHook is BaseHook {
    struct Storage {
        uint256 value;
        uint256 lastIncrement;
        address lastCaller;
    }

    mapping(bytes32 => Storage) private _storage;

    constructor() BaseHook() {}

    function _getHookName() internal pure override returns (string memory) {
        return "CounterHook";
    }

    function _s() internal view returns (Storage storage) {
        return _storage[STORAGE_KEY];
    }

    function increment() external returns (uint256) {
        Storage storage s = _s();

        s.value++;
        s.lastIncrement = block.timestamp;
        s.lastCaller = msg.sender;

        return s.value;
    }

    function getValue() external view returns (uint256) {
        Storage storage s = _s();
        return s.value;
    }

    function reset() external {
        Storage storage s = _s();
        s.value = 0;
        s.lastIncrement = 0;
        s.lastCaller = address(0);
    }

    function getLastCaller() external view returns (address) {
        Storage storage s = _s();
        return s.lastCaller;
    }
}
