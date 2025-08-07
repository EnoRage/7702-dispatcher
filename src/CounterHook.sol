// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract CounterHook {
    bytes32 public immutable STORAGE_KEY = keccak256("CounterHook");

    struct Storage {
        uint256 value;
        uint256 lastIncrement;
        address lastCaller;
    }

    mapping(bytes32 => Storage) private _storage;

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
