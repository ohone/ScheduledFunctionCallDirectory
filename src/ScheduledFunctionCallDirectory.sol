// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/utils/ERC721Holder.sol";

/// @title ScheduledFunctionCallDirectory
/// @author eoghan
/// @notice Allows registering of function calls to be executed beyond a time,
/// with a reward to the maker.
/// Calls will be made in the context of the eventual caller, so scheduling calls
/// that functionally observe msg.sender is not advised.
contract ScheduledFunctionCallDirectory is ERC721Holder {
    uint256 private index;
    mapping(uint256 => ScheduledCall) private directory;

    struct ScheduledCall {
        bytes arguments;
        address target;
        uint256 timestamp;
        uint256 value;
        uint256 expires;
        address bountyAddress;
        uint256 bountyId;
        address owner;
    }

    event CallScheduled(
        uint256 indexed timestamp,
        uint256 indexed expires,
        uint256 id,
        bytes args,
        address bountyAddress,
        uint256 bountyId
    );

    function scheduleCall(
        address target,
        uint256 timestamp,
        uint256 value,
        bytes calldata args,
        uint256 expires,
        address owner,
        address bountyAddress,
        uint256 bountyId
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
        str.bountyId = bountyId;
        str.bountyAddress = bountyAddress;

        emit CallScheduled(timestamp, expires, index, args, bountyAddress, bountyId);
        IERC721(bountyAddress).safeTransferFrom(owner, address(this), bountyId, "");
        return index;
    }

    function PopCall(uint256 callToPop, address recipient) public {
        ScheduledCall storage str = directory[callToPop];

        require(block.timestamp >= str.timestamp, "Call isn't scheduled yet.");
        require(block.timestamp <= str.expires, "Call has expired.");

        // fetch call data
        uint256 bountyId = str.bountyId;
        uint256 value = str.value;
        bytes memory args = str.arguments;
        address addr = str.target;
        address bountyAddress = str.bountyAddress;

        // cleanup, gas $$, prevents reentry risk on following .call
        delete directory[callToPop];

        // act
        (bool functionSuccess,) = addr.call{value: value}(args);
        if (functionSuccess != true) {
            revert("Function call reverted.");
        }

        // transfer bounty to recipient
        IERC721(bountyAddress).safeTransferFrom(address(this), recipient, bountyId, "");
    }

    function RefundSchedule(uint256 callToPop, address recipient) public {
        ScheduledCall storage str = directory[callToPop];
        require(str.owner == msg.sender, "caller not owner of call");

        address owner = str.owner;
        uint256 bountyId = str.bountyId;
        address bountyAddress = str.bountyAddress;
        delete directory[callToPop];

        IERC721(bountyAddress).safeTransferFrom(address(this), str.owner, bountyId);
    }
}
