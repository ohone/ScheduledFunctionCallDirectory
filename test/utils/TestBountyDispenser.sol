// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "src/IBountyDispenser.sol";

contract TestBountyDispenser is IBountyDispenser {
    struct callRecord {
        bytes args;
        address sender;
    }

    mapping(bytes4 => callRecord[]) calls;

    mapping(bytes32 => address) custodians;

    function dispenseBountyTo(bytes32, address) external recordCall(msg.sig, msg.data, msg.sender) {}

    function refundBounty(bytes32, address) external recordCall(msg.sig, msg.data, msg.sender) {}

    function getBountyCustodian(bytes32 bountyHash)
        external
        recordCall(msg.sig, msg.data, msg.sender)
        returns (address)
    {
        return custodians[bountyHash];
    }

    function setBountyCustodianResponse(bytes32 bounty, address addr) external {
        custodians[bounty] = addr;
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

    function registerBounty(bytes32 bountyHash, address registrar) external {}

    modifier recordCall(bytes4 signature, bytes calldata data, address sender) {
        callRecord[] storage functionCalls = calls[signature];
        functionCalls.push(callRecord(data, sender));
        _;
    }
}
