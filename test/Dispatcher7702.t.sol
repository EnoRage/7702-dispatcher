// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Dispatcher7702} from "../src/Dispatcher7702.sol";
import {BatchCallsHook} from "../src/BatchCallsHook.sol";
import {Call} from "../src/Types.sol";

// Mock contract for testing
contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function revertFunction() external pure {
        revert("Test revert");
    }
}

contract Dispatcher7702Test is Test {
    Dispatcher7702 public dispatcher;
    BatchCallsHook public batchHook;
    MockTarget public mockTarget;

    function setUp() public {
        dispatcher = new Dispatcher7702();
        batchHook = new BatchCallsHook();
        mockTarget = new MockTarget();
    }

    function test_SetAndClearHook() public {
        bytes4 selector = BatchCallsHook.batch.selector;

        // Hook is not set initially
        assertEq(dispatcher.hooks(selector), address(0));

        // Set hook through self-call
        vm.prank(address(dispatcher));
        dispatcher.setHook(selector, address(batchHook));

        // Check that hook is set
        assertEq(dispatcher.hooks(selector), address(batchHook));

        // Clear hook
        vm.prank(address(dispatcher));
        dispatcher.clearHook(selector);

        // Check that hook is cleared
        assertEq(dispatcher.hooks(selector), address(0));
    }

    function test_OnlySelfCanSetHook() public {
        bytes4 selector = BatchCallsHook.batch.selector;

        // Attempt to set hook from another address should fail
        vm.expectRevert(abi.encodeWithSelector(Dispatcher7702.AccessDenied.selector, address(this)));
        dispatcher.setHook(selector, address(batchHook));
    }

    function test_CannotSetZeroHook() public {
        bytes4 selector = BatchCallsHook.batch.selector;

        vm.prank(address(dispatcher));
        vm.expectRevert(Dispatcher7702.HookIsZero.selector);
        dispatcher.setHook(selector, address(0));
    }

    function test_CannotSetRecursiveHook() public {
        bytes4 selector = BatchCallsHook.batch.selector;

        vm.prank(address(dispatcher));
        vm.expectRevert(Dispatcher7702.RecursiveHook.selector);
        dispatcher.setHook(selector, address(dispatcher));
    }

    function test_BatchCallsHook() public {
        bytes4 selector = BatchCallsHook.batch.selector;

        // Set hook
        vm.prank(address(dispatcher));
        dispatcher.setHook(selector, address(batchHook));

        // Create array of calls
        Call[] memory calls = new Call[](2);
        calls[0] =
            Call({to: address(mockTarget), value: 0, data: abi.encodeWithSelector(MockTarget.setValue.selector, 42)});
        calls[1] = Call({to: address(mockTarget), value: 0, data: abi.encodeWithSelector(MockTarget.getValue.selector)});

        // Execute batch call through dispatcher fallback
        bytes memory callData = abi.encodeWithSelector(BatchCallsHook.batch.selector, calls);
        (bool success, bytes memory results) = address(dispatcher).call(callData);
        assertTrue(success);

        // Decode results
        bytes[] memory decodedResults = abi.decode(results, (bytes[]));

        // Check results
        assertEq(mockTarget.value(), 42);
        assertEq(abi.decode(decodedResults[1], (uint256)), 42);
    }

    function test_BatchCallsWithRevert() public {
        bytes4 selector = BatchCallsHook.batch.selector;

        // Set hook
        vm.prank(address(dispatcher));
        dispatcher.setHook(selector, address(batchHook));

        // Create array of calls with a function that reverts
        Call[] memory calls = new Call[](1);
        calls[0] =
            Call({to: address(mockTarget), value: 0, data: abi.encodeWithSelector(MockTarget.revertFunction.selector)});

        // Execution should fail
        bytes memory callData = abi.encodeWithSelector(BatchCallsHook.batch.selector, calls);
        vm.expectRevert("Test revert");
        address(dispatcher).call(callData);
    }

    function test_NoHookRegistered() public {
        // Attempt to call non-existent hook should fail
        bytes4 nonExistentSelector = bytes4(keccak256("nonExistent()"));

        // Send any data to dispatcher
        (bool success,) = address(dispatcher).call(abi.encodeWithSelector(nonExistentSelector));
        assertFalse(success);
    }

    function test_ReceiveEther() public {
        // Check that dispatcher can receive ETH
        uint256 balanceBefore = address(dispatcher).balance;

        payable(address(dispatcher)).transfer(1 ether);

        assertEq(address(dispatcher).balance, balanceBefore + 1 ether);
    }
    /// @notice End‑to‑end scenario that illustrates a typical user‑flow:
    ///  1. Wallet without hooks – call fails.
    ///  2. Account contract registers BatchCallsHook.
    ///  3. User makes batch transaction through fallback.
    ///  4. User sends ETH to wallet.
    ///  5. Hook is removed – subsequent calls fail again.

    function test_UserFlowDemonstration() public {
        // Setup
        bytes4 selector = BatchCallsHook.batch.selector;

        // 0. Call without registered hook should fail
        (bool okBefore,) = address(dispatcher).call(abi.encodeWithSelector(selector, new Call[](0)));
        assertFalse(okBefore, "call should fail when no hook registered");

        // 1. "Owner" (account itself) registers BatchCallsHook
        vm.prank(address(dispatcher));
        dispatcher.setHook(selector, address(batchHook));
        assertEq(dispatcher.hooks(selector), address(batchHook));

        // 2. Batch call: setValue(100) → getValue()
        Call[] memory calls = new Call[](2);
        calls[0] =
            Call({to: address(mockTarget), value: 0, data: abi.encodeWithSelector(MockTarget.setValue.selector, 100)});
        calls[1] = Call({to: address(mockTarget), value: 0, data: abi.encodeWithSelector(MockTarget.getValue.selector)});

        bytes memory calldataBatch = abi.encodeWithSelector(selector, calls);
        (bool okBatch, bytes memory ret) = address(dispatcher).call(calldataBatch);
        assertTrue(okBatch, "batch call via hook failed");

        // Decode results and verify
        bytes[] memory decoded = abi.decode(ret, (bytes[]));
        assertEq(abi.decode(decoded[1], (uint256)), 100);
        assertEq(mockTarget.value(), 100);

        // 3. Send 0.5 ETH to wallet
        vm.deal(address(this), 1 ether);
        uint256 balanceBefore = address(dispatcher).balance;
        payable(address(dispatcher)).transfer(0.5 ether);
        assertEq(address(dispatcher).balance, balanceBefore + 0.5 ether);

        // 4. Remove hook
        vm.prank(address(dispatcher));
        dispatcher.clearHook(selector);
        assertEq(dispatcher.hooks(selector), address(0));

        // 5. Subsequent call fails again
        (bool okAfter,) = address(dispatcher).call(calldataBatch);
        assertFalse(okAfter, "call should fail after hook removed");
    }
}
