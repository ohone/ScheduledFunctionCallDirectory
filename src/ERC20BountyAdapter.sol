// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC20.sol";
import "./BountyAdapterBase.sol";

contract ERC20BountyAdapter is BountyAdapterBase {
    constructor() ERC721("ERC20Bounty", "ERC20B") {}

    struct ERC20Bounty {
        address token;
        uint256 amount;
    }

    mapping(uint256 => ERC20Bounty) private bounties;

    function supplyBounty(address token, address from, uint256 amount, address custodian) external returns (uint256) {
        IERC20(token).transferFrom(from, address(this), amount);

        uint256 bountyId = getNewBountyId();
        bounties[bountyId] = ERC20Bounty(token, amount);

        _mint(custodian, bountyId);

        return bountyId;
    }

    function claimBounty(uint256 bountyId, address recipient) external {
        ERC20Bounty storage bounty = bounties[bountyId];

        require(msg.sender == ownerOf(bountyId), "only custodian can claim bounty");

        uint256 amount = bounty.amount;
        address token = bounty.token;

        delete bounties[bountyId];

        _burn(bountyId);
        IERC20(token).transfer(recipient, amount);
    }

    function bountyExists(uint256 bountyHash) public view override returns (bool) {
        return bounties[bountyHash].token != address(0);
    }
}
