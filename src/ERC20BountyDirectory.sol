// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC20.sol";
import "./BountyDispenserBase.sol";

contract ERC20BountyDirectory is BountyDispenserBase {
    struct ERC20Bounty {
        address token;
        address from;
        uint256 amount;
        address custodian;
    }

    mapping(bytes32 => ERC20Bounty) bounties;

    function supplyBounty(address token, address from, uint256 amount, address custodian) external returns (bytes32) {
        IERC20(token).transferFrom(from, address(this), amount);

        bytes32 bountyHash = keccak256(abi.encodePacked(token, from, amount));

        bounties[bountyHash] = ERC20Bounty(token, from, amount, custodian);

        return bountyHash;
    }

    function dispenseBountyTo(bytes32 bountyHash, address recipient) external {
        ERC20Bounty storage bounty = bounties[bountyHash];

        require(msg.sender == bounty.custodian, "only custodian can dispense bounty");

        uint256 amount = bounty.amount;
        address token = bounty.token;

        delete bounties[bountyHash];

        IERC20(token).transfer(recipient, amount);
    }

    function refundBounty(bytes32 bountyHash, address recipient) external {
        ERC20Bounty storage bounty = bounties[bountyHash];

        address bountyOwner = bounty.from;
        require(bountyOwner == msg.sender, "sender doesn't have rights to this bounty");

        uint256 amount = bounty.amount;
        address token = bounty.token;

        delete bounties[bountyHash];

        IERC20(token).transfer(recipient, amount);
    }

    function getBountyCustodian(bytes32 bountyHash) external view returns (address) {
        ERC20Bounty storage bounty = bounties[bountyHash];

        return bounty.custodian;
    }

    function bountyExists(bytes32 bountyHash) public view override returns (bool) {
        return bounties[bountyHash].token != address(0);
    }
}
