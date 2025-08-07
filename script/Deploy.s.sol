// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Dispatcher7702} from "../src/Dispatcher7702.sol";
import {BatchCallsHook} from "../src/BatchCallsHook.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy dispatcher
        Dispatcher7702 dispatcher = new Dispatcher7702();
        console.log("Dispatcher7702 deployed at:", address(dispatcher));

        // Deploy batch-calls hook
        BatchCallsHook batchHook = new BatchCallsHook();
        console.log("BatchCallsHook deployed at:", address(batchHook));

        // Register hook in dispatcher
        bytes4 selector = BatchCallsHook.batch.selector;
        console.log("Batch selector:", vm.toString(selector));
        
        // For demonstration using vm.prank, but in reality this would be a self-call
        vm.prank(address(dispatcher));
        dispatcher.setHook(selector, address(batchHook));
        console.log("Hook registered successfully");

        vm.stopBroadcast();
    }
} 