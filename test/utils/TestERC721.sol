// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    address private callbackTarget;
    bytes private callbackArgs;

    function mint(address reciever, uint256 tokenId) public {
        _mint(reciever, tokenId);
    }

    function registerPostTokenTransferCallback(address target, bytes memory args) public {
        callbackTarget = target;
        callbackArgs = args;
    }

    function _afterTokenTransfer(address, address, uint256) internal override {
        if (callbackTarget != address(0)) {
            callbackTarget.call(callbackArgs);
        }
    }
}
