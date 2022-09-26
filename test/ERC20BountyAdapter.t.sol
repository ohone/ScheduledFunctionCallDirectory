// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BountyAdapterTestBase.sol";
import "./utils/TestERC20.sol";
import "../src/ERC20BountyAdapter.sol";

contract ERC20BountyAdapterTest is BountyAdapterTestBase {
    ERC20BountyAdapter adapter;
    TestERC20 testToken;

    constructor() {
        adapter = new ERC20BountyAdapter();
        testToken = new TestERC20("test", "test");
    }

    function getDispenserAddress() public override returns (address) {
        return address(adapter);
    }

    function createAndSupplyBounty() public override returns (uint256 bountyId, address bountyOwner) {
        testToken.mint(address(this), 100);
        testToken.approve(address(adapter), 100);
        bountyOwner = address(1);
        bountyId = adapter.supplyBounty(address(testToken), address(this), 100, bountyOwner);

        return (bountyId, bountyOwner);
    }

    function testSupplyBounty_TransfersBounty() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(adapter), 100);
        address custodian = address(1);

        uint256 tokenId = adapter.supplyBounty(address(testToken), address(this), 100, custodian);

        assertEq(0, testToken.balanceOf(address(this)));
        assertEq(100, testToken.balanceOf(address(adapter)));
    }

    function testClaimBounty_AsBountyOwner_TransfersTokenToRecipient() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(adapter), 100);
        address custodian = address(1);
        uint256 tokenId = adapter.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        address recipient = address(10);
        vm.prank(custodian);
        adapter.burnBounty(tokenId, recipient);
        assertEq(100, testToken.balanceOf(recipient));
    }

    function testClaimBounty_NotBountyOwner_Reverts() public override {
        // supply bountty
        testToken.mint(address(this), 100);
        testToken.approve(address(adapter), 100);
        address custodian = address(1);
        uint256 tokenId = adapter.supplyBounty(address(testToken), address(this), 100, custodian);

        // act
        address recipient = address(1);

        vm.startPrank(address(2));
        vm.expectRevert("only custodian can claim bounty");
        adapter.burnBounty(tokenId, recipient);
    }

    function testGetBountyCustodian_ExistingBounty_ReturnsCustodian() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(adapter), 100);
        address custodian = address(1);

        uint256 tokenId = adapter.supplyBounty(address(testToken), address(this), 100, custodian);

        assertEq(custodian, adapter.ownerOf(tokenId));
    }

    function testBountyExists_ReturnsTrue() public override {
        testToken.mint(address(this), 100);
        testToken.approve(address(adapter), 100);
        address custodian = address(1);

        uint256 tokenId = adapter.supplyBounty(address(testToken), address(this), 100, custodian);

        assertTrue(adapter.bountyExists(tokenId));
    }

    function testBountyExists_ReturnsFalse() public {
        assertFalse(adapter.bountyExists(uint256(0)));
    }
}
