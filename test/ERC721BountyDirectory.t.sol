// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BountyDispenserTestBase.sol";
import "./utils/TestERC721.sol";
import "src/ERC721BountyDirectory.sol";

contract ERC721BountyDirectoryTest is BountyDispenserTestBase {
    ERC721BountyDirectory dispenser;
    TestERC721 testToken;

    constructor() public {
        dispenser = new ERC721BountyDirectory();
        testToken = new TestERC721("test","test");
    }

    function getDispenserAddress() public override returns (address) {
        return address(dispenser);
    }

    function createAndSupplyBounty() public override returns (uint256 bountyId, address bountyOwner) {
        uint256 tokenId = 1;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), 1);
        bountyOwner = address(1);
        bountyId = dispenser.supplyBounty(address(testToken), address(this), 1, bountyOwner);
        return (bountyId, bountyOwner);
    }

    // Tests

    function testSupplyBounty_TransfersBounty() public override {
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);

        uint256 bountyId = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        assertEq(0, testToken.balanceOf(address(this)));
        assertEq(1, testToken.balanceOf(address(dispenser)));
        assertEq(address(dispenser), testToken.ownerOf(tokenId));
    }

    function testClaimBounty_AsBountyOwner_TransfersTokenToRecipient() public override {
        // supply bounty
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);
        uint256 bountyId = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        // act
        address recipient = address(10);
        vm.prank(custodian);
        dispenser.claimBounty(bountyId, recipient);

        assertEq(1, testToken.balanceOf(recipient));
        assertEq(recipient, testToken.ownerOf(tokenId));
    }

    function testClaimBounty_NotBountyOwner_Reverts() public override {
        // supply bounty
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);
        uint256 bountyId = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        // act
        address recipient = address(1);

        vm.startPrank(address(2));
        vm.expectRevert("only custodian can claim bounty");
        dispenser.claimBounty(bountyId, recipient);
    }

    function testGetBountyCustodian_ExistingBounty_ReturnsCustodian() public override {
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);

        uint256 bountyId = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        assertEq(custodian, dispenser.ownerOf(bountyId));
    }

    function testBountyExists_ReturnsTrue() public override {
        uint256 tokenId = 100;
        testToken.mint(address(this), tokenId);
        testToken.approve(address(dispenser), tokenId);
        address custodian = address(1);

        uint256 bountyId = dispenser.supplyBounty(address(testToken), address(this), tokenId, custodian);

        assertTrue(dispenser.bountyExists(bountyId));
    }

    function testBountyExists_ReturnsFalse() public {
        assertFalse(dispenser.bountyExists(0));
    }
}
