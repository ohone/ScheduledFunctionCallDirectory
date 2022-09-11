// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IBountyDirectory {
    /// @notice Registers a bounty referenced in bountyContract by bountyHash
    /// in this directory, and returns a new identifier for referring to this
    /// bounty in this contract.
    /// @dev The returned
    /// @param bountyHash  the identifier of the bounty in the referenced bountyContract
    /// to register.
    /// @return bountyHash a new identifier used for referring to the bounty in this contract.
    function registerBounty(bytes32 bountyHash, address bountyContract) external returns (bytes32);
    /// @notice Removes the bounty from this register. Does not
    /// refund or otherwise action the bounty from the contract that describes
    /// it or the bounty's controller.
    /// @param bountyHash the identifier of the bounty to deregister.
    function deregisterBounty(bytes32 bountyHash) external;
    /// @notice Retrieve the holding contract's address and identifier for the bounty.
    /// @param bountyHash the identifier of the bounty
    /// @return (address,bytes32) the address of the contract that describes the bounty
    /// and the identifier of the bounty within that contract.
    function getBountyInfo(bytes32 bountyHash) external returns (address, bytes32);
}
