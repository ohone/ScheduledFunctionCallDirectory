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

        directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        assertEq(directory.index(), 1);
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

        directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            scheduled,
            address(this),
            bytes32(0x0)
        );

        uint256 functionId = directory.index();

        vm.warp(scheduled - 1);

        vm.expectRevert("Call isn't scheduled yet.");
        directory.PopCall(functionId, recipient);
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithArgs(uint256 scheduled) public {
        AuditableContract target = new AuditableContract(false);

        uint256 methodValue = 1;
        address recipient = address(1);
        uint256 arg1 = 2;
        uint256 arg2 = 3;

        directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        vm.warp(scheduled);
        vm.expectEmit(true, true, true, true);
        emit Called(arg1, arg2);
        directory.PopCall(directory.index(), recipient);
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithValue(uint256 scheduled) public {
        AuditableContract target = new AuditableContract(false);

        uint256 methodValue = 1;
        address recipient = address(1);

        uint256 arg1 = 2;
        uint256 arg2 = 3;

        directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        vm.warp(scheduled);

        directory.PopCall(directory.index(), recipient);

        assertEq(address(target).balance, methodValue);
    }

    function testScheduledCall_CalledSuccessfully_TransfersBountyToCaller(uint256 scheduled) public {
        AuditableContract target = new AuditableContract(false);

        uint256 methodValue = 1;
        uint256 reward = 1;
        address recipient = address(1);

        directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        vm.warp(scheduled);
        directory.PopCall(directory.index(), payable(recipient));

        assertEq(rewardToken.balanceOf(recipient), reward);
    }

    function testScheduledCall_CalledAtScheduledTime_CalledMethodReverts_Reverts() public {
        AuditableContract target = new AuditableContract(true);

        uint256 methodValue = 1;
        address recipient = address(1);
        uint256 scheduled = 1000;

        directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        uint256 functionId = directory.index();
        vm.warp(scheduled);

        vm.expectRevert("Function call reverted.");
        directory.PopCall(functionId, recipient);
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
        directory.scheduleCall{value: methodValue}(
            address(target),
            1,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry,
            address(this),
            bytes32(0x0)
        );

        vm.warp(expiry + 1);

        // must extract call from in-line, otherwise expectRevert
        // operates on .index() not .PopCall()
        uint256 functionIndex = directory.index();

        vm.expectRevert("Call has expired.");
        directory.PopCall(functionIndex, recipient);
    }

    function testScheduledCall_CalledBeforeExpiry_Succeeds() public {
        AuditableContract target = new AuditableContract(false);

        address recipient = address(1);
        uint256 methodValue = 1;
        uint256 currentTimestamp = 10000;
        uint256 expiry = currentTimestamp + 1;
        vm.warp(currentTimestamp);

        directory.scheduleCall{value: methodValue}(
            address(target),
            1,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry,
            address(this),
            bytes32(0x0)
        );

        directory.PopCall(directory.index(), payable(address(recipient)));
    }

    function testPopSameCallTwice_Reverts(uint256 scheduled) public {
        vm.assume(scheduled > 0);

        AuditableContract target = new AuditableContract(false);
        BountyDirectory bountyDirectory = directory.bountyDirectory();
        TestBountyDispenser bountyDispenser = new TestBountyDispenser();
        bytes32 bountyHash = bytes32(0x0);
        bountyDispenser.setBountyCustodianResponse(bountyHash, address(directory));
        bytes32 addressedBountyHash = bountyDispenser.registerBounty(bountyHash, address(bountyDirectory));

        uint256 methodValue = 1;
        address recipient = address(1);

        directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            addressedBountyHash
        );

        vm.warp(scheduled);
        uint256 callToPop = directory.index();

        directory.PopCall(callToPop, address(this));
        
        vm.expectRevert("Call has expired.");
        directory.PopCall(callToPop, recipient);
    }

    function testReentryIntoPopCall_BountyNotResent(uint256 scheduled) public {
        AuditableContract target = new AuditableContract(false);

        uint256 reward = 1;
        uint256 methodValue = 1;
        uint256 arg1 = 3;
        uint256 arg2 = 2;
        address recipient = address(1);

        directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            bytes32(0x0)
        );

        vm.warp(scheduled);
        uint256 callToPop = directory.index();
        bytes memory functionSignature = abi.encodeWithSignature(
            "scheduleCall(address,uint256,address,uint256,address,uint256,bytes,uint256, address)",
            address(target),
            scheduled,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2),
            UINT256_MAX,
            address(this)
        );
        rewardToken.registerPostTokenTransferCallback(address(directory), functionSignature);

        directory.PopCall(callToPop, recipient);
        // assert only one set of reward tokens transferred
        assertEq(rewardToken.balanceOf(recipient), reward);
    }
}
