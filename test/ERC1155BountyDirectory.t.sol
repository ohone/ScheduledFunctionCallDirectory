// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BountyDispenserTestBase.sol";
import "./utils/TestERC1155.sol";
import "src/ERC1155BountyDirectory.sol";
import "openzeppelin-contracts/interfaces/IERC1155Receiver.sol";
import "./utils/TestERC1155Reciever.sol";

contract ERC1155BountyDirectoryTest is BountyDispenserTestBase {
    ERC1155BountyDirectory private dispenser;
    TestERC1155 private testToken;
    TestERC1155Reciever private reciever;

    constructor() {
        reciever = new TestERC1155Reciever();
        dispenser = new ERC1155BountyDirectory();
        testToken = new TestERC1155("test");
    }

    function testSupplyBounty_ReturnsHash() public override {
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(dispenser), true);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);
        assertFalse(bountyHash == bytes32(0));
    }

    function testSupplyBounty_TransfersBounty() public override {
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(dispenser), true);
        address custodian = address(1);

        dispenser.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        assertEq(0, testToken.balanceOf(address(reciever), tokenId));
        assertEq(amount, testToken.balanceOf(address(dispenser), tokenId));
    }

    function testTransferOwnership_NotCustodian_Reverts() public override {
        // supply bounty
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(dispenser), true);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        vm.expectRevert("only custodian can dispense bounty");
        dispenser.transferOwnership(bountyHash, address(reciever));
    }

    function testTransferOwnership_AsCustodian_TransfersOwnership() public override {
        // supply bounty
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(dispenser), true);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        // act
        address recipient = address(1);
        vm.prank(custodian);
        dispenser.transferOwnership(bountyHash, recipient);

        // assert
        assertEq(recipient, dispenser.getBountyCustodian(bountyHash));
        vm.prank(recipient);
        dispenser.claimBounty(bountyHash, recipient);
        assertEq(amount, testToken.balanceOf(recipient, tokenId));
    }

    function testClaimBounty_AsBountyOwner_TransfersTokenToRecipient() public override {
        // supply bounty
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(dispenser), true);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        // act
        vm.prank(address(custodian));
        dispenser.claimBounty(bountyHash, address(reciever));

        assertEq(amount, testToken.balanceOf(address(reciever), tokenId));
    }

    function testClaimBounty_NotBountyOwner_Reverts() public override {
        // supply bounty
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(dispenser), true);
        address custodian = address(1);
        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        // act
        address recipient = address(1);

        vm.startPrank(address(2));
        vm.expectRevert("only custodian can claim bounty");
        dispenser.claimBounty(bountyHash, recipient);
    }

    function testGetBountyCustodian_ExistingBounty_ReturnsCustodian() public override {
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(dispenser), true);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);
        assertEq(custodian, dispenser.getBountyCustodian(bountyHash));
    }

    function testGetBountyCustodian_NonExistingBounty_ReturnsZero() public override {
        assertEq(address(0), dispenser.getBountyCustodian(bytes32(uint256(0))));
    }

    function testBountyExists_ReturnsTrue() public override {
        uint256 tokenId = 100;
        uint256 amount = 10;
        testToken.mint(address(reciever), tokenId, amount, bytes(""));
        vm.prank(address(reciever));
        testToken.setApprovalForAll(address(dispenser), true);
        address custodian = address(1);

        bytes32 bountyHash = dispenser.supplyBounty(address(testToken), address(reciever), tokenId, amount, custodian);

        assertTrue(dispenser.bountyExists(bountyHash));
    }

    function testBountyExists_ReturnsFalse() public {
        assertFalse(dispenser.bountyExists(bytes32(uint256(0))));
    }
}
