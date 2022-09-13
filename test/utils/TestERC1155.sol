// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC1155/ERC1155.sol";

contract TestERC1155 is ERC1155 {
    constructor(string memory uri) ERC1155(uri) {}

    address private callbackTarget;
    bytes private callbackArgs;

    function mint(address to, uint256 id, uint256 amount, bytes memory data) public {
        _mint(to, id, amount, data);
    }

    function registerPostTokenTransferCallback(address target, bytes memory args) public {
        callbackTarget = target;
        callbackArgs = args;
    }

    function _afterTokenTransfer(address, address, address, uint256[] memory, uint256[] memory, bytes memory)
        internal
        override
    {
        if (callbackTarget != address(0)) {
            callbackTarget.call(callbackArgs);
        }
    }
}
