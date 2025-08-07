// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Call} from "./Types.sol";

contract BatchCallsHook {
    /// Executes a series of calls and returns an array of return data
    function batch(Call[] calldata calls) external payable returns (bytes[] memory results) {
        uint256 len = calls.length;
        results = new bytes[](len);

        for (uint256 i; i < len; ++i) {
            (bool ok, bytes memory ret) = calls[i].to.call{value: calls[i].value}(calls[i].data);
            if (!ok) {
                // bubble-up revert data
                assembly {
                    revert(add(ret, 32), mload(ret))
                }
            }
            results[i] = ret;
        }
    }
}
