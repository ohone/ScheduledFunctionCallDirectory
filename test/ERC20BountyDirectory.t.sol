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

    function getDispenserAddress() public override returns (address) {
        return address(dispenser);
    }

    function createAndSupplyBounty() public override returns (uint256 bountyId, address bountyOwner) {
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        bountyOwner = address(1);
        bountyId = dispenser.supplyBounty(address(testToken), address(this), 100, bountyOwner);

        return (bountyId, bountyOwner);
    }

    function testSupplyBounty_TransfersBounty() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);

        uint256 tokenId = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        assertEq(0, testToken.balanceOf(address(this)));
        assertEq(100, testToken.balanceOf(address(dispenser)));
    }

    function testClaimBounty_AsBountyOwner_TransfersTokenToRecipient() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        uint256 tokenId = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        address recipient = address(10);
        vm.prank(custodian);
        dispenser.claimBounty(tokenId, recipient);
        assertEq(100, testToken.balanceOf(recipient));
    }

    function testClaimBounty_NotBountyOwner_Reverts() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);
        uint256 tokenId = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        address recipient = address(1);

        vm.startPrank(address(2));
        vm.expectRevert("only custodian can claim bounty");
        dispenser.claimBounty(tokenId, recipient);
    }

    function testGetBountyCustodian_ExistingBounty_ReturnsCustodian() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);

        uint256 tokenId = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        assertEq(custodian, dispenser.ownerOf(tokenId));
    }

    function testBountyExists_ReturnsTrue() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(dispenser), 100);
        address custodian = address(1);

        uint256 tokenId = dispenser.supplyBounty(address(testToken), address(this), 100, custodian);

        assertTrue(dispenser.bountyExists(tokenId));
    }

    function testBountyExists_ReturnsFalse() public {
        assertFalse(dispenser.bountyExists(uint256(0)));
    }
}
