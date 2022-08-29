// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ScheduledFunctionCallDirectory.sol";
import "./AuditableContract.sol";

contract ScheduledFunctionCallDirectoryTest is Test {
    ScheduledFunctionCallDirectory private directory;

    event Called(uint256 argument1, uint256 argument2);
    event CallScheduled(uint256 timestamp, uint256 expires, uint256 reward, uint256 id, bytes args);

    function setUp() public {
        directory = new ScheduledFunctionCallDirectory();
        vm.warp(0);
    }

    function testSchedulingCall_IncrementsNumber() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        directory.ScheduleCall{value: reward + methodValue}(
            address(0), 100, reward, methodValue, abi.encodeWithSignature("ScheduleCall()", ""), UINT256_MAX
        );
        assertEq(directory.index(), 1);
    }

    function testSchedulingCall_TransfersEther() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        directory.ScheduleCall{value: reward + methodValue}(
            address(0), 100, reward, methodValue, abi.encodeWithSignature("ScheduleCall()", ""), UINT256_MAX
        );

        assertEq(address(directory).balance, reward + methodValue);
    }

    function testSchedulingCall_SendsMoreEtherThanRequired_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        vm.expectRevert("Sent ether doesnt equal required ether.");
        directory.ScheduleCall{value: reward + methodValue + 1}(
            address(0), 100, reward, methodValue, abi.encodeWithSignature("ScheduleCall()", ""), UINT256_MAX
        );
    }

    function testSchedulingCall_SendsLessEtherThanRequired_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        vm.expectRevert("Sent ether doesnt equal required ether.");
        directory.ScheduleCall{value: reward + methodValue - 1}(
            address(0), 100, reward, methodValue, abi.encodeWithSignature("ScheduleCall()", ""), UINT256_MAX
        );
    }

    function testSchedulingCall_EmitsEvent(uint256 expires) public {
        vm.assume(expires > 0);

        uint256 reward = 1;
        uint256 methodValue = 1;

        uint256 timestamp = 100;

        bytes memory args = abi.encodeWithSignature("ScheduleCall()", "");

        vm.expectEmit(true, true, true, true);
        emit CallScheduled(timestamp, expires, reward, directory.index() + 1, args);
        directory.ScheduleCall{value: reward + methodValue}(address(0), timestamp, reward, methodValue, args, expires);
    }

    function testScheduledCall_CalledBeforeScheduledTime_Reverts(uint256 scheduled) public {
        vm.assume(scheduled > 0);
        uint256 reward = 1;
        uint256 methodValue = 1;

        directory.ScheduleCall{value: reward + methodValue}(
            address(1), scheduled, reward, methodValue, abi.encodeWithSignature("ScheduleCall()", ""), UINT256_MAX
        );

        uint256 functionId = directory.index();

        vm.warp(scheduled - 1);

        vm.expectRevert("Call isn't scheduled yet.");
        directory.PopCall(functionId, payable(address(0)));
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithArgs(uint256 scheduled) public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);
        uint256 arg1 = 2;
        uint256 arg2 = 3;

        directory.ScheduleCall{value: reward + methodValue}(
            address(target),
            scheduled,
            reward,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2),
            UINT256_MAX
        );

        vm.warp(scheduled);
        vm.expectEmit(true, true, true, true);
        emit Called(arg1, arg2);
        directory.PopCall(directory.index(), payable(address(0)));
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithValue(uint256 scheduled) public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);
        uint256 arg1 = 2;
        uint256 arg2 = 3;

        directory.ScheduleCall{value: reward + methodValue}(
            address(target),
            scheduled,
            reward,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2),
            UINT256_MAX
        );

        vm.warp(scheduled);

        directory.PopCall(directory.index(), payable(address(0)));

        assertEq(address(target).balance, methodValue);
    }

    function testScheduledCall_CalledSuccessfully_RewardsCallerValue(uint256 scheduled) public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        address recipient = address(0);

        directory.ScheduleCall{value: reward + methodValue}(
            address(target),
            scheduled,
            reward,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX
        );

        vm.warp(scheduled);
        directory.PopCall(directory.index(), payable(recipient));

        assertEq(recipient.balance, reward);
    }

    function testScheduledCall_CalledAtScheduledTime_CalledMethodReverts_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(true);

        directory.ScheduleCall{value: reward + methodValue}(
            address(target),
            block.timestamp,
            reward,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX
        );

        uint256 functionId = directory.index();

        vm.expectRevert("Function call reverted.");
        directory.PopCall(functionId, payable(address(0)));
    }

    function testSchedulingCall_ExpiryInThePast_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        uint256 currentTimestamp = 10000;
        vm.warp(currentTimestamp);

        vm.expectRevert("call expiry timestamp cannot be in the past");
        directory.ScheduleCall{value: reward + methodValue}(
            address(target),
            1,
            reward,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            currentTimestamp - 1
        );
    }

    function testScheduledCall_CalledPassedExpiry_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        uint256 currentTimestamp = 10000;
        uint256 expiry = currentTimestamp + 1;
        vm.warp(currentTimestamp);

        directory.ScheduleCall{value: reward + methodValue}(
            address(target),
            1,
            reward,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry
        );

        vm.warp(expiry + 1);

        // must extract call from in-line, otherwise expectRevert
        // operates on .index() not .PopCall()
        uint256 functionIndex = directory.index();

        vm.expectRevert("Call has expired.");
        directory.PopCall(functionIndex, payable(address(0)));
    }

    function testScheduledCall_CalledBeforeExpiry_Succeeds() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        address recipient = address(0);

        uint256 currentTimestamp = 10000;
        uint256 expiry = currentTimestamp + 1;
        vm.warp(currentTimestamp);

        directory.ScheduleCall{value: reward + methodValue}(
            address(target),
            1,
            reward,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry
        );

        directory.PopCall(directory.index(), payable(address(recipient)));
    }
}
