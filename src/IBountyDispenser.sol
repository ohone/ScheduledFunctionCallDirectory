interface IBountyDispenser {
    function dispenseBountyTo(bytes32 bounty, address recipient) external;
    function refundBounty(bytes32 bounty, address recipient) external;
    function reserveBounty(bytes32 bounty, address onBehalfOf) external;
}
