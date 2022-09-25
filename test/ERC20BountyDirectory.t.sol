// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BountyDispenserTestBase.sol";
import "./utils/TestERC20.sol";
import "../src/ERC20BountyDirectory.sol";

contract ERC20BountyDirectoryTest is BountyDispenserTestBase {
    ERC20BountyDirectory dispenser;
    TestERC20 testToken;

    constructor() {
        dispenser = new ERC20BountyDirectory();
        testToken = new TestERC20("test", "test");
    }

    function testSupplyBounty_ReturnsHash() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);
    }

    function testSupplyBounty_TransfersBounty() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        assertEq(0, testToken.balanceOf(address(this)));
        assertEq(100, testToken.balanceOf(address(dispenser)));
    }

    function testTransferOwnership_NotCustodian_Reverts() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        vm.expectRevert("only custodian can dispense bounty");
        dispenser.transferOwnership(bountyHash, address(this));
    }

    function testTransferOwnership_AsCustodian_TransfersOwnership() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        address reciever = address(1337);
        vm.prank(custodian);
        dispenser.transferOwnership(bountyHash, reciever);

        assertEq(reciever, dispenser.getBountyCustodian(bountyHash));

        vm.prank(reciever);
        dispenser.claimBounty(bountyHash, reciever);
        assertEq(100, testToken.balanceOf(reciever));
    }

    function testClaimBounty_AsBountyOwner_TransfersTokenToRecipient() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        address recipient = address(10);
        vm.prank(custodian);
        dispenser.claimBounty(bountyHash, recipient);
        assertEq(100, testToken.balanceOf(recipient));
    }

    function testClaimBounty_NotBountyOwner_Reverts() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        address recipient = address(1);

        vm.startPrank(address(2));
        vm.expectRevert("only custodian can claim bounty");
        dispenser.claimBounty(bountyHash, recipient);
    }

    function testGetBountyCustodian_ExistingBounty_ReturnsCustodian() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        assertEq(custodian, dispenser.getBountyCustodian(bountyHash));
    }

    function testGetBountyCustodian_NonExistingBounty_ReturnsZero() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);

        assertEq(address(0), dispenser.getBountyCustodian(bytes32(uint256(1))));
    }

    function testBountyExists_ReturnsTrue() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        assertTrue(dispenser.bountyExists(bountyHash));
    }

    function testBountyExists_ReturnsFalse() public {
        assertFalse(dispenser.bountyExists(bytes32(uint256(0))));
    }
}
