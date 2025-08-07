// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Dispatcher7702} from "../src/dispatcher/Dispatcher7702.sol";
import {BatchCallsHook} from "../src/hooks/BatchCallsHook.sol";
import {MockToken} from "../src/utils/MockToken.sol";
import {Reverter} from "../src/utils/Reverter.sol";
import {EtherSink} from "../src/utils/EtherSink.sol";
import {Call} from "../src/utils/Types.sol";

/// @notice Example showing how each user has their own account contract in EIP-7702
contract UserAccountExample is Test {
    // Each user gets their own account contract
    Dispatcher7702 public aliceAccount;
    Dispatcher7702 public bobAccount;
    Dispatcher7702 public charlieAccount;

    // Shared hook (can be used by multiple accounts)
    BatchCallsHook public sharedBatchHook;

    MockToken public mockUSDC;
    MockToken public mockDAI;

    // Helper contracts
    Reverter public reverter;
    EtherSink public etherSink;

    function setUp() public {
        // Deploy shared hook (can be used by all accounts)
        sharedBatchHook = new BatchCallsHook();

        // Each user gets their own account contract
        aliceAccount = new Dispatcher7702();
        bobAccount = new Dispatcher7702();
        charlieAccount = new Dispatcher7702();

        // Deploy mock tokens
        mockUSDC = new MockToken();
        mockDAI = new MockToken();

        // Deploy helper contracts
        reverter = new Reverter();
        etherSink = new EtherSink();

        // Give some initial balances
        mockUSDC.setBalance(address(aliceAccount), 1000e6); // 1000 USDC
        mockDAI.setBalance(address(bobAccount), 500e18); // 500 DAI
    }

    function test_EachUserHasOwnAccount() public {
        // Alice registers batch hook in her account
        bytes4 selector = BatchCallsHook.batch.selector;
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(sharedBatchHook));

        // Bob registers the same hook in his account
        vm.prank(address(bobAccount));
        bobAccount.setHook(selector, address(sharedBatchHook));

        // Charlie doesn't register any hooks

        // Verify each account has its own hook registry
        assertEq(aliceAccount.hooks(selector), address(sharedBatchHook));
        assertEq(bobAccount.hooks(selector), address(sharedBatchHook));
        assertEq(charlieAccount.hooks(selector), address(0));
    }

    function test_IndependentHookManagement() public {
        bytes4 selector = BatchCallsHook.batch.selector;

        // Alice registers hook
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(sharedBatchHook));

        // Bob doesn't register hook
        // Charlie doesn't register hook

        // Only Alice can use batch calls
        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            to: address(mockUSDC),
            value: 0,
            data: abi.encodeWithSelector(MockToken.transfer.selector, address(1), 100e6)
        });

        // Alice's call succeeds
        bytes memory callData = abi.encodeWithSelector(selector, calls);
        (bool aliceSuccess,) = address(aliceAccount).call(callData);
        assertTrue(aliceSuccess, "Alice should be able to use batch calls");

        // Bob's call fails (no hook registered)
        (bool bobSuccess,) = address(bobAccount).call(callData);
        assertFalse(bobSuccess, "Bob should not be able to use batch calls");

        // Charlie's call fails (no hook registered)
        (bool charlieSuccess,) = address(charlieAccount).call(callData);
        assertFalse(charlieSuccess, "Charlie should not be able to use batch calls");
    }

    function test_SharedHookDifferentConfigurations() public {
        // Alice can register different hooks than Bob
        bytes4 batchSelector = BatchCallsHook.batch.selector;

        // Alice registers batch hook
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(batchSelector, address(sharedBatchHook));

        // Bob registers a different hook (or no hook)
        // Bob could register a different hook here if we had one

        // Each account maintains its own configuration
        assertEq(aliceAccount.hooks(batchSelector), address(sharedBatchHook));
        assertEq(bobAccount.hooks(batchSelector), address(0));
    }

    function test_AccountIsolation() public {
        // Each account has its own storage and state
        bytes4 selector = BatchCallsHook.batch.selector;

        // Alice registers hook
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(sharedBatchHook));

        // Alice can use her account
        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            to: address(mockUSDC),
            value: 0,
            data: abi.encodeWithSelector(MockToken.transfer.selector, address(1), 100e6)
        });

        bytes memory callData = abi.encodeWithSelector(selector, calls);
        (bool aliceSuccess,) = address(aliceAccount).call(callData);
        assertTrue(aliceSuccess);

        // Bob cannot use Alice's account (different addresses)
        (bool bobSuccess,) = address(bobAccount).call(callData);
        assertFalse(bobSuccess);

        // Charlie cannot use Alice's account
        (bool charlieSuccess,) = address(charlieAccount).call(callData);
        assertFalse(charlieSuccess);
    }

    function test_RealWorldScenario() public {
        // Simulate real-world usage where each user has their own account

        // 1. Alice sets up her account with batch calls
        bytes4 selector = BatchCallsHook.batch.selector;
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(sharedBatchHook));

        // 2. Alice performs a complex transaction (approve + transfer)
        Call[] memory aliceCalls = new Call[](2);
        aliceCalls[0] = Call({
            to: address(mockUSDC),
            value: 0,
            data: abi.encodeWithSelector(MockToken.approve.selector, address(0x123), 500e6)
        });
        aliceCalls[1] = Call({
            to: address(mockUSDC),
            value: 0,
            data: abi.encodeWithSelector(MockToken.transfer.selector, address(0x456), 200e6)
        });

        bytes memory aliceCallData = abi.encodeWithSelector(selector, aliceCalls);
        (bool aliceSuccess,) = address(aliceAccount).call(aliceCallData);
        assertTrue(aliceSuccess, "Alice's complex transaction should succeed");

        // 3. Bob sets up his account later with the same hook
        vm.prank(address(bobAccount));
        bobAccount.setHook(selector, address(sharedBatchHook));

        // 4. Bob performs his own transaction
        Call[] memory bobCalls = new Call[](1);
        bobCalls[0] = Call({
            to: address(mockDAI),
            value: 0,
            data: abi.encodeWithSelector(MockToken.transfer.selector, address(0x789), 100e18)
        });

        bytes memory bobCallData = abi.encodeWithSelector(selector, bobCalls);
        (bool bobSuccess,) = address(bobAccount).call(bobCallData);
        assertTrue(bobSuccess, "Bob's transaction should succeed");

        // 5. Each account maintains independent state
        assertEq(aliceAccount.hooks(selector), address(sharedBatchHook));
        assertEq(bobAccount.hooks(selector), address(sharedBatchHook));
        assertEq(charlieAccount.hooks(selector), address(0));
    }

    // New tests added by user

    function test_NoHookRevertsWithNoHookError() public {
        // Test that unregistered selector gives NoHook(selector) error
        bytes4 nonExistentSelector = bytes4(keccak256("nonExistent()"));

        (bool success,) = address(aliceAccount).call(abi.encodeWithSelector(nonExistentSelector));
        assertFalse(success, "Call should fail when no hook registered");
    }

    function test_SetHookOnlySelfGuard() public {
        // External call to setHook should catch AccessDenied(caller)
        bytes4 selector = BatchCallsHook.batch.selector;

        // External call should fail
        vm.expectRevert(abi.encodeWithSelector(Dispatcher7702.AccessDenied.selector, address(this)));
        aliceAccount.setHook(selector, address(sharedBatchHook));

        // Self-call should succeed
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(sharedBatchHook));
        assertEq(aliceAccount.hooks(selector), address(sharedBatchHook));
    }

    function test_SetHookZeroAddressReverts() public {
        // Protection against registering address(0) (HookIsZero)
        bytes4 selector = BatchCallsHook.batch.selector;

        vm.prank(address(aliceAccount));
        vm.expectRevert(Dispatcher7702.HookIsZero.selector);
        aliceAccount.setHook(selector, address(0));
    }

    function test_ClearHookOnlySelfGuard() public {
        // Same guard for clearHook
        bytes4 selector = BatchCallsHook.batch.selector;

        // First set a hook
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(sharedBatchHook));

        // External call to clearHook should fail
        vm.expectRevert(abi.encodeWithSelector(Dispatcher7702.AccessDenied.selector, address(this)));
        aliceAccount.clearHook(selector);

        // Self-call should succeed
        vm.prank(address(aliceAccount));
        aliceAccount.clearHook(selector);
        assertEq(aliceAccount.hooks(selector), address(0));
    }

    function test_RevertBubbling_InsideBatch() public {
        // Inside batch one of the calls fails, and "boom" reason bubbles up
        bytes4 selector = BatchCallsHook.batch.selector;

        // Register hook
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(sharedBatchHook));

        // Create batch with one call that reverts
        Call[] memory calls = new Call[](2);
        calls[0] = Call({
            to: address(mockUSDC),
            value: 0,
            data: abi.encodeWithSelector(MockToken.transfer.selector, address(1), 100e6)
        });
        calls[1] = Call({to: address(reverter), value: 0, data: abi.encodeWithSelector(Reverter.boom.selector)});

        bytes memory callData = abi.encodeWithSelector(selector, calls);
        (bool success,) = address(aliceAccount).call(callData);
        assertFalse(success, "Should revert with boom");
    }

    function test_ReceiveEther_IsolatedPerAccount() public {
        // Accounts independently receive ETH; can forward ether to sink via batch
        bytes4 selector = BatchCallsHook.batch.selector;

        // Register hook
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(sharedBatchHook));

        // Give ETH to Alice's account
        vm.deal(address(aliceAccount), 1 ether);
        assertEq(address(aliceAccount).balance, 1 ether);

        // Alice forwards ETH to sink via batch
        Call[] memory calls = new Call[](1);
        calls[0] = Call({to: address(etherSink), value: 0.5 ether, data: ""});

        bytes memory callData = abi.encodeWithSelector(selector, calls);
        (bool success,) = address(aliceAccount).call{value: 0}(callData);
        assertTrue(success);

        // Check ETH was transferred
        assertEq(address(etherSink).balance, 0.5 ether);
        assertEq(address(aliceAccount).balance, 0.5 ether);

        // Bob's account is independent
        assertEq(address(bobAccount).balance, 0);
    }

    function test_UpgradeHook_PerAccountIndependence() public {
        // Upgrading hook for one account doesn't break config for another
        bytes4 selector = BatchCallsHook.batch.selector;

        // Give Bob some USDC balance
        mockUSDC.setBalance(address(bobAccount), 1000e6);

        // Both accounts register the same hook
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(sharedBatchHook));

        vm.prank(address(bobAccount));
        bobAccount.setHook(selector, address(sharedBatchHook));

        // Deploy new hook
        BatchCallsHook newHook = new BatchCallsHook();

        // Alice upgrades to new hook
        vm.prank(address(aliceAccount));
        aliceAccount.setHook(selector, address(newHook));

        // Bob still has old hook
        assertEq(aliceAccount.hooks(selector), address(newHook));
        assertEq(bobAccount.hooks(selector), address(sharedBatchHook));

        // Both should still work
        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            to: address(mockUSDC),
            value: 0,
            data: abi.encodeWithSelector(MockToken.transfer.selector, address(1), 100e6)
        });

        bytes memory callData = abi.encodeWithSelector(selector, calls);

        (bool aliceSuccess,) = address(aliceAccount).call(callData);
        assertTrue(aliceSuccess, "Alice should work with new hook");

        (bool bobSuccess,) = address(bobAccount).call(callData);
        assertTrue(bobSuccess, "Bob should work with old hook");
    }
}
