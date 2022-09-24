// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BountyDirectory.sol";
import "./utils/TestBountyDispenser.sol";

contract BountyDirectoryTest is Test {
    BountyDirectory private directory;
    TestBountyDispenser private bountyDispenser;

    constructor() {
        directory = new BountyDirectory();
        bountyDispenser = new TestBountyDispenser();
    }

    function testRegisterBounty_FromBountyAddress_RegistersBounty() public {
        vm.prank(address(bountyDispenser));
        directory.registerBounty(bytes32(0), address(bountyDispenser));
    }

    function testRegisterBounty_FromNonBountyAddress_Reverts() public {
        vm.expectRevert("Caller not holder of bounty.");
        directory.registerBounty(bytes32(0), address(bountyDispenser));
    }

    function testDeregisterRegisteredBounty_FromCustodian_DeregistersBounty() public {
        // create+register bounty
        bytes32 bountyHash = bytes32(uint256(1));
        vm.prank(address(bountyDispenser));
        bytes32 addressedBountyHash = directory.registerBounty(bountyHash, address(bountyDispenser));
        // set custodian response
        bountyDispenser.setBountyCustodianResponse(bountyHash, address(this));

        // act
        directory.deregisterBounty(addressedBountyHash);

        // assert
        vm.expectRevert("bounty does not exist");
        directory.getBountyInfo(addressedBountyHash);
    }

    function testDeregisterRegisteredBounty_NotFromCustodian_Reverts() public {
        // create+register bounty
        vm.prank(address(bountyDispenser));
        bytes32 bountyHash = bytes32(uint256(1));
        bytes32 addressedBountyHash = directory.registerBounty(bountyHash, address(bountyDispenser));
        // set custodian response to NOT this address
        bountyDispenser.setBountyCustodianResponse(addressedBountyHash, address(address(1)));

        // act
        vm.expectRevert("only custodian can deregister");
        directory.deregisterBounty(addressedBountyHash);
    }

    function testGetBountyInfo_ReturnsBountyInfo() public {
        // populate+register bounty
        bytes32 bountyHash = bytes32(uint256(1));
        vm.prank(address(bountyDispenser));
        bytes32 addressedHash = directory.registerBounty(bountyHash, address(bountyDispenser));

        // act
        (address contractAddress, bytes32 returnedHash) = directory.getBountyInfo(addressedHash);

        // assert
        assertEq(address(bountyDispenser), contractAddress);
        assertEq(bountyHash, returnedHash);
    }

    function testGetBountyInfo_NotExistantBounty_Reverts() public {
        vm.expectRevert("bounty does not exist");
        directory.getBountyInfo(bytes32(uint256(1)));
    }
}
