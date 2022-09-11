// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC1155.sol";
import "openzeppelin-contracts/interfaces/IERC1155Receiver.sol";
import "./BountyDispenserBase.sol";

contract ERC1155BountyDirectory is BountyDispenserBase, IERC1155Receiver {
    struct ERC1155Bounty {
        address token;
        address from;
        uint256 id;
        uint256 amount;
        address custodian;
    }

    mapping(bytes32 => ERC1155Bounty) bounties;

    function supplyBounty(address token, address from, uint256 id, uint256 amount, address custodian)
        external
        returns (bytes32)
    {
        IERC1155(token).safeTransferFrom(from, address(this), id, amount, "");

        bytes32 bountyHash = keccak256(abi.encodePacked(token, from, id, amount, custodian));

        bounties[bountyHash] = ERC1155Bounty(token, from, id, amount, custodian);

        return bountyHash;
    }

    function dispenseBountyTo(bytes32 bountyHash, address recipient) external {
        ERC1155Bounty storage bounty = bounties[bountyHash];

        require(msg.sender == bounty.custodian, "only custodian can dispense bounty");

        uint256 amount = bounty.amount;
        uint256 id = bounty.id;
        address token = bounty.token;
        delete bounties[bountyHash];

        IERC1155(token).safeTransferFrom(address(this), recipient, id, amount, "");
    }

    function refundBounty(bytes32 bountyHash, address recipient) external {
        ERC1155Bounty storage bounty = bounties[bountyHash];

        address bountyOwner = bounty.from;
        require(bountyOwner == msg.sender, "sender doesn't have rights to this bounty");

        uint256 amount = bounty.amount;
        uint256 id = bounty.id;
        address token = bounty.token;

        delete bounties[bountyHash];

        IERC1155(token).safeTransferFrom(address(this), recipient, id, amount, "");
    }

    function getBountyCustodian(bytes32 bountyHash) external view returns (address) {
        ERC1155Bounty storage bounty = bounties[bountyHash];

        return bounty.custodian;
    }

    function bountyExists(bytes32 bountyHash) public view override returns (bool) {
        return bounties[bountyHash].token != address(0);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId;
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
