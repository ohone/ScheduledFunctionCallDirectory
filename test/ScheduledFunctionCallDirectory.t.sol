// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ScheduledFunctionCallDirectory.sol";
import "./AuditableContract.sol";

contract ScheduledFunctionCallDirectoryTest is Test {

    ScheduledFunctionCallDirectory private directory;

    event Called(uint256 argument1, uint256 argument2);
    event CallScheduled(uint256 timestamp, uint256 reward, uint256 id, bytes args);

    function setUp() public {
        directory = new ScheduledFunctionCallDirectory();
    }

    function testSchedulingCall_IncrementsNumber() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        directory.ScheduleCall{value:reward + methodValue}(address(0), 100, reward, methodValue, abi.encodeWithSignature("ScheduleCall()", ""));

        assertEq(directory.number(), 1);
    }

    function testSchedulingCall_TransfersEther() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        directory.ScheduleCall{value:reward + methodValue}(address(0), 100, reward, methodValue, abi.encodeWithSignature("ScheduleCall()", ""));

        assertEq(address(directory).balance, reward + methodValue);
    }

    function testSchedulingCall_SendsMoreEtherThanRequired_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        vm.expectRevert("Sent ether doesnt equal required ether.");
        directory.ScheduleCall{value:reward + methodValue + 1}(address(0), 100, reward, methodValue, abi.encodeWithSignature("ScheduleCall()", ""));
    }

    function testSchedulingCall_SendsLessEtherThanRequired_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        vm.expectRevert("Sent ether doesnt equal required ether.");
        directory.ScheduleCall{value:reward + methodValue - 1}(address(0), 100, reward, methodValue, abi.encodeWithSignature("ScheduleCall()", ""));
    }

    function testSchedulingCall_EmitsEvent() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        uint256 timestamp = 100;

        bytes memory args = abi.encodeWithSignature("ScheduleCall()", "");

        vm.expectEmit(true, true, true, true);
        emit CallScheduled(timestamp, reward, directory.number() + 1, args);
        directory.ScheduleCall{value:reward + methodValue}(address(0), timestamp, reward, methodValue, args);
    }

    function testScheduledCall_CalledBeforeScheduledTime_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        directory.ScheduleCall{value:reward + methodValue}(
            address(0), 
            block.timestamp + 2, 
            reward, 
            methodValue, 
            abi.encodeWithSignature("ScheduleCall()", ""));

        vm.expectRevert("Call isn't scheduled yet.");
        directory.PopCall(directory.number(), payable(address(0)));
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithArgs() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);
        uint256 arg1 = 2;
        uint256 arg2 = 3;

        directory.ScheduleCall{value:reward + methodValue}(
            address(target), 
            block.timestamp, 
            reward, 
            methodValue, 
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2));

        vm.expectEmit(true, true, true, true);
        emit Called(arg1, arg2);
        directory.PopCall(directory.number(), payable(address(0)));
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithValue() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);
        uint256 arg1 = 2;
        uint256 arg2 = 3;

        uint256 schedule = 100;

        directory.ScheduleCall{value:reward + methodValue}(
            address(target), 
            schedule, 
            reward, 
            methodValue, 
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2));

        vm.warp(schedule);
        directory.PopCall(directory.number(), payable(address(0)));

        assertEq(address(target).balance, methodValue);
    }

    function testScheduledCall_CalledSuccessfully_RewardsCallerValue() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        uint256 scheduled = 100;
        AuditableContract target = new AuditableContract(false);

        address recipient = address(0);

        directory.ScheduleCall{value:reward + methodValue}(
            address(target), 
            scheduled, 
            reward, 
            methodValue, 
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1,2));

        vm.warp(scheduled);
        directory.PopCall(directory.number(), payable(recipient));

        assertEq(recipient.balance, reward);
    }

    function testScheduledCall_CalledAtScheduledTime_CalledMethodReverts_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        uint256 scheduled = 100;
        AuditableContract target = new AuditableContract(true);

        directory.ScheduleCall{value:reward + methodValue}(
            address(target), 
            scheduled, 
            reward, 
            methodValue, 
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1,2));

        vm.expectRevert();
        directory.PopCall(directory.number(), payable(address(0)));
    }
}
