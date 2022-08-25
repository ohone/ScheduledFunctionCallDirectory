/// @title AuditableContract
/// @author eoghan
/// @notice A contract that emits an event when called, and can be configured
/// to revert.
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