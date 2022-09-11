// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/interfaces/IERC721Receiver.sol";
import "./BountyDispenserBase.sol";

contract ERC721BountyDirectory is BountyDispenserBase, IERC721Receiver {
    struct ERC721Bounty {
        address token;
        address from;
        uint256 id;
        address custodian;
    }

    mapping(bytes32 => ERC721Bounty) bounties;

    function supplyBounty(address token, address from, uint256 id, uint256 amount, address custodian)
        external
        returns (bytes32)
    {
        IERC721(token).safeTransferFrom(from, address(this), id);

        bytes32 bountyHash = keccak256(abi.encodePacked(token, from, id, amount, custodian));

        bounties[bountyHash] = ERC721Bounty(token, from, id, custodian);

        return bountyHash;
    }

    function dispenseBountyTo(bytes32 bountyHash, address recipient) external {
        ERC721Bounty storage bounty = bounties[bountyHash];

        require(msg.sender == bounty.custodian, "only custodian can dispense bounty");

        uint256 id = bounty.id;
        address token = bounty.token;
        delete bounties[bountyHash];

        IERC721(token).safeTransferFrom(address(this), recipient, id);
    }

    function refundBounty(bytes32 bountyHash, address recipient) external {
        ERC721Bounty storage bounty = bounties[bountyHash];

        address bountyOwner = bounty.from;
        require(bountyOwner == msg.sender, "sender doesn't have rights to this bounty");

        uint256 id = bounty.id;
        address token = bounty.token;

        delete bounties[bountyHash];

        IERC721(token).safeTransferFrom(address(this), recipient, id);
    }

    function getBountyCustodian(bytes32 bountyHash) external view returns (address) {
        ERC721Bounty storage bounty = bounties[bountyHash];

        return bounty.custodian;
    }

    function bountyExists(bytes32 bountyHash) public view override returns (bool) {
        return bounties[bountyHash].token != address(0);
    }

    /**
     * @dev See {IERC721-onERC721Received}.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
