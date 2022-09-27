// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/interfaces/IERC721Receiver.sol";
import "./BountyAdapterBase.sol";

contract ERC721BountyAdapter is BountyAdapterBase, IERC721Receiver {
    constructor() ERC721("ERC721Bounty", "ERC721B") {}

    struct ERC721Bounty {
        address token;
        uint256 id;
    }

    mapping(uint256 => ERC721Bounty) private bounties;

    function supplyBounty(address token, address from, uint256 id, address custodian) external returns (uint256) {
        uint256 bountyId = getNewBountyId();
        bounties[bountyId] = ERC721Bounty(token, id);
        _mint(custodian, bountyId);

        IERC721(token).safeTransferFrom(from, address(this), id);
        return bountyId;
    }

    function burnBounty(uint256 bountyId, address recipient) external {
        ERC721Bounty storage bounty = bounties[bountyId];

        require(msg.sender == ownerOf(bountyId), "only custodian can claim bounty");

        uint256 id = bounty.id;
        address token = bounty.token;

        delete bounties[bountyId];

        _burn(bountyId);
        IERC721(token).safeTransferFrom(address(this), recipient, id);
    }

    function bountyExists(uint256 bountyHash) public view override returns (bool) {
        return bounties[bountyHash].token != address(0);
    }

    /**
     * @dev See {IERC721-onERC721Received}.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
