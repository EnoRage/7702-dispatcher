// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Dispatcher7702} from "../src/dispatcher/Dispatcher7702.sol";
import {AccessControlHook} from "../src/hooks/AccessControlHook.sol";

/// @title AccessControlHookTest - Demonstrates _SENDER_SLOT practical use
/// @notice Tests access control functionality using the reserved sender slot
contract AccessControlHookTest is Test {
    Dispatcher7702 public dispatcher;
    AccessControlHook public accessHook;

    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);

    function setUp() public {
        dispatcher = new Dispatcher7702();
        accessHook = new AccessControlHook();

        // Set up the hook
        bytes4 setOwnerSelector = AccessControlHook.setOwner.selector;
        bytes4 addUserSelector = AccessControlHook.addUser.selector;
        bytes4 depositSelector = AccessControlHook.deposit.selector;
        bytes4 withdrawSelector = AccessControlHook.withdraw.selector;

        vm.prank(address(dispatcher));
        dispatcher.setHook(setOwnerSelector, address(accessHook));

        vm.prank(address(dispatcher));
        dispatcher.setHook(addUserSelector, address(accessHook));

        vm.prank(address(dispatcher));
        dispatcher.setHook(addUserSelector, address(accessHook));

        vm.prank(address(dispatcher));
        dispatcher.setHook(depositSelector, address(accessHook));

        vm.prank(address(dispatcher));
        dispatcher.setHook(withdrawSelector, address(accessHook));

        // Register isAuthorized and getBalance functions
        bytes4 isAuthorizedSelector = AccessControlHook.isAuthorized.selector;
        bytes4 getBalanceSelector = AccessControlHook.getBalance.selector;
        vm.prank(address(dispatcher));
        dispatcher.setHook(isAuthorizedSelector, address(accessHook));
        vm.prank(address(dispatcher));
        dispatcher.setHook(getBalanceSelector, address(accessHook));
    }

    function test_AccessControlWithSenderSlot() public {
        // Alice is the account owner
        vm.deal(alice, 10 ether);

        // Alice sets herself as owner
        vm.prank(alice);
        (bool success,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.setOwner.selector, alice));
        assertTrue(success, "Alice should be able to set herself as owner");

        // Alice adds Bob as authorized user
        vm.prank(alice);
        (bool success2,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.addUser.selector, bob));
        assertTrue(success2, "Alice should be able to add Bob");

        // Verify Bob is authorized
        (bool success3, bytes memory result) =
            address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.isAuthorized.selector, bob));
        assertTrue(success3, "Should be able to check authorization");
        bool isAuthorized = abi.decode(result, (bool));
        assertTrue(isAuthorized, "Bob should be authorized");

        // Bob deposits funds
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        (bool success4,) =
            address(dispatcher).call{value: 1 ether}(abi.encodeWithSelector(AccessControlHook.deposit.selector));
        assertTrue(success4, "Bob should be able to deposit");

        // Check Bob's balance after deposit
        (bool success5, bytes memory balanceResult) =
            address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.getBalance.selector, bob));
        assertTrue(success5, "Should be able to get balance");
        uint256 balance = abi.decode(balanceResult, (uint256));
        assertEq(balance, 1 ether, "Bob should have 1 ether balance");

        // Bob tries to withdraw (should work since he's authorized)
        vm.prank(bob);
        (bool success6,) =
            address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.withdraw.selector, 0.5 ether));
        assertTrue(success6, "Bob should be able to withdraw");
    }

    function test_UnauthorizedAccessFails() public {
        // Charlie tries to deposit without being authorized
        vm.deal(charlie, 1 ether);
        vm.prank(charlie);

        (bool success,) =
            address(dispatcher).call{value: 1 ether}(abi.encodeWithSelector(AccessControlHook.deposit.selector));
        assertFalse(success, "Charlie should not be able to deposit");
    }

    function test_OnlyOwnerCanAddUsers() public {
        // Alice sets herself as owner first
        vm.prank(alice);
        (bool success,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.setOwner.selector, alice));
        assertTrue(success, "Alice should be able to set herself as owner");

        // Bob tries to add Charlie as authorized user (should fail)
        vm.prank(bob);
        (bool success2,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.addUser.selector, charlie));
        assertFalse(success2, "Bob should not be able to add users");

        // Alice (owner) adds Charlie as authorized user (should succeed)
        vm.prank(alice);
        (bool success3,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.addUser.selector, charlie));
        assertTrue(success3, "Alice should be able to add Charlie");
    }

    function test_WithdrawWithoutBalanceFails() public {
        // Alice sets herself as owner first
        vm.prank(alice);
        (bool success,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.setOwner.selector, alice));
        assertTrue(success, "Alice should be able to set herself as owner");

        // Alice adds Bob as authorized user
        vm.prank(alice);
        (bool success2,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.addUser.selector, bob));
        assertTrue(success2, "Alice should be able to add Bob");

        // Bob tries to withdraw without having a balance (should fail)
        vm.prank(bob);
        (bool success3,) =
            address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.withdraw.selector, 0.5 ether));
        assertFalse(success3, "Bob should not be able to withdraw without balance");
    }

    function test_SenderSlotIsolation() public {
        // Alice sets herself as owner first
        vm.prank(alice);
        (bool success,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.setOwner.selector, alice));
        assertTrue(success, "Alice should be able to set herself as owner");

        // Alice adds Bob as authorized user
        vm.prank(alice);
        (bool success2,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.addUser.selector, bob));
        assertTrue(success2, "Alice should be able to add Bob");

        // Bob deposits funds
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        (bool success3,) =
            address(dispatcher).call{value: 1 ether}(abi.encodeWithSelector(AccessControlHook.deposit.selector));
        assertTrue(success3, "Bob should be able to deposit");

        // Charlie tries to withdraw (should fail - not authorized)
        vm.prank(charlie);
        (bool success4,) =
            address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.withdraw.selector, 0.5 ether));
        assertFalse(success4, "Charlie should not be able to withdraw");
    }

    function test_DelegatecallContextPreservesSenderSlot() public {
        // This test demonstrates that the _SENDER_SLOT works correctly
        // in the delegatecall context where msg.sender is the dispatcher

        // Alice sets herself as owner first
        vm.prank(alice);
        (bool success,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.setOwner.selector, alice));
        assertTrue(success, "Alice should be able to set herself as owner");

        // Alice adds Bob as authorized user
        vm.prank(alice);
        (bool success2,) = address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.addUser.selector, bob));
        assertTrue(success2, "Alice should be able to add Bob");

        // Bob deposits funds through the dispatcher
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        (bool success3,) =
            address(dispatcher).call{value: 1 ether}(abi.encodeWithSelector(AccessControlHook.deposit.selector));
        assertTrue(success3, "Bob should be able to deposit through dispatcher");

        // Bob should be able to withdraw (authorized)
        vm.prank(bob);
        (bool success4,) =
            address(dispatcher).call(abi.encodeWithSelector(AccessControlHook.withdraw.selector, 0.5 ether));
        assertTrue(success4, "Bob should be able to withdraw");
    }
}
