// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC20.sol";

/// @title ScheduledFunctionCallDirectory
/// @author eoghan
/// @notice Allows registering of function calls to be executed beyond a time,
/// with a reward to the maker.
/// Calls will be made in the context of the eventual caller, so scheduling calls
/// that functionally observe msg.sender is not advised.
contract ScheduledFunctionCallDirectory {
    uint256 public index;

    mapping(uint256 => ScheduledCall) directory;

    struct ScheduledCall {
        bytes arguments;
        address target;
        uint256 timestamp;
        address rewardToken;
        uint256 rewardAmount;
        uint256 value;
        uint256 expires;
    }

    event CallScheduled(
        uint256 timestamp, uint256 expires, address rewardToken, uint256 rewardAmount, uint256 id, bytes args
    );

    function ScheduleCall(
        address target,
        uint256 timestamp,
        address rewardToken,
        uint256 rewardAmount,
        address rewardPayer,
        uint256 value,
        bytes calldata args,
        uint256 expires
    )
        external
        payable
    {
        require(expires > block.timestamp, "call expiry timestamp cannot be in the past");

        index = index + 1;

        if (msg.value != value) {
            revert("Sent ether doesnt equal required ether.");
        }

        bool success = IERC20(rewardToken).transferFrom(rewardPayer, address(this), rewardAmount);
        if (!success) {
            revert("Transfer of rewardToken failed.");
        }

        ScheduledCall storage str = directory[index];
        str.arguments = args;
        str.target = target;
        str.timestamp = timestamp;
        str.rewardToken = rewardToken;
        str.rewardAmount = rewardAmount;
        str.value = value;
        str.expires = expires;

        emit CallScheduled(timestamp, expires, rewardToken, rewardAmount, index, args);
    }

    function PopCall(uint256 callToPop, address recipient) public {
        ScheduledCall storage str = directory[callToPop];

        require(block.timestamp >= str.timestamp, "Call isn't scheduled yet.");
        require(block.timestamp <= str.expires, "Call has expired.");

        // fetch call data
        uint256 callerRewardAmount = str.rewardAmount;
        address callerRewardToken = str.rewardToken;
        uint256 value = str.value;
        bytes memory args = str.arguments;
        address addr = str.target;

        // cleanup, gas $$, prevents reentry on ERC20.transfer
        delete directory[index];

        // act
        (bool functionSuccess,) = addr.call{value: value}(args);
        if (functionSuccess != true) {
            revert("Function call reverted.");
        }

        // pay caller's recipient address
        bool transferSuccess = IERC20(callerRewardToken).transfer(recipient, callerRewardAmount);
        if (!transferSuccess) {
            revert("transfer of reward token to recipient failed");
        }
    }

    function CallRewards(uint256 call) public view returns (address, uint256) {
        return (directory[call].rewardToken, directory[call].rewardAmount);
    }
}
