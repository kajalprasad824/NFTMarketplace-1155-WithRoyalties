// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

contract CollectionNFT721 is ERC721, ERC721URIStorage, Ownable, ERC2981 {
    uint256 private _nextTokenId;

    event Mint(uint256 tokenId);

    constructor(
        address initialOwner,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(initialOwner) {
    
    }

    function safeMint(
        address to,
        string memory uri,
        address _royaltyReceiver,
        uint96 _feeNumerator
    ) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _setTokenRoyalty(tokenId, _royaltyReceiver, _feeNumerator);
        emit Mint(tokenId);
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
