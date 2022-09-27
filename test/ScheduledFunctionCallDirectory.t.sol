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
    address private erc721reciever;
    TestERC721 private bountyContract;

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

    function testScheduleCall_IncrementsNumber() public {
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

    function testScheduleCall_TransfersEther() public {
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

    function testScheduleCall_SendsMoreEtherThanRequired_Reverts() public {
        uint256 methodValue = 1;
        address bountyAddress = address(1337);
        uint256 bountyId = 1337;
        vm.expectRevert("sent ether != required ether");
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

    function testScheduleCall_SendsLessEtherThanRequired_Reverts() public {
        uint256 methodValue = 1;
        address bountyAddress = address(1337);
        uint256 bountyId = 1337;
        vm.expectRevert("sent ether != required ether");
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

    function testScheduleCall_EmitsEvent(uint256 expires) public {
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

    function testPopCall_CalledBeforeScheduled_Reverts(uint256 scheduled) public {
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

    function testPopCall_CallExpired_Reverts() public {
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

    function testPopCall_CalledAtScheduledTime_CallsMethodWithArgs(uint256 scheduled) public {
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

    function testPopCall_CalledAtScheduledTime_CallsMethodWithValue(uint256 scheduled) public {
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

    function testPopCall_Success_TransfersBountyToRecipient(uint256 scheduled) public {
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

    function testPopCall_AtScheduledTime_CalledMethodReverts_Reverts() public {
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

    function testScheduleCall_ExpiryInThePast_Reverts() public {
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

    function tesPopCall_BeforeExpiry_Succeeds() public {
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

    function testPopCall_CalledTwice_Reverts(uint256 scheduled) public {
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

    // refundschedule_notowner_reverts
    // refundschedule_invalidschedule_reverts
    // refundschedule_duplicatecallreverts
    // refundschedule_transfersbounty_torecipient
    // refundschedule_expiredschedule_transfersbounty
    // refundschedule_activeschedule_transfersbounty
    // refundschedule_beforeschedule_transfersbounty
}
