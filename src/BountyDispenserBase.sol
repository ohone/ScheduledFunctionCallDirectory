// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IBountyDispenser.sol";
import "./IBountyDirectory.sol";
import "openzeppelin-contracts/token/ERC721/ERC721.sol";

abstract contract BountyDispenserBase is IBountyDispenser, ERC721 {
    uint256 private currentBountyId;

    function getNewBountyId() public returns (uint256) {
        return currentBountyId++;
    }

    function bountyExists(uint256 tokenId) public view virtual returns (bool);
}
