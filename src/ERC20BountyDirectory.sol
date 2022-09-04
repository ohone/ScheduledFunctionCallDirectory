import "openzeppelin-contracts/interfaces/IERC20.sol";
import "./IBountyDispenser.sol";

contract ERC20BountyDirectory is IBountyDispenser {
    struct ERC20Bounty {
        address token;
        address from;
        uint256 amount;
        bool reserved;
    }

    mapping(bytes32 => ERC20Bounty) bounties;
    address owner;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    /**
     * @dev See {IBountyDispenser-supplyBounty}.
     */
    function supplyBounty(address token, address from, uint256 amount) external returns (bytes32) {
        IERC20(token).transferFrom(from, address(this), amount);

        bytes32 bountyHash = keccak256(abi.encodePacked(token, from, amount));

        bounties[bountyHash] = ERC20Bounty(token, from, amount, false);

        return bountyHash;
    }

    /**
     * @dev See {IBountyDispenser-reserveBounty}.
     */
    function reserveBounty(bytes32 bountyHash, address onBehalfOf) external onlyOwner {
        ERC20Bounty storage bounty = bounties[bountyHash];
        address bountyOwner = bounty.from;
        require(bountyOwner == onBehalfOf, "user does not have rights to bounty.");

        bounty.reserved = true;
        return;
    }

    /**
     * @dev See {IBountyDispenser-dispenseBountyTo}.
     */
    function dispenseBountyTo(bytes32 bountyHash, address recipient) external onlyOwner {
        ERC20Bounty storage bounty = bounties[bountyHash];

        uint256 amount = bounty.amount;
        address token = bounty.token;

        delete bounties[bountyHash];

        IERC20(token).transferFrom(address(this), recipient, amount);
    }

    /**
     * @dev See {IBountyDispenser-refundBounty}.
     */
    function refundBounty(bytes32 bountyHash, address recipient) external {
        ERC20Bounty storage bounty = bounties[bountyHash];

        address bountyOwner = bounty.from;
        require(bountyOwner == msg.sender, "sender doesn't have rights to this bounty");
        bool bountyReserved = bounty.reserved;
        require(!bountyReserved, "bounty is reserved. Revoke reservation before attempting refund.");

        uint256 amount = bounty.amount;
        address token = bounty.token;

        delete bounties[bountyHash];

        IERC20(token).transferFrom(address(this), recipient, amount);
    }
}
