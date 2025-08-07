// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseHook} from "./base/BaseHook.sol";
import {Call} from "../utils/Types.sol";

contract BatchCallsHook is BaseHook {
    struct Storage {
        uint256 callCount;
        address sender;
        uint256 currentIndex;
        bool hasError;
        bytes lastError;
    }

    mapping(bytes32 => Storage) private _storage;

    constructor() BaseHook() {}

    function _getHookName() internal pure override returns (string memory) {
        return "BatchCallsHook";
    }

    function _s() internal view returns (Storage storage) {
        return _storage[STORAGE_KEY];
    }

    /// @notice Executes a series of calls and returns an array of return data
    function batch(Call[] calldata calls) external payable returns (bytes[] memory results) {
        Storage storage s = _s();

        uint256 len = calls.length;
        results = new bytes[](len);

        // Store context in our storage
        s.callCount = len;
        s.sender = msg.sender;

        for (uint256 i; i < len; ++i) {
            // Store current index
            s.currentIndex = i;

            (bool ok, bytes memory ret) = calls[i].to.call{value: calls[i].value}(calls[i].data);
            if (!ok) {
                // Store error in our storage
                s.hasError = true;
                s.lastError = ret;

                assembly {
                    revert(add(ret, 32), mload(ret))
                }
            }
            results[i] = ret;
        }

        // Clear temporary data
        s.currentIndex = 0;
        s.hasError = false;
    }
}
