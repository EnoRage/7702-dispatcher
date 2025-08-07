// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Reverter {
    function boom() external pure {
        revert("boom");
    }
}
