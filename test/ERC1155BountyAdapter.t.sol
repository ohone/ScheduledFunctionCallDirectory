// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BountyAdapterTestBase.sol";
import "./utils/TestERC1155.sol";
import "src/ERC1155BountyAdapter.sol";
import "openzeppelin-contracts/interfaces/IERC1155Receiver.sol";
import "./utils/TestERC1155Reciever.sol";

contract ERC1155BountyAdapterTest is BountyAdapterTestBase {
    ERC1155BountyAdapter private adapter;
    TestERC1155 private testToken;
    TestERC1155Reciever private reciever;

    constructor() {
        reciever = new TestERC1155Reciever();
        adapter = new ERC1155BountyAdapter();
        testToken = new TestERC1155("test");
    }

    function getDispenserAddress() public override returns (address) {
        return address(adapter);
    }

    function createAndSupplyBounty() public override returns (uint256 bountyId, address bountyOwner) {
        testToken.mint(address(reciever), 1, 1, "");
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(adapter), true);
        bountyOwner = address(199);
        vm.prank(address(reciever));
        bountyId = adapter.supplyBounty(address(testToken), address(reciever), 1, 1, bountyOwner);

        return (bountyId, bountyOwner);
    }

    function testSupplyBounty_TransfersBounty() public override {
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(adapter), true);
        address custodian = address(1);

        adapter.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        assertEq(0, testToken.balanceOf(address(reciever), tokenId));
        assertEq(amount, testToken.balanceOf(address(adapter), tokenId));
    }

    function testClaimBounty_AsBountyOwner_TransfersTokenToRecipient() public override {
        // supply bounty
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(adapter), true);
        address custodian = address(1);
        uint256 bountyId = adapter.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        // act
        vm.prank(address(custodian));
        adapter.burnBounty(bountyId, address(reciever));

        assertEq(amount, testToken.balanceOf(address(reciever), tokenId));
    }

    function testClaimBounty_NotBountyOwner_Reverts() public override {
        // supply bounty
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(adapter), true);
        address custodian = address(1);
        uint256 bountyId = adapter.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        // act
        address recipient = address(1);

        vm.startPrank(address(2));
        vm.expectRevert("only custodian can claim bounty");
        adapter.burnBounty(bountyId, recipient);
    }

    function testGetBountyCustodian_ExistingBounty_ReturnsCustodian() public override {
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(adapter), true);
        address custodian = address(1);

        uint256 bountyTokenId = adapter.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);
        assertEq(custodian, adapter.ownerOf(bountyTokenId));
    }

    function testBountyExists_ReturnsTrue() public override {
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(adapter), true);
        address custodian = address(1);

        uint256 bountyTokenId = adapter.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        assertTrue(adapter.bountyExists(bountyTokenId));
    }

    function testBountyExists_ReturnsFalse() public {
        assertFalse(adapter.bountyExists(uint256(0)));
    }
}
