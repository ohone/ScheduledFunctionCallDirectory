// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title ScheduledFunctionCallDirectory
/// @author eoghan
/// @notice Allows registering of function calls to be executed beyond a time,
/// with a reward to the maker.
/// Calls will be made in the context of the eventual caller, so scheduling calls
/// that functionally observe msg.sender is not advised.
contract ScheduledFunctionCallDirectory {
    uint256 public index;

    mapping (uint256=>ScheduledCall) directory;

    struct ScheduledCall{
        bytes arguments;
        address target;
        uint256 timestamp;
        uint256 reward;
        uint256 value;
    }

    event CallScheduled(uint256 timestamp, uint256 reward, uint256 id, bytes args);

    function ScheduleCall(address target, uint256 timestamp, uint256 reward, uint256 value, bytes calldata args) external payable {
        index = index + 1;

        if (msg.value != reward + value){
            revert("Sent ether doesnt equal required ether.");
        }

        ScheduledCall storage str = directory[index];
        str.arguments = args;
        str.target = target;
        str.timestamp = timestamp;
        str.reward = reward;
        str.value = value;

        emit CallScheduled(timestamp, reward, index, args);
    }

    function PopCall(uint256 callToPop, address payable recipient) public {
        
        ScheduledCall storage str = directory[callToPop];
        
        require(block.timestamp >= str.timestamp, "Call isn't scheduled yet.");
        
        // fetch call data
        uint256 callerReward = str.reward;
        uint256 value = str.value;
        bytes memory args = str.arguments;
        address addr = str.target;

        // cleanup, gas $$, prevents replay
        delete directory[index];

        // act
        (bool functionSuccess,) = addr.call{value: value}(args);
        if (functionSuccess != true){
            revert("Function call reverted.");
        }

        // pay caller's recipient address
        (bool paymentSuccess,) = recipient.call{value: callerReward}("");
        if (!paymentSuccess){
            revert("nope");
        }
    }

    function CallRewards(uint256 call) public view returns (uint256) {
        return directory[call].reward;
    }
}
