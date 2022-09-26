// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "src/IBountyAdapter.sol";
import "src/IBountyDirectory.sol";
import "../../src/BountyAdapterBase.sol";

contract TestBountyAdapter is BountyAdapterBase {
    constructor() ERC721("ERC1155Bounty", "ERC1155B") {}

    struct callRecord {
        bytes args;
        address sender;
    }

    struct callback {
        bytes call;
        address target;
    }

    mapping(bytes4 => callRecord[]) public calls;
    mapping(uint256 => address) public custodians;
    mapping(bytes4 => callback) public callbacks;

    function burnBounty(uint256, address) external recordCall(msg.sig, msg.data, msg.sender) {}

    function registerBounty(uint256 tokenId, address registrar)
        external
        recordCall(msg.sig, msg.data, msg.sender)
        returns (bytes32)
    {
        return IBountyDirectory(registrar).registerBounty(tokenId, address(this));
    }

    function createBounty(address reciever) external returns (uint256 bountyId) {
        uint256 bountyId = getNewBountyId();
        _mint(reciever, bountyId);
        return bountyId;
    }

    function getBountyCustodian(uint256 bountyId)
        external
        recordCall(msg.sig, msg.data, msg.sender)
        returns (address)
    {
        return custodians[bountyId];
    }

    function bountyExists(uint256 bountyId) public view override returns (bool) {
        return true;
    }

    function getCallRecords(bytes4 signature) external view returns (callRecord[] memory) {
        return calls[signature];
    }

    function assertCalled(bytes4 signature) external view returns (bool) {
        return calls[signature].length > 0;
    }

    function assertCalled(bytes4 signature, bytes memory args, address sender) external view returns (bool) {
        callRecord[] memory callRecords = calls[signature];
        for (uint256 index = 0; index < callRecords.length; index++) {
            callRecord memory record = callRecords[index];
            if (keccak256(record.args) == keccak256(args) && record.sender == sender) {
                return true;
            }
        }

        return false;
    }

    modifier recordCall(bytes4 signature, bytes calldata data, address sender) {
        callRecord[] storage functionCalls = calls[signature];
        functionCalls.push(callRecord(data, sender));
        _;
    }

    function registerCallback(bytes4 signature, address target, bytes memory call) external {
        callbacks[signature] = callback(call, target);
    }
}
