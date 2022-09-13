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

    function testDispenseBountyTo_NotCustodian_Reverts() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        vm.expectRevert("only custodian can dispense bounty");
        dispenser.dispenseBountyTo(bountyHash, address(this));
    }

    function testDispenseBountyTo_AsCustodian_TransfersToken() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        vm.prank(custodian);
        dispenser.dispenseBountyTo(bountyHash, custodian);

        assertEq(100, testToken.balanceOf(custodian));
    }

    function testDispenseBountyTo_Success_BountyDeleted() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        // double-up tokens owned by dispenser
        testToken.mint(address(dispenser), 100);
        testToken.approve(address(dispenser), 200);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        vm.prank(custodian);
        dispenser.dispenseBountyTo(bountyHash, custodian);
        assertEq(100, testToken.balanceOf(custodian));

        // act again, attempt to get the other 100 tokens
        vm.expectRevert("only custodian can dispense bounty");
        dispenser.dispenseBountyTo(bountyHash, custodian);
    }

    function testRefundBounty_AsBountyOwner_TransfersTokenToRecipient() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        address recipient = address(1);
        dispenser.refundBounty(bountyHash, recipient);
        assertEq(100, testToken.balanceOf(recipient));
    }

    function testRefundBOunty_NotBountyOwner_Reverts() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        address recipient = address(1);

        vm.startPrank(address(1));
        vm.expectRevert("sender doesn't have rights to this bounty");
        dispenser.refundBounty(bountyHash, recipient);
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
