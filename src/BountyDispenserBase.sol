// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IBountyDispenser.sol";
import "./IBountyDirectory.sol";

abstract contract BountyDispenserBase is IBountyDispenser {
    function registerBounty(bytes32 bountyHash, address registrar) external returns (bytes32) {
        require(bountyExists(bountyHash), "specified bounty doesn't exist");
        return IBountyDirectory(registrar).registerBounty(bountyHash, address(this));
    }

    function bountyExists(bytes32 bountyHash) public view virtual returns (bool);
}
