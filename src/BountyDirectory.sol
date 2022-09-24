// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IBountyDispenser.sol";
import "./IBountyDirectory.sol";

contract BountyDirectory is IBountyDirectory {
    mapping(bytes32 => bountyInfo) bountyContracts;

    struct bountyInfo {
        address bountyContract;
        bytes32 bountyHash;
    }

    modifier onlyContract(address bountyContract) {
        require(msg.sender == bountyContract, "Caller is not holder of the bounty.");
        _;
    }

    function registerBounty(bytes32 bountyHash, address bountyContract)
        external
        onlyContract(bountyContract)
        returns (bytes32)
    {
        bytes32 addressedBountyHash = keccak256(abi.encodePacked(bountyHash, bountyContract));
        bountyContracts[addressedBountyHash] = bountyInfo(bountyContract, bountyHash);
        return addressedBountyHash;
    }

    function deregisterBounty(bytes32 addressedBountyHash) external {
        bountyInfo storage info = bountyContracts[addressedBountyHash];
        address custodian = IBountyDispenser(info.bountyContract).getBountyCustodian(info.bountyHash);
        require(msg.sender == custodian, "only bounty custodian can deregister bounty");

        delete bountyContracts[addressedBountyHash];
    }

    function getBountyInfo(bytes32 addressedBountyHash) external view returns (address, bytes32) {
        bountyInfo storage info = bountyContracts[addressedBountyHash];
        if (info.bountyContract == address(0)){
            revert("bounty does not exist");
        }
        return (info.bountyContract, info.bountyHash);
    }
}
