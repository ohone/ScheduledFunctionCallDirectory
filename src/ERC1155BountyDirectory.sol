import "openzeppelin-contracts/interfaces/IERC1155.sol";
import "openzeppelin-contracts/interfaces/IERC1155Receiver.sol";
import "./IBountyDispenser.sol";

contract ERC1155BountyDirectory is IBountyDispenser, IERC1155Receiver {
    struct ERC1155Bounty {
        address token;
        address from;
        uint256 id;
        uint256 amount;
        bool reserved;
    }

    mapping(bytes32 => ERC1155Bounty) bounties;
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
        IERC1155(token).safeTransferFrom(from, address(this), id, amount, "");

        bytes32 bountyHash = keccak256(abi.encodePacked(token, from, id, amount));

        bounties[bountyHash] = ERC1155Bounty(token, from, id, amount, false);

        return bountyHash;
    }

    /**
     * @dev See {IBountyDispenser-reserveBounty}.
     */
    function reserveBounty(bytes32 bountyHash, address onBehalfOf) external onlyOwner {
        ERC1155Bounty storage bounty = bounties[bountyHash];
        address bountyOwner = bounty.from;
        require(bountyOwner == onBehalfOf, "user does not have rights to bounty.");

        bounty.reserved = true;
        return;
    }

    /**
     * @dev See {IBountyDispenser-dispenseBountyTo}.
     */
    function dispenseBountyTo(bytes32 bountyHash, address recipient) external onlyOwner {
        ERC1155Bounty storage bounty = bounties[bountyHash];

        uint256 amount = bounty.amount;
        uint256 id = bounty.id;
        address token = bounty.token;
        delete bounties[bountyHash];

        IERC1155(token).safeTransferFrom(address(this), recipient, id, amount, "");
    }

    /**
     * @dev See {IBountyDispenser-refundBounty}.
     */
    function refundBounty(bytes32 bountyHash, address recipient) external {
        ERC1155Bounty storage bounty = bounties[bountyHash];

        address bountyOwner = bounty.from;
        require(bountyOwner == msg.sender, "sender doesn't have rights to this bounty");
        bool bountyReserved = bounty.reserved;
        require(!bountyReserved, "bounty is reserved. Revoke reservation before attempting refund.");

        uint256 amount = bounty.amount;
        uint256 id = bounty.id;
        address token = bounty.token;

        delete bounties[bountyHash];

        IERC1155(token).safeTransferFrom(address(this), recipient, id, amount, "");
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    /**
     * @dev See {IERC1155Receiver-onERC1155Received}.
     */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    /**
     * @dev See {IERC1155Receiver-onERC1155BatchReceived}.
     */
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }
}
