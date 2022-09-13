// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/BountyDirectory.sol";
import "./utils/TestBountyDispenser.sol";

abstract contract BountyDispenserTestBase is Test {
    function testRegisterBounty_BountyDoesntExist_Reverts() public {}
    function testRegisterBounty_ProxiesCallsToProvidedRegistrar() public {}
    function testBountyExists() public {}

    function testSupplyBounty_ReturnsHash() public virtual;

    function testSupplyBounty_TransfersBounty() public virtual;

    function testDispenseBountyTo_NotCustodian_Reverts() public virtual;

    function testDispenseBountyTo_AsCustodian_TransfersToken() public virtual;

    function testDispenseBountyTo_Success_BountyDeleted() public virtual;

    function testRefundBounty_AsBountyOwner_TransfersTokenToRecipient() public virtual;

    function testRefundBOunty_NotBountyOwner_Reverts() public virtual;

    function testGetBountyCustodian_ExistingBounty_ReturnsCustodian() public virtual;

    function testGetBountyCustodian_NonExistingBounty_ReturnsZero() public virtual;

    function testBountyExists_ReturnsTrue() public virtual;
}
