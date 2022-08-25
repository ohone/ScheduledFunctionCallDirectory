// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title ScheduledFunctionCallDirectory
/// @author eoghan
/// @notice Allows registering of function calls to be executed beyond a time,
/// with a reward to the maker.
/// Calls will be made in the context of the eventual caller, so scheduling calls
/// that functionally observe msg.sender is not advised.
contract ScheduledFunctionCallDirectory {
    uint256 public number;
    mapping (uint256=>bytes) arguments;
    mapping (uint256=>address) addresses;
    mapping (uint256=>uint256) timestamps;
    mapping (uint256=>uint256) rewards;
    mapping (uint256=>uint256) values;

    event CallScheduled(uint256 timestamp, uint256 reward, uint256 id, bytes args);

    function ScheduleCall(address target, uint256 timestamp, uint256 reward, uint256 value, bytes calldata args) external payable {
        number = number + 1;

        if (msg.value != reward + value){
            revert("Sent ether doesnt equal required ether.");
        }
        rewards[number] = reward;
        values[number] = value;

        arguments[number] = args;
        timestamps[number] = timestamp;
        addresses[number] = target;

        emit CallScheduled(timestamp, reward, number, args);
    }

    function PopCall(uint256 callToPop, address payable recipient) public IsItTime(timestamps[callToPop]) {
        // fetch call data
        uint256 callerReward = rewards[callToPop];
        uint256 value = values[callToPop];
        bytes storage args = arguments[callToPop];
        address addr = addresses[callToPop];

        // act
        (bool functionSuccess,) = addr.call{value: value}(args);
        if (!functionSuccess){
            revert("nope");
        }

        // cleanup, gas $$
        delete rewards[callToPop];
        delete timestamps[callToPop];
        delete addresses[callToPop];
        delete arguments[callToPop];
        delete values[callToPop];
        
        // pay caller's recipient address
        (bool paymentSuccess,) = recipient.call{value: callerReward}("");
        if (!paymentSuccess){
            revert("nope");
        }
    }

    function CallRewards(uint256 call) public view returns (uint256) {
        return rewards[call];
    }

    modifier IsItTime(uint256 time) {
        require(block.timestamp >= time, "Call isn't scheduled yet.");
        _;
    }
}
