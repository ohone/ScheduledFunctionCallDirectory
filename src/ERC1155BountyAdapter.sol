// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC1155.sol";
import "openzeppelin-contracts/interfaces/IERC1155Receiver.sol";
import "./BountyAdapterBase.sol";

contract ERC1155BountyAdapter is BountyAdapterBase, IERC1155Receiver {
    constructor() ERC721("ERC1155Bounty", "ERC1155B") {}

    struct ERC1155Bounty {
        address token;
        uint256 id;
        uint256 amount;
    }

    mapping(uint256 => ERC1155Bounty) private bounties;

    function supplyBounty(address token, address from, uint256 id, uint256 amount, address custodian)
        external
        returns (uint256)
    {
        uint256 bountyId = getNewBountyId();
        bounties[bountyId] = ERC1155Bounty(token, id, amount);
        _mint(custodian, bountyId);

        IERC1155(token).safeTransferFrom(from, address(this), id, amount, "");
        return bountyId;
    }

    function burnBounty(uint256 bountyId, address recipient) external {
        ERC1155Bounty storage bounty = bounties[bountyId];

        require(msg.sender == ownerOf(bountyId), "only custodian can claim bounty");

        uint256 id = bounty.id;
        address token = bounty.token;
        uint256 amount = bounty.amount;

        delete bounties[bountyId];

        _burn(bountyId);
        IERC1155(token).safeTransferFrom(address(this), recipient, id, amount, "");
    }

    function bountyExists(uint256 tokenId) public view override returns (bool) {
        return bounties[tokenId].token != address(0);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public pure override (IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
            || interfaceId == type(IERC721).interfaceId;
    }

    /**
     * @dev See {IERC1155Receiver-onERC1155Received}.
     */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    /**
     * @dev See {IERC1155Receiver-onERC1155BatchReceived}.
     */
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }
}
