// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "src/IBountyDispenser.sol";
import "src/IBountyDirectory.sol";

contract TestBountyDispenser is IBountyDispenser {
    struct callRecord {
        bytes args;
        address sender;
    }

    struct callback {
        bytes call;
        address target;
    }

    mapping(bytes4 => callRecord[]) calls;
    mapping(bytes32 => address) custodians;
    mapping(bytes4 => callback) callbacks;

    function dispenseBountyTo(bytes32, address) external recordCall(msg.sig, msg.data, msg.sender) {
        callback storage thisCallback = callbacks[msg.sig];
        if (thisCallback.target != address(0)) {
            thisCallback.target.call(thisCallback.call);
        }
    }

    function refundBounty(bytes32, address) external recordCall(msg.sig, msg.data, msg.sender) {}

    function registerBounty(bytes32 bountyHash, address registrar)
        external
        recordCall(msg.sig, msg.data, msg.sender)
        returns (bytes32)
    {
        return IBountyDirectory(registrar).registerBounty(bountyHash, address(this));
    }

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

    modifier recordCall(bytes4 signature, bytes calldata data, address sender) {
        callRecord[] storage functionCalls = calls[signature];
        functionCalls.push(callRecord(data, sender));
        _;
    }

    function registerCallback(bytes4 signature, address target, bytes memory call) external {
        callbacks[signature] = callback(call, target);
    }
}
