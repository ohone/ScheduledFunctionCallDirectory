// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract TestERC1155Reciever is ERC1155Receiver {
    bool private shouldAccept = true;

    function setShouldAccept(bool _shouldAccept) external {
        shouldAccept = _shouldAccept;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        view
        returns (bytes4 response)
    {
        if (shouldAccept) {
            return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        }
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        view
        returns (bytes4 response)
    {
        if (shouldAccept) {
            return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        }
    }
}
