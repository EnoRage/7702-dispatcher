// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Dispatcher7702} from "../src/Dispatcher7702.sol";
import {BatchCallsHook} from "../src/BatchCallsHook.sol";
import {CounterHook} from "../src/CounterHook.sol";
import {TokenHook} from "../src/TokenHook.sol";
import {Call} from "../src/Types.sol";

/// @notice Test for storage isolation between hooks using struct-based storage
contract StorageIsolationTest is Test {
    Dispatcher7702 public account;
    BatchCallsHook public batchHook;
    CounterHook public counterHook;
    TokenHook public tokenHook;

    function setUp() public {
        account = new Dispatcher7702();
        batchHook = new BatchCallsHook();
        counterHook = new CounterHook();
        tokenHook = new TokenHook();
    }

    function test_StructBasedStorageIsolation() public {
        // Register hooks
        bytes4 batchSelector = BatchCallsHook.batch.selector;
        bytes4 counterSelector = CounterHook.increment.selector;
        bytes4 getValueSelector = CounterHook.getValue.selector;
        bytes4 tokenSelector = TokenHook.transfer.selector;

        vm.prank(address(account));
        account.setHook(batchSelector, address(batchHook));

        vm.prank(address(account));
        account.setHook(counterSelector, address(counterHook));

        vm.prank(address(account));
        account.setHook(getValueSelector, address(counterHook));

        vm.prank(address(account));
        account.setHook(tokenSelector, address(tokenHook));

        // Test counter functionality
        (bool success1,) = address(account).call(abi.encodeWithSelector(counterSelector));
        assertTrue(success1);

        (bool success2,) = address(account).call(abi.encodeWithSelector(counterSelector));
        assertTrue(success2);

        // Check counter value
        (bool success3, bytes memory result) = address(account).call(abi.encodeWithSelector(getValueSelector));
        assertTrue(success3);
        uint256 counterValue = abi.decode(result, (uint256));
        assertEq(counterValue, 2, "Counter should be 2");

        // Test batch functionality
        Call[] memory calls = new Call[](1);
        calls[0] = Call({to: address(0x123), value: 0, data: ""});

        (bool success4,) = address(account).call(abi.encodeWithSelector(batchSelector, calls));
        assertTrue(success4);

        // Counter value should remain unchanged after batch call
        (bool success5, bytes memory result2) = address(account).call(abi.encodeWithSelector(getValueSelector));
        assertTrue(success5);
        uint256 counterValueAfter = abi.decode(result2, (uint256));
        assertEq(counterValueAfter, 2, "Counter should still be 2 after batch call");
    }

    function test_DifferentAccountsHaveSeparateStorage() public {
        // Create two accounts
        Dispatcher7702 account1 = new Dispatcher7702();
        Dispatcher7702 account2 = new Dispatcher7702();

        bytes4 counterSelector = CounterHook.increment.selector;
        bytes4 getValueSelector = CounterHook.getValue.selector;

        // Register counter hook in both accounts
        vm.prank(address(account1));
        account1.setHook(counterSelector, address(counterHook));

        vm.prank(address(account1));
        account1.setHook(getValueSelector, address(counterHook));

        vm.prank(address(account2));
        account2.setHook(counterSelector, address(counterHook));

        vm.prank(address(account2));
        account2.setHook(getValueSelector, address(counterHook));

        // Increment counter in first account
        (bool success1,) = address(account1).call(abi.encodeWithSelector(counterSelector));
        assertTrue(success1);

        (bool success2,) = address(account1).call(abi.encodeWithSelector(counterSelector));
        assertTrue(success2);

        // Increment counter in second account
        (bool success3,) = address(account2).call(abi.encodeWithSelector(counterSelector));
        assertTrue(success3);

        // Check values

        (bool success4, bytes memory result1) = address(account1).call(abi.encodeWithSelector(getValueSelector));
        assertTrue(success4);
        uint256 value1 = abi.decode(result1, (uint256));
        assertEq(value1, 2, "Account1 counter should be 2");

        (bool success5, bytes memory result2) = address(account2).call(abi.encodeWithSelector(getValueSelector));
        assertTrue(success5);
        uint256 value2 = abi.decode(result2, (uint256));
        assertEq(value2, 1, "Account2 counter should be 1");
    }

    function test_ComplexStorageStructure() public {
        // Test TokenHook with complex storage structure
        bytes4 tokenSelector = TokenHook.transfer.selector;
        bytes4 balanceSelector = TokenHook.balanceOf.selector;
        bytes4 mintSelector = TokenHook.mint.selector;

        vm.prank(address(account));
        account.setHook(tokenSelector, address(tokenHook));

        vm.prank(address(account));
        account.setHook(balanceSelector, address(tokenHook));

        vm.prank(address(account));
        account.setHook(mintSelector, address(tokenHook));

        // Mint tokens to the account
        (bool success1,) = address(account).call(abi.encodeWithSelector(mintSelector, address(account), 1000));
        assertTrue(success1);

        // Check balance
        (bool success2, bytes memory result) =
            address(account).call(abi.encodeWithSelector(balanceSelector, address(account)));
        assertTrue(success2);
        uint256 balance = abi.decode(result, (uint256));
        assertEq(balance, 1000, "Balance should be 1000");

        // Mint tokens to address 0x456 directly
        (bool success3,) = address(account).call(abi.encodeWithSelector(mintSelector, address(0x456), 500));
        assertTrue(success3);

        // Check balances after minting
        (bool success4, bytes memory result2) =
            address(account).call(abi.encodeWithSelector(balanceSelector, address(account)));
        assertTrue(success4);
        uint256 balance1 = abi.decode(result2, (uint256));
        assertEq(balance1, 1000, "Account balance should be 1000");

        (bool success5, bytes memory result3) =
            address(account).call(abi.encodeWithSelector(balanceSelector, address(0x456)));
        assertTrue(success5);
        uint256 balance2 = abi.decode(result3, (uint256));
        assertEq(balance2, 500, "Address 0x456 balance should be 500");
    }

    function test_StorageKeyUniqueness() public {
        // Test that different hooks have different storage keys
        bytes32 batchKey = batchHook.STORAGE_KEY();
        bytes32 counterKey = counterHook.STORAGE_KEY();
        bytes32 tokenKey = tokenHook.STORAGE_KEY();

        // All keys should be different
        assertTrue(batchKey != counterKey, "BatchCallsHook and CounterHook should have different storage keys");
        assertTrue(batchKey != tokenKey, "BatchCallsHook and TokenHook should have different storage keys");
        assertTrue(counterKey != tokenKey, "CounterHook and TokenHook should have different storage keys");
    }
}
