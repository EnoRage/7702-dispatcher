// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Dispatcher7702} from "../src/dispatcher/Dispatcher7702.sol";
import {CounterHook} from "../src/hooks/CounterHook.sol";
import {TokenHook} from "../src/hooks/TokenHook.sol";
import {BatchCallsHook} from "../src/hooks/BatchCallsHook.sol";
import {AccessControlHook} from "../src/hooks/AccessControlHook.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy dispatcher
        Dispatcher7702 dispatcher = new Dispatcher7702();
        console.log("Dispatcher7702 deployed at:", address(dispatcher));

        // Deploy all hooks
        CounterHook counterHook = new CounterHook();
        TokenHook tokenHook = new TokenHook();
        BatchCallsHook batchHook = new BatchCallsHook();
        AccessControlHook accessHook = new AccessControlHook();

        console.log("CounterHook deployed at:", address(counterHook));
        console.log("TokenHook deployed at:", address(tokenHook));
        console.log("BatchCallsHook deployed at:", address(batchHook));
        console.log("AccessControlHook deployed at:", address(accessHook));

        // Register hooks in dispatcher (demonstration - in reality these would be self-calls)
        vm.prank(address(dispatcher));
        dispatcher.setHook(CounterHook.increment.selector, address(counterHook));

        vm.prank(address(dispatcher));
        dispatcher.setHook(TokenHook.transfer.selector, address(tokenHook));

        vm.prank(address(dispatcher));
        dispatcher.setHook(BatchCallsHook.batch.selector, address(batchHook));

        vm.prank(address(dispatcher));
        dispatcher.setHook(AccessControlHook.deposit.selector, address(accessHook));

        console.log("All hooks registered successfully");

        vm.stopBroadcast();
    }
}
