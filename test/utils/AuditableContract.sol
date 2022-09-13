// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title AuditableContract
/// @author eoghan
/// @notice A contract that emits an event when called, and can be configured
/// to revert.
contract AuditableContract {
    bool private reverts;

    event Called(uint256 argument1, uint256 argument2);

    constructor(bool shouldRevert) {
        reverts = shouldRevert;
    }

    function payableFunction(uint256 argument1, uint256 argument2) external payable {
        if (reverts) {
            revert("reverts!");
        }
        emit Called(argument1, argument2);
    }
}
