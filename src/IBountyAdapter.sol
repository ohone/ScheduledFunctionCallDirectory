// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/IERC721.sol";

interface IBountyAdapter is IERC721 {
    function burnBounty(uint256 bountyId, address recipient) external;
}
