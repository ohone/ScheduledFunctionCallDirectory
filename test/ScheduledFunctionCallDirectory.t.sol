// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ScheduledFunctionCallDirectory.sol";
import "./utils/AuditableContract.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "./utils/TestERC20.sol";
import "./utils/TestBountyDispenser.sol";

contract ScheduledFunctionCallDirectoryTest is Test {
    ScheduledFunctionCallDirectory private directory;
    TestERC20 private rewardToken;

    event Called(uint256 argument1, uint256 argument2);
    event CallScheduled(uint256 indexed timestamp, uint256 indexed expires, uint256 id, bytes args, bytes32 bounty);

    function setUp() public {
        directory = new ScheduledFunctionCallDirectory();
        rewardToken = new TestERC20("test", "TEST");
        rewardToken.mint(address(this), UINT256_MAX);
        rewardToken.approve(address(directory), UINT256_MAX);
        vm.warp(0);
    }

    function testSchedulingCall_IncrementsNumber() public {
        uint256 methodValue = 1;

        uint256 firstCall = directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        uint256 secondCall = directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        assertEq(firstCall + 1, secondCall);
    }

    function testSchedulingCall_TransfersEther() public {
        uint256 methodValue = 1;

        directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        assertEq(address(directory).balance, methodValue);
    }

    function testSchedulingCall_SendsMoreEtherThanRequired_Reverts() public {
        uint256 methodValue = 1;

        vm.expectRevert("Sent ether doesnt equal required ether.");
        directory.scheduleCall{value: methodValue + 1}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );
    }

    function testSchedulingCall_SendsLessEtherThanRequired_Reverts() public {
        uint256 methodValue = 1;

        vm.expectRevert("Sent ether doesnt equal required ether.");
        directory.scheduleCall{value: methodValue - 1}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );
    }

    function testSchedulingCall_EmitsEvent(uint256 expires) public {
        vm.assume(expires > 0);

        uint256 methodValue = 1;
        uint256 timestamp = 100;
        bytes32 bounty = bytes32(0x0);
        bytes memory args = abi.encodeWithSignature("ScheduleCall()", "");

        vm.expectEmit(true, true, true, true);
        emit CallScheduled(timestamp, expires, 1, args, bounty);
        directory.scheduleCall{value: methodValue}(
            address(0), timestamp, methodValue, args, expires, address(this), bounty
        );
    }

    function testScheduledCall_CalledBeforeScheduledTime_Reverts(uint256 scheduled) public {
        vm.assume(scheduled > 0);

        uint256 methodValue = 1;
        address recipient = address(1);

        AuditableContract target = new AuditableContract(false);
        (TestBountyDispenser bountyDispenser, bytes32 bountyHash, bytes32 addressedBountyHash) =
            setupMockBounty(directory.bountyDirectory(), address(directory));

        uint256 functionId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            addressedBountyHash
        );

        vm.warp(scheduled - 1);

        vm.expectRevert("Call isn't scheduled yet.");
        directory.PopCall(functionId, recipient);
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithArgs(uint256 scheduled) public {
        vm.assume(scheduled > 0);

        uint256 methodValue = 1;
        address recipient = address(1);
        uint256 arg1 = 2;
        uint256 arg2 = 3;

        AuditableContract target = new AuditableContract(false);
        (TestBountyDispenser bountyDispenser, bytes32 bountyHash, bytes32 addressedBountyHash) =
            setupMockBounty(directory.bountyDirectory(), address(directory));

        uint256 scheduledCallId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2),
            UINT256_MAX,
            address(this),
            addressedBountyHash
        );

        vm.warp(scheduled);
        vm.expectEmit(true, true, true, true);
        emit Called(arg1, arg2);
        directory.PopCall(scheduledCallId, recipient);
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithValue(uint256 scheduled) public {
        vm.assume(scheduled > 0);

        uint256 methodValue = 1;
        address recipient = address(1);
        uint256 arg1 = 2;
        uint256 arg2 = 3;

        AuditableContract target = new AuditableContract(false);

        (TestBountyDispenser bountyDispenser, bytes32 bountyHash, bytes32 addressedBountyHash) =
            setupMockBounty(directory.bountyDirectory(), address(directory));

        uint256 scheduledCallId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2),
            UINT256_MAX,
            address(this),
            addressedBountyHash
        );

        vm.warp(scheduled);
        vm.expectEmit(true, true, true, true);

        emit Called(arg1, arg2);
        directory.PopCall(scheduledCallId, recipient);
        assertEq(address(target).balance, methodValue);
    }

    function testScheduledCall_CalledSuccessfully_TransfersBountyToCaller(uint256 scheduled) public {
        AuditableContract target = new AuditableContract(false);

        uint256 methodValue = 1;
        uint256 reward = 1;
        address recipient = address(1);

        (TestBountyDispenser bountyDispenser, bytes32 bountyHash, bytes32 addressedBountyHash) =
            setupMockBounty(directory.bountyDirectory(), address(directory));

        uint256 scheduledFunctionId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            addressedBountyHash
        );

        vm.warp(scheduled);
        directory.PopCall(scheduledFunctionId, payable(recipient));

        // TODO: tighter assertion
        bountyDispenser.assertCalled(bytes4(keccak256(bytes("dispenseBountyTo(uint256,address)"))));
    }

    function testScheduledCall_CalledAtScheduledTime_CalledMethodReverts_Reverts() public {
        AuditableContract target = new AuditableContract(true);

        uint256 methodValue = 1;
        address recipient = address(1);
        uint256 scheduled = 1000;

        uint256 scheduledCallId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        vm.warp(scheduled);

        vm.expectRevert("Function call reverted.");
        directory.PopCall(scheduledCallId, recipient);
    }

    function testSchedulingCall_ExpiryInThePast_Reverts() public {
        AuditableContract target = new AuditableContract(false);

        uint256 methodValue = 1;
        uint256 currentTimestamp = 10000;

        vm.warp(currentTimestamp);

        vm.expectRevert("call expiry timestamp cannot be in the past");
        directory.scheduleCall{value: methodValue}(
            address(target),
            100,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            currentTimestamp - 1,
            address(this),
            bytes32(0x0)
        );
    }

    function testScheduledCall_CalledPassedExpiry_Reverts() public {
        AuditableContract target = new AuditableContract(false);

        uint256 methodValue = 1;
        address recipient = address(1);
        uint256 currentTimestamp = 10000;
        uint256 expiry = currentTimestamp + 1;

        vm.warp(currentTimestamp);
        uint256 scheduledFunctionId = directory.scheduleCall{value: methodValue}(
            address(target),
            1,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry,
            address(this),
            bytes32(0x0)
        );

        vm.warp(expiry + 1);

        vm.expectRevert("Call has expired.");
        directory.PopCall(scheduledFunctionId, recipient);
    }

    function testScheduledCall_CalledBeforeExpiry_Succeeds() public {
        address recipient = address(1);
        uint256 methodValue = 1;
        uint256 currentTimestamp = 10000;
        uint256 expiry = currentTimestamp + 1;

        AuditableContract target = new AuditableContract(false);

        (TestBountyDispenser bountyDispenser, bytes32 bountyHash, bytes32 addressedBountyHash) =
            setupMockBounty(directory.bountyDirectory(), address(directory));

        vm.warp(currentTimestamp);

        uint256 scheduledFunctionId = directory.scheduleCall{value: methodValue}(
            address(target),
            1,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry,
            address(this),
            addressedBountyHash
        );

        directory.PopCall(scheduledFunctionId, payable(address(recipient)));
    }

    function testPopSameCallTwice_Reverts(uint256 scheduled) public {
        vm.assume(scheduled > 0);

        AuditableContract target = new AuditableContract(false);

        (TestBountyDispenser bountyDispenser, bytes32 bountyHash, bytes32 addressedBountyHash) =
            setupMockBounty(directory.bountyDirectory(), address(directory));

        uint256 methodValue = 1;
        address recipient = address(1);

        uint256 scheduledFunctionId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            addressedBountyHash
        );

        vm.warp(scheduled);

        directory.PopCall(scheduledFunctionId, address(this));

        vm.expectRevert("Call has expired.");
        directory.PopCall(scheduledFunctionId, recipient);
    }

    function testReentryIntoPopCall_BountyNotResent(uint256 scheduled) public {
        vm.assume(scheduled > 0);

        // setup bounty mocks
        AuditableContract target = new AuditableContract(false);
        (TestBountyDispenser bountyDispenser, bytes32 bountyHash, bytes32 addressedBountyHash) =
            setupMockBounty(directory.bountyDirectory(), address(directory));

        // schedule call with bounty
        uint256 methodValue = 1;
        uint256 scheduledFunctionId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            addressedBountyHash
        );

        // warp to call scheduled
        vm.warp(scheduled);

        address recipient = address(103);

        // setup a reentrant callback from bounty dispense
        bytes memory reentryCallback =
            abi.encodeWithSignature("popCall(uint256,address)", scheduledFunctionId, recipient);
        bytes4 dispenseBountySignature = bytes4(keccak256(bytes("dispenseBountyTo(bytes32,address)")));
        rewardToken.registerPostTokenTransferCallback(address(directory), reentryCallback);
        bountyDispenser.registerCallback(dispenseBountySignature, address(directory), reentryCallback);

        directory.PopCall(scheduledFunctionId, recipient);

        // assert bounty dispense only called once
        TestBountyDispenser.callRecord[] memory records = bountyDispenser.getCallRecords(dispenseBountySignature);
        assertEq(1, records.length);
    }

    function setupMockBounty(BountyDirectory bountyDirectory, address custodian)
        private
        returns (TestBountyDispenser bountyDispenser, bytes32 bountyhash, bytes32 addressedBountyHash)
    {
        TestBountyDispenser bountyDispenser = new TestBountyDispenser();
        bytes32 bountyHash = bytes32(0x0);
        bountyDispenser.setBountyCustodianResponse(bountyHash, address(custodian));
        bytes32 addressedBountyHash = bountyDispenser.registerBounty(bountyHash, address(bountyDirectory));
        return (bountyDispenser, bountyHash, addressedBountyHash);
    }
}
