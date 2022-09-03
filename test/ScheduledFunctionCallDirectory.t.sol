// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ScheduledFunctionCallDirectory.sol";
import "./AuditableContract.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "./TestERC20.sol";

contract ScheduledFunctionCallDirectoryTest is Test {
    ScheduledFunctionCallDirectory private directory;
    TestERC20 private rewardToken;

    event Called(uint256 argument1, uint256 argument2);
    event CallScheduled(
        uint256 indexed timestamp, uint256 indexed expires, address rewardToken, uint256 rewardAmount, uint256 id, bytes args
    );

    function setUp() public {
        directory = new ScheduledFunctionCallDirectory();
        rewardToken = new TestERC20("test", "TEST");
        rewardToken.mint(address(this), UINT256_MAX);
        rewardToken.approve(address(directory), UINT256_MAX);
        vm.warp(0);
    }

    function testSchedulingCall_IncrementsNumber() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this)
        );
        assertEq(directory.index(), 1);
    }

    function testSchedulingCall_TransfersEther() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this)
        );

        assertEq(address(directory).balance, methodValue);
    }

    function testSchedulingCall_TransfersERC20() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this)
        );

        assertEq(rewardToken.balanceOf(address(directory)), reward);
    }

    function testSchedulingCall_SendsMoreEtherThanRequired_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        vm.expectRevert("Sent ether doesnt equal required ether.");
        directory.scheduleCall{value: methodValue + 1}(
            address(0),
            100,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this)
        );
    }

    function testSchedulingCall_SendsLessEtherThanRequired_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        vm.expectRevert("Sent ether doesnt equal required ether.");
        directory.scheduleCall{value: methodValue - 1}(
            address(0),
            100,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this)
        );
    }

    function testSchedulingCall_EmitsEvent(uint256 expires) public {
        vm.assume(expires > 0);

        uint256 reward = 1;
        uint256 methodValue = 1;

        uint256 timestamp = 100;

        bytes memory args = abi.encodeWithSignature("ScheduleCall()", "");

        vm.expectEmit(true, true, true, true);
        emit CallScheduled(timestamp, expires, address(rewardToken), reward, directory.index() + 1, args);
        directory.scheduleCall{value: methodValue}(
            address(0), timestamp, address(rewardToken), reward, address(this), methodValue, args, expires, address(this)
        );
    }

    function testScheduledCall_CalledBeforeScheduledTime_Reverts(uint256 scheduled) public {
        vm.assume(scheduled > 0);
        uint256 reward = 1;
        uint256 methodValue = 1;

        address recipient = address(1);

        directory.scheduleCall{value: methodValue}(
            address(1),
            scheduled,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this)
        );

        uint256 functionId = directory.index();

        vm.warp(scheduled - 1);

        vm.expectRevert("Call isn't scheduled yet.");
        directory.PopCall(functionId, recipient);
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithArgs(uint256 scheduled) public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        address recipient = address(1);

        uint256 arg1 = 2;
        uint256 arg2 = 3;

        directory.scheduleCall{value: methodValue}(
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

        vm.warp(scheduled);
        vm.expectEmit(true, true, true, true);
        emit Called(arg1, arg2);
        directory.PopCall(directory.index(), recipient);
    }

    function testScheduledCall_CalledAtScheduledTime_CallsMethodWithValue(uint256 scheduled) public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        address recipient = address(1);

        uint256 arg1 = 2;
        uint256 arg2 = 3;

        directory.scheduleCall{value: methodValue}(
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

        vm.warp(scheduled);

        directory.PopCall(directory.index(), recipient);

        assertEq(address(target).balance, methodValue);
    }

    function testScheduledCall_CalledSuccessfully_RewardsCallerValue(uint256 scheduled) public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        address recipient = address(1);

        directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this)
        );

        vm.warp(scheduled);
        directory.PopCall(directory.index(), payable(recipient));

        assertEq(rewardToken.balanceOf(recipient), reward);
    }

    function testScheduledCall_CalledAtScheduledTime_CalledMethodReverts_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(true);

        address recipient = address(1);

        directory.scheduleCall{value: methodValue}(
            address(target),
            block.timestamp,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this)
        );

        uint256 functionId = directory.index();

        vm.expectRevert("Function call reverted.");
        directory.PopCall(functionId, recipient);
    }

    function testSchedulingCall_ExpiryInThePast_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        uint256 currentTimestamp = 10000;
        vm.warp(currentTimestamp);

        vm.expectRevert("call expiry timestamp cannot be in the past");
        directory.scheduleCall{value: methodValue}(
            address(target),
            1,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            currentTimestamp - 1,
            address(this)
        );
    }

    function testScheduledCall_CalledPassedExpiry_Reverts() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        address recipient = address(1);

        uint256 currentTimestamp = 10000;
        uint256 expiry = currentTimestamp + 1;
        vm.warp(currentTimestamp);

        directory.scheduleCall{value: methodValue}(
            address(target),
            1,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry,
            address(this)
        );

        vm.warp(expiry + 1);

        // must extract call from in-line, otherwise expectRevert
        // operates on .index() not .PopCall()
        uint256 functionIndex = directory.index();

        vm.expectRevert("Call has expired.");
        directory.PopCall(functionIndex, recipient);
    }

    function testScheduledCall_CalledBeforeExpiry_Succeeds() public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        address recipient = address(1);

        uint256 currentTimestamp = 10000;
        uint256 expiry = currentTimestamp + 1;
        vm.warp(currentTimestamp);

        directory.scheduleCall{value: methodValue}(
            address(target),
            1,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry,
            address(this)
        );

        directory.PopCall(directory.index(), payable(address(recipient)));
    }

    function testPopSameCallTwice_Reverts(uint256 scheduled) public {
        uint256 reward = 1;
        uint256 methodValue = 1;

        AuditableContract target = new AuditableContract(false);

        address recipient = address(1);

        directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            address(rewardToken),
            reward,
            address(this),
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 2, 3),
            UINT256_MAX,
            address(this)
        );

        vm.warp(scheduled);
        uint256 callToPop = directory.index();

        directory.PopCall(callToPop, recipient);

        vm.expectRevert("Call has expired.");
        directory.PopCall(callToPop, recipient);
    }

    function testReentryIntoPopCall_TokensNotResent(uint256 scheduled) public {
        uint256 reward = 1;
        uint256 methodValue = 1;
        uint256 arg1 = 3;
        uint256 arg2 = 2;
        AuditableContract target = new AuditableContract(false);

        address recipient = address(1);

        directory.scheduleCall{value: methodValue}(
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

        vm.expectEmit(true, true, true, true);
        emit Called(arg1, arg2);
        directory.PopCall(callToPop, recipient);
        // assert only one set of reward tokens transferred 
        assertEq(rewardToken.balanceOf(recipient), reward);
    }
}
