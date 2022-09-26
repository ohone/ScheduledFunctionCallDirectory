// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ScheduledFunctionCallDirectory.sol";
import "./utils/AuditableContract.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "./utils/TestBountyAdapter.sol";
import "openzeppelin-contracts/token/ERC721/utils/ERC721Holder.sol";
import "./utils/TestERC721.sol";

contract ScheduledFunctionCallDirectoryTest is Test, ERC721Holder {
    ScheduledFunctionCallDirectory private directory;
    address erc721reciever;
    TestERC721 bountyContract;

    event Called(uint256 argument1, uint256 argument2);
    event CallScheduled(
        uint256 indexed timestamp,
        uint256 indexed expires,
        uint256 id,
        bytes args,
        address bountyAddress,
        uint256 bountId
    );

    function setUp() public {
        erc721reciever = address(new ERC721Holder());
        directory = new ScheduledFunctionCallDirectory();
        vm.warp(0);
        bountyContract = new TestERC721("a","a");
    }

    function testSchedulingCall_IncrementsNumber() public {
        uint256 methodValue = 1;
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);
        uint256 firstCall = directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
        );

        uint256 secondBountyId = uint256(2);
        bountyContract.mint(address(this), secondBountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        uint256 secondCall = directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bountyAddress,
            secondBountyId
        );

        assertEq(firstCall + 1, secondCall);
    }

    function testSchedulingCall_TransfersEther() public {
        uint256 methodValue = 1;
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);
        directory.scheduleCall{value: methodValue}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
        );

        assertEq(address(directory).balance, methodValue);
    }

    function testSchedulingCall_SendsMoreEtherThanRequired_Reverts() public {
        uint256 methodValue = 1;
        address bountyAddress = address(1337);
        uint256 bountyId = 1337;
        vm.expectRevert("Sent ether doesnt equal required ether");
        directory.scheduleCall{value: methodValue + 1}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
        );
    }

    function testSchedulingCall_SendsLessEtherThanRequired_Reverts() public {
        uint256 methodValue = 1;
        address bountyAddress = address(1337);
        uint256 bountyId = 1337;
        vm.expectRevert("Sent ether doesnt equal required ether");
        directory.scheduleCall{value: methodValue - 1}(
            address(0),
            100,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
        );
    }

    function testSchedulingCall_EmitsEvent(uint256 expires) public {
        vm.assume(expires > 0);
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);
        uint256 methodValue = 1;
        uint256 timestamp = 100;
        bytes memory args = abi.encodeWithSignature("ScheduleCall()", "");

        vm.expectEmit(true, true, true, true);
        emit CallScheduled(timestamp, expires, 1, args, bountyAddress, bountyId);
        directory.scheduleCall{value: methodValue}(
            address(0), timestamp, methodValue, args, expires, address(this), bountyAddress, bountyId
        );
    }

    function testScheduledCall_CalledBeforeScheduledTime_Reverts(uint256 scheduled) public {
        vm.assume(scheduled > 0);

        uint256 methodValue = 1;
        address recipient = address(1);
        AuditableContract target = new AuditableContract(false);
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);

        uint256 functionId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("ScheduleCall()", ""),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
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
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);

        uint256 scheduledCallId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
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
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);

        uint256 scheduledCallId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", arg1, arg2),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
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
        address recipient = address(1);
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);

        uint256 scheduledFunctionId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
        );

        vm.warp(scheduled);
        directory.PopCall(scheduledFunctionId, payable(recipient));

        // TODO: tighter assertion
        assertEq(recipient, bountyContract.ownerOf(bountyId));
    }

    function testScheduledCall_CalledAtScheduledTime_CalledMethodReverts_Reverts() public {
        AuditableContract target = new AuditableContract(true);

        uint256 methodValue = 1;
        uint256 scheduled = 1000;
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);
        uint256 scheduledCallId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
        );

        vm.warp(scheduled);

        vm.expectRevert("Function call reverted.");
        directory.PopCall(scheduledCallId, erc721reciever);
    }

    function testSchedulingCall_ExpiryInThePast_Reverts() public {
        AuditableContract target = new AuditableContract(false);

        uint256 methodValue = 1;
        uint256 currentTimestamp = 10000;
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);
        vm.warp(currentTimestamp);

        vm.expectRevert("expiry cannot be in the past");
        directory.scheduleCall{value: methodValue}(
            address(target),
            100,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            currentTimestamp - 1,
            address(this),
            bountyAddress,
            bountyId
        );
    }

    function testScheduledCall_CalledPassedExpiry_Reverts() public {
        AuditableContract target = new AuditableContract(false);

        uint256 methodValue = 1;
        address recipient = address(1);
        uint256 currentTimestamp = 10000;
        uint256 expiry = currentTimestamp + 1;
        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);
        vm.warp(currentTimestamp);

        uint256 scheduledFunctionId = directory.scheduleCall{value: methodValue}(
            address(target),
            1,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry,
            address(this),
            bountyAddress,
            bountyId
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

        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);
        address bountyAddress = address(bountyContract);

        vm.warp(currentTimestamp);

        uint256 scheduledFunctionId = directory.scheduleCall{value: methodValue}(
            address(target),
            1,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            expiry,
            address(this),
            bountyAddress,
            bountyId
        );

        directory.PopCall(scheduledFunctionId, payable(address(recipient)));
    }

    function testPopSameCallTwice_Reverts(uint256 scheduled) public {
        vm.assume(scheduled > 0);

        AuditableContract target = new AuditableContract(false);

        uint256 bountyId = uint256(1);
        bountyContract.mint(address(this), bountyId);
        bountyContract.setApprovalForAll(address(directory), true);

        uint256 methodValue = 1;
        address bountyAddress = address(bountyContract);
        uint256 scheduledFunctionId = directory.scheduleCall{value: methodValue}(
            address(target),
            scheduled,
            methodValue,
            abi.encodeWithSignature("payableFunction(uint256,uint256)", 1, 2),
            UINT256_MAX,
            address(this),
            bountyAddress,
            bountyId
        );

        vm.warp(scheduled);

        directory.PopCall(scheduledFunctionId, erc721reciever);

        vm.expectRevert("Call has expired.");
        directory.PopCall(scheduledFunctionId, erc721reciever);
    }
}
