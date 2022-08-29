# Scheduled Function Call Directory 

A small contract to enable scheduling contract calls in the future, to be executed by third parties. 

Scheduled calls are incentivised with a bounty, paid to the eventual caller. The consistent format of calls, emitting scheduled calls as events, makes the job of executing these function calls on-time (and collecting the bounty!) easy for searchers.

## Scheduling a Call
>`ScheduleCall(address target,
        uint256 timestamp,
        uint256 reward,
        uint256 value,
        bytes calldata args,
        uint256 expires)`

To schedule a call to be executed some time in the future, the user must provide a `target` address of the contract to execute, `timestamp` (unix seconds) for when the call becomes executable, a `reward` in wei to pay to the eventual caller, a `value` that the scheduled contract call should pass, `args` calldata detailing the function to call and an `expires` timestamp, dictating when the function call becomes invalid.

### Notes
- The value of the transaction must equal exactly `value + reward`. A the user that eventually executes the call pays only gas.
- If the function call need not expire before its called, `expires` should be set to the max value `0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff`.
- The eventual transaction's `tx.origin` will differ from your own address. If it's possible that the function call observes `tx.origin` (be careful with proxy contracts - functionality can change!), it would be better to look into another solution - the value of `tx.origin` in your eventual function call should not be assumed to be any specific value.

## Executing a Scheduled Call

>`PopCall(uint256 callId, address payable recipient)`

Executing a scheduled call requires a user supply `callId` of the scheduled call to execute, and an address `recipient` to recieve the bounty.

### Notes
- By calling `PopCall` you will be signing and executing a transaction on behalf of another agent. This could include fraudulent, unethical or unsafe contract calls. Verify the transaction before you execute.