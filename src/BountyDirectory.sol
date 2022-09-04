interface IBountyDirectory {
    function registerBounty(bytes32 bountyHash, address bountyContract) external;
    function deregisterBounty(bytes32 bountyHash) external;
    function bountyAddress(bytes32 bountyHash) external returns (address);
}

contract BountyDirectory is IBountyDirectory {
    mapping(bytes32 => address) bountyContracts;

    modifier onlyContract(address bountyContract) {
        require(msg.sender == bountyContract, "Caller is not holder of the bounty.");
        _;
    }

    /**
     * @dev See {IBountyDirectory-registerBounty}.
     */
    function registerBounty(bytes32 bountyHash, address bountyContract) external onlyContract(bountyContract) {
        bountyContracts[bountyHash] = bountyContract;
    }

    /**
     * @dev See {IBountyDirectory-deregisterBounty}.
     */
    function deregisterBounty(bytes32 bountyHash) external onlyContract(bountyContracts[bountyHash]) {
        delete bountyContracts[bountyHash];
    }

    /**
     * @dev See {IBountyDirectory-bountyAddress}.
     */
    function bountyAddress(bytes32 bountyHash) external view returns (address) {
        return bountyContracts[bountyHash];
    }
}
