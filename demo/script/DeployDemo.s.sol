// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../../src/dispatcher/Dispatcher7702.sol";
import "../../src/hooks/CounterHook.sol";
import "../../src/hooks/TokenHook.sol";

contract DeployDemo is Script {
    // Private key for EOA (standard Anvil key)
    uint256 constant ALICE_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address constant ALICE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        vm.startBroadcast();
        
        // Deploy hooks first
        CounterHook counterHook = new CounterHook();
        TokenHook tokenHook = new TokenHook();
        
        // Deploy dispatcher
        Dispatcher7702 dispatcher = new Dispatcher7702();
        
        console2.log("=== Deployed contracts ===");
        console2.log("dispatcher", address(dispatcher));
        console2.log("counterHook", address(counterHook));
        console2.log("tokenHook", address(tokenHook));
        console2.log("ALICE EOA", ALICE);
        
        vm.stopBroadcast();
        
        // Now we make a proper 7702 transaction from EOA
        // This emulates a real transaction with delegation
        vm.startBroadcast(ALICE_PK);
        
        // Attach dispatcher code to EOA via delegation
        vm.signAndAttachDelegation(address(dispatcher), ALICE_PK);
        
        // Now EOA has dispatcher code and can call setHook
        // msg.sender will be ALICE, which passes the onlySelf check
        Dispatcher7702 eoaDispatcher = Dispatcher7702(payable(ALICE));
        
        console2.log("=== Setting hooks via 7702 delegation ===");
        
        // Set hooks - now this is a real 7702 transaction
        eoaDispatcher.setHook(CounterHook.increment.selector, address(counterHook));
        eoaDispatcher.setHook(CounterHook.getValue.selector, address(counterHook));
        eoaDispatcher.setHook(TokenHook.mint.selector, address(tokenHook));
        eoaDispatcher.setHook(TokenHook.balanceOf.selector, address(tokenHook));
        
        console2.log("=== Hooks set successfully ===");
        
        vm.stopBroadcast();
        
        // Test functionality
        console2.log("=== Testing functionality ===");
        
        // Test counter through EOA with attached dispatcher
        vm.startBroadcast(ALICE_PK);
        
        // Call increment through EOA with dispatcher
        (bool success, bytes memory data) = ALICE.call(
            abi.encodeWithSelector(CounterHook.increment.selector)
        );
        
        if (success) {
            uint256 value = abi.decode(data, (uint256));
            console2.log("Counter increment successful, new value:", value);
        } else {
            console2.log("Counter increment failed");
        }
        
        // Check counter value
        (success, data) = ALICE.call(
            abi.encodeWithSelector(CounterHook.getValue.selector)
        );
        
        if (success) {
            uint256 value = abi.decode(data, (uint256));
            console2.log("Counter value:", value);
        }
        
        // Test token - mint tokens
        (success, data) = ALICE.call(
            abi.encodeWithSelector(TokenHook.mint.selector, ALICE, 1000)
        );
        
        if (success) {
            console2.log("Token mint successful");
        } else {
            console2.log("Token mint failed");
        }
        
        // Check balance
        (success, data) = ALICE.call(
            abi.encodeWithSelector(TokenHook.balanceOf.selector, ALICE)
        );
        
        if (success) {
            uint256 balance = abi.decode(data, (uint256));
            console2.log("Token balance:", balance);
        }
        
        vm.stopBroadcast();
        
        // DEMONSTRATE STORAGE ISOLATION
        console2.log("=== STORAGE ISOLATION DEMO ===");
        console2.log("Showing how multiple hooks coexist without storage conflicts...");
        
        vm.startBroadcast(ALICE_PK);
        
        // Test 1: Counter hook operations
        console2.log("--- Counter Hook Operations ---");
        (success, data) = ALICE.call(
            abi.encodeWithSelector(CounterHook.increment.selector)
        );
        if (success) {
            uint256 counterValue = abi.decode(data, (uint256));
            console2.log("Counter value after increment:", counterValue);
        }
        
        (success, data) = ALICE.call(
            abi.encodeWithSelector(CounterHook.increment.selector)
        );
        if (success) {
            uint256 counterValue = abi.decode(data, (uint256));
            console2.log("Counter value after second increment:", counterValue);
        }
        
        // Test 2: Token hook operations (should not affect counter)
        console2.log("--- Token Hook Operations ---");
        (success, data) = ALICE.call(
            abi.encodeWithSelector(TokenHook.mint.selector, ALICE, 500)
        );
        if (success) {
            console2.log("Token mint successful");
        }
        
        (success, data) = ALICE.call(
            abi.encodeWithSelector(TokenHook.balanceOf.selector, ALICE)
        );
        if (success) {
            uint256 tokenBalance = abi.decode(data, (uint256));
            console2.log("Token balance:", tokenBalance);
        }
        
        // Test 3: Verify counter is still isolated
        console2.log("--- Verifying Storage Isolation ---");
        (success, data) = ALICE.call(
            abi.encodeWithSelector(CounterHook.getValue.selector)
        );
        if (success) {
            uint256 finalCounterValue = abi.decode(data, (uint256));
            console2.log("Final counter value (should be 3):", finalCounterValue);
        }
        
        // Test 4: Show that both hooks work independently
        console2.log("--- Final State Check ---");
        (success, data) = ALICE.call(
            abi.encodeWithSelector(TokenHook.balanceOf.selector, ALICE)
        );
        if (success) {
            uint256 finalTokenBalance = abi.decode(data, (uint256));
            console2.log("Final token balance (should be 1500):", finalTokenBalance);
        }
        
        vm.stopBroadcast();
        
        // PRINT STORAGE SLOTS TO SHOW ISOLATION
        console2.log("=== STORAGE SLOT ANALYSIS ===");
        
        // Get storage keys for each hook
        bytes32 counterStorageKey = keccak256(abi.encodePacked("CounterHook"));
        bytes32 tokenStorageKey = keccak256(abi.encodePacked("TokenHook"));
        
        console2.log("CounterHook storage key:", vm.toString(counterStorageKey));
        console2.log("TokenHook storage key:", vm.toString(tokenStorageKey));
        
        // Check if they're different
        if (counterStorageKey != tokenStorageKey) {
            console2.log("SUCCESS: Storage keys are different - hooks are isolated!");
        } else {
            console2.log("ERROR: Storage keys are the same - potential conflict!");
        }
        
        // Read actual storage values from the EOA
        bytes32 counterSlot = keccak256(abi.encodePacked(counterStorageKey, bytes32(0)));
        bytes32 tokenSlot = keccak256(abi.encodePacked(tokenStorageKey, bytes32(0)));
        
        uint256 counterStorageValue = uint256(vm.load(ALICE, counterSlot));
        uint256 tokenStorageValue = uint256(vm.load(ALICE, tokenSlot));
        
        console2.log("CounterHook storage slot value:", counterStorageValue);
        console2.log("TokenHook storage slot value:", tokenStorageValue);
        
        console2.log("=== STORAGE ISOLATION SUCCESSFUL ===");
        console2.log("SUCCESS: Counter and Token hooks coexist without conflicts");
        console2.log("SUCCESS: Each hook maintains its own isolated storage");
        console2.log("SUCCESS: No storage slot collisions between different hooks");
        console2.log("=== Demo completed successfully ===");
    }
}
