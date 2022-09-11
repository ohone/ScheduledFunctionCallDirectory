// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BountyDispenserTestBase.sol";
import "./TestERC721.sol";
import "../src/ERC721BountyDirectory.sol";

contract ERC721BountyDirectoryTest is BountyDispenserTestBase {
    ERC721BountyDirectory dispenser;
    TestERC721 testToken;

    constructor() public {
        dispenser = new ERC721BountyDirectory();
        testToken = new TestERC721("test","test");
    }

    function testSupplyBounty_ReturnsHash() public override {
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);
    }

    function testSupplyBounty_TransfersBounty() public override {
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        assertEq(0, testToken.balanceOf(address(this)));
        assertEq(1, testToken.balanceOf(address(dispenser)));
        assertEq(address(dispenser), testToken.ownerOf(tokenId));
    }

    function testDispenseBountyTo_NotCustodian_Reverts() public override {
        // supply bounty
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        vm.expectRevert("only custodian can dispense bounty");
        dispenser.dispenseBountyTo(bountyHash, address(this));
    }

    function testDispenseBountyTo_AsCustodian_TransfersToken() public override {
        // supply bounty
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        // act
        address recipient = address(1);
        vm.prank(custodian);
        dispenser.dispenseBountyTo(bountyHash, recipient);

        assertEq(1, testToken.balanceOf(recipient));
        assertEq(address(recipient), testToken.ownerOf(tokenId));
    }

    function testDispenseBountyTo_Success_BountyDeleted() public override {
        // supply bounty
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        // act
        vm.prank(custodian);
        dispenser.dispenseBountyTo(bountyHash, custodian);

        assertFalse(dispenser.bountyExists(bountyHash));
    }

    function testRefundBounty_AsBountyOwner_TransfersTokenToRecipient() public override {
        // supply bounty
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        // act
        address recipient = address(1);
        dispenser.refundBounty(bountyHash, recipient);

        assertEq(1, testToken.balanceOf(recipient));
        assertEq(recipient, testToken.ownerOf(tokenId));
    }

    function testRefundBOunty_NotBountyOwner_Reverts() public override {
        // supply bounty
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        // act
        address recipient = address(1);

        vm.startPrank(address(1));
        vm.expectRevert("sender doesn't have rights to this bounty");
        dispenser.refundBounty(bountyHash, recipient);
    }

    function testGetBountyCustodian_ExistingBounty_ReturnsCustodian() public override {
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        assertEq(custodian, dispenser.getBountyCustodian(bountyHash));
    }

    function testGetBountyCustodian_NonExistingBounty_ReturnsZero() public override {
        assertEq(address(0), dispenser.getBountyCustodian(bytes32(uint256(0))));
    }

    function testBountyExists_ReturnsTrue() public override {
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        assertTrue(dispenser.bountyExists(bountyHash));
    }

    function testBountyExists_ReturnsFalse() public {
        assertFalse(dispenser.bountyExists(bytes32(uint256(0))));
    }
}
