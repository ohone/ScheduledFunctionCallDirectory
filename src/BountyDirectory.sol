// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IBountyDispenser.sol";
import "./IBountyDirectory.sol";

contract BountyDirectory is IBountyDirectory {
    mapping(bytes32 => bountyInfo) private bountyContracts;

    struct bountyInfo {
        address bountyContract;
        uint256 bountyHash;
    }

    modifier onlyContract(address bountyContract) {
        require(msg.sender == bountyContract, "Caller not holder of bounty.");
        _;
    }

    function registerBounty(uint256 bountyHash, address bountyContract)
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
        address custodian = IBountyDispenser(info.bountyContract).ownerOf(info.bountyHash);
        require(msg.sender == custodian, "only custodian can deregister");

        delete bountyContracts[addressedBountyHash];
    }

    function getBountyInfo(bytes32 addressedBountyHash) external view returns (address, uint256) {
        bountyInfo storage info = bountyContracts[addressedBountyHash];
        if (info.bountyContract == address(0)) {
            revert("bounty does not exist");
        }
        return (info.bountyContract, info.bountyHash);
    }
}
