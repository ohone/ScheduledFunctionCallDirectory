// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IBountyAdapter.sol";
import "openzeppelin-contracts/token/ERC721/ERC721.sol";

abstract contract BountyAdapterBase is IBountyAdapter, ERC721 {
    uint256 private currentBountyId;

    function getNewBountyId() internal returns (uint256) {
        return currentBountyId++;
    }

    function bountyExists(uint256 tokenId) public view virtual returns (bool);
}
