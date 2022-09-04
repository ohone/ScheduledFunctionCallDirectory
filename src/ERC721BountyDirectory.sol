import "openzeppelin-contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/interfaces/IERC721Receiver.sol";
import "./IBountyDispenser.sol";

contract ERC721BountyDirectory is IBountyDispenser, IERC721Receiver {
    struct ERC721Bounty {
        address token;
        address from;
        uint256 id;
        bool reserved;
    }

    mapping(bytes32 => ERC721Bounty) bounties;
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
    function supplyBounty(address token, address from, uint256 id, uint256 amount) external returns (bytes32) {
        IERC721(token).safeTransferFrom(from, address(this), id);

        bytes32 bountyHash = keccak256(abi.encodePacked(token, from, id, amount));

        bounties[bountyHash] = ERC721Bounty(token, from, id, false);

        return bountyHash;
    }

    /**
     * @dev See {IBountyDispenser-reserveBounty}.
     */
    function reserveBounty(bytes32 bountyHash, address onBehalfOf) external onlyOwner {
        ERC721Bounty storage bounty = bounties[bountyHash];
        address bountyOwner = bounty.from;
        require(bountyOwner == onBehalfOf, "user does not have rights to bounty.");

        bounty.reserved = true;
        return;
    }

    /**
     * @dev See {IBountyDispenser-dispenseBountyTo}.
     */
    function dispenseBountyTo(bytes32 bountyHash, address recipient) external onlyOwner {
        ERC721Bounty storage bounty = bounties[bountyHash];

        uint256 id = bounty.id;
        address token = bounty.token;
        delete bounties[bountyHash];

        IERC721(token).safeTransferFrom(address(this), recipient, id);
    }

    /**
     * @dev See {IBountyDispenser-refundBounty}.
     */
    function refundBounty(bytes32 bountyHash, address recipient) external {
        ERC721Bounty storage bounty = bounties[bountyHash];

        address bountyOwner = bounty.from;
        require(bountyOwner == msg.sender, "sender doesn't have rights to this bounty");
        bool bountyReserved = bounty.reserved;
        require(!bountyReserved, "bounty is reserved. Revoke reservation before attempting refund.");

        uint256 id = bounty.id;
        address token = bounty.token;

        delete bounties[bountyHash];

        IERC721(token).safeTransferFrom(address(this), recipient, id);
    }

    /**
     * @dev See {IERC721-onERC721Received}.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
