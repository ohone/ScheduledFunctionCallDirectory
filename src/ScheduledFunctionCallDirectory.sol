// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC20.sol";
import "./BountyDirectory.sol";

/// @title ScheduledFunctionCallDirectory
/// @author eoghan
/// @notice Allows registering of function calls to be executed beyond a time,
/// with a reward to the maker.
/// Calls will be made in the context of the eventual caller, so scheduling calls
/// that functionally observe msg.sender is not advised.
contract ScheduledFunctionCallDirectory {
    uint256 private index;
    mapping(uint256 => ScheduledCall) private directory;
    BountyDirectory public bounties;

    constructor() {
        bounties = new BountyDirectory();
    }

    struct ScheduledCall {
        bytes arguments;
        address target;
        uint256 timestamp;
        uint256 value;
        uint256 expires;
        address owner;
        bytes32 bounty;
    }

    event CallScheduled(uint256 indexed timestamp, uint256 indexed expires, uint256 id, bytes args, bytes32 bounty);

    function scheduleCall(
        address target,
        uint256 timestamp,
        uint256 value,
        bytes calldata args,
        uint256 expires,
        address owner,
        bytes32 bounty
    )
        external
        payable
        returns (uint256)
    {
        // call isn't expired already
        require(expires > block.timestamp, "expiry cannot be in the past");

        // call includes ether amount specified to be sent with call
        if (msg.value != value) {
            revert("Sent ether doesnt equal required ether");
        }

        // increment to get identifier for new call
        index = index + 1;

        ScheduledCall storage str = directory[index];
        str.arguments = args;
        str.target = target;
        str.timestamp = timestamp;
        str.value = value;
        str.expires = expires;
        str.owner = owner;
        str.bounty = bounty;

        emit CallScheduled(timestamp, expires, index, args, bounty);

        return index;
    }

    function PopCall(uint256 callToPop, address recipient) public {
        ScheduledCall storage str = directory[callToPop];

        require(block.timestamp >= str.timestamp, "Call isn't scheduled yet.");
        require(block.timestamp <= str.expires, "Call has expired.");

        // fetch call data
        bytes32 bounty = str.bounty;
        uint256 value = str.value;
        bytes memory args = str.arguments;
        address addr = str.target;

        // cleanup, gas $$, prevents reentry risk on following .call
        delete directory[callToPop];

        // act
        (bool functionSuccess,) = addr.call{value: value}(args);
        if (functionSuccess != true) {
            revert("Function call reverted.");
        }

        // fetch bounty
        (address bountyContract, uint256 bountyHash) = bounties.getBountyInfo(bounty);
        IBountyDispenser dispenser = IBountyDispenser(bountyContract);

        // deregister bounty
        bounties.deregisterBounty(bounty);

        // pay bounty to recipient
        dispenser.safeTransferFrom(address(this), recipient, bountyHash, "");
    }

    function RefundSchedule(uint256 callToPop, address recipient) public {
        ScheduledCall storage str = directory[callToPop];
        require(str.owner == msg.sender, "caller not owner of call");

        bytes32 bounty = str.bounty;

        delete directory[callToPop];

        // fetch bounty
        (address bountyContract, uint256 bountyHash) = bounties.getBountyInfo(bounty);
        IBountyDispenser dispenser = IBountyDispenser(bountyContract);
        // deregister bounty
        bounties.deregisterBounty(bounty);

        // pay bounty to recipient
        dispenser.safeTransferFrom(address(this), recipient, bountyHash, "");
    }

    function CallRewards(uint256 call) public view returns (address, uint256) {
        return bounties.getBountyInfo(directory[call].bounty);
    }
}
