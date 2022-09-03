import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    address private callbackTarget;
    bytes private callbackArgs;

    function mint(address reciever, uint256 amount) public {
        _mint(reciever, amount);
    }

    function registerPostTokenTransferCallback(address target, bytes memory args) public {
        callbackTarget = target;
        callbackArgs = args;
    }

    function _afterTokenTransfer(address, address, uint256) internal override {
        if (callbackTarget != address(0)) {
            callbackTarget.call(callbackArgs);
        }
    }
}
