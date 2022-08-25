/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract AuditableContract {

    bool private reverts;

    constructor(bool shouldRevert){
        reverts = shouldRevert;
    }

    event Called(uint256 argument1, uint256 argument2);

    function payableFunction(uint256 argument1, uint256 argument2) external payable {
        if (reverts){
            revert("reverts!");
        }

        emit Called(argument1, argument2);
    }
}