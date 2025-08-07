// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct Call {
    address to;
    uint256 value;
    bytes data;
} 