// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";

abstract contract BountyAdapterTestBase is Test {
    function getDispenserAddress() public virtual returns (address);
    function testRegisterBounty_BountyDoesntExist_Reverts() public {}
    function testRegisterBounty_ProxiesCallsToProvidedRegistrar() public {}
    function testBountyExists() public {}

    // tests
    function testSupplyBounty_TransfersBounty() public virtual;

    function testTransferOwnership_AsCustodian_TransfersOwnership() public {
        (uint256 bountyId, address bountyOwner) = createAndSupplyBounty();

        address bountyReciever = address(1337);
        address dispenserAddress = getDispenserAddress();
        vm.prank(bountyOwner);

        IERC721(dispenserAddress).safeTransferFrom(bountyOwner, bountyReciever, bountyId);

        assertEq(bountyReciever, IERC721(dispenserAddress).ownerOf(bountyId));
        // Assert bounty is claimable
        // TODO: extract claim function to interface
    }

    function testTransferOwnership_NotCustodian_Reverts() public {
        (uint256 bountyId, address bountyOwner) = createAndSupplyBounty();

        vm.expectRevert("ERC721: caller is not token owner or approved");
        IERC721(getDispenserAddress()).safeTransferFrom(bountyOwner, address(this), bountyId);
    }

    function testSupplyBounty_ReturnsId() public {
        createAndSupplyBounty();
    }

    function testClaimBounty_AsBountyOwner_TransfersTokenToRecipient() public virtual;

    function testClaimBounty_NotBountyOwner_Reverts() public virtual;

    function testGetBountyCustodian_ExistingBounty_ReturnsCustodian() public virtual;

    function testGetBountyCustodian_NonExistingBounty_Reverts() public {
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(address(0), IERC721(getDispenserAddress()).ownerOf(uint256(1223)));
    }

    function testBountyExists_ReturnsTrue() public virtual;

    function createAndSupplyBounty() public virtual returns (uint256 bountyId, address bountyOwner);
}
