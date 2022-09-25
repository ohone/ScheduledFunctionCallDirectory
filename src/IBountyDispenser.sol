// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IBountyDispenser {
    function transferOwnership(bytes32 bounty, address recipient) external;
    function claimBounty(bytes32 bountyHash, address recipient) external;
    function getBountyCustodian(bytes32 bounty) external returns (address);
    function registerBounty(bytes32 bountyHash, address registrar) external returns (bytes32);
}
