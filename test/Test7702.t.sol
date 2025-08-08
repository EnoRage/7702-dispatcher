// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/dispatcher/Dispatcher7702.sol";

contract Test7702 is Test {
    function testSignAndAttachDelegation() external {
        // Deploy dispatcher
        Dispatcher7702 dispatcher = new Dispatcher7702();

        // Test the 7702 cheatcode
        vm.signAndAttachDelegation(
            address(dispatcher), 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        );

        // Check if the EOA now has code
        address eoa = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        uint256 codeSize = eoa.code.length;

        console2.log("EOA code size:", codeSize);

        // If it works, codeSize should be > 0
        assert(codeSize > 0);
    }
}
