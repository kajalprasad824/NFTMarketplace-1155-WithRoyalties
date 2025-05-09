// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CollectionNFT721.sol";
import "./CollectionNFT1155.sol";

contract NFTCollectionFactory {
    enum NFTType {
        ERC721,
        ERC1155
    }

    event CollectionDeployed(address indexed user, address collectionAddress, NFTType nftType);

    mapping(address => address[]) public userCollections;

    function deployCollection(
        NFTType nftType,
        string calldata _name,
        string calldata _symbol
    ) external returns (address collectionAddress) {
        if (nftType == NFTType.ERC721) {
            CollectionNFT721 newERC721 = new CollectionNFT721(
                msg.sender,
                _name,
                _symbol
            );
            collectionAddress = address(newERC721);
        } else{
            CollectionNFT1155 newERC1155 = new CollectionNFT1155(
                msg.sender,
                _name,
                _symbol
                
            );
            collectionAddress = address(newERC1155);
        }

        userCollections[msg.sender].push(collectionAddress);
        emit CollectionDeployed(msg.sender, collectionAddress, nftType);
        return collectionAddress;
    }

    function getUserCollections(address user) external view returns (address[] memory) {
        return userCollections[user];
    }
}
