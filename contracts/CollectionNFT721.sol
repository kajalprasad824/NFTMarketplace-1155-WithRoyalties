// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

contract CollectionNFT721 is
    ERC721,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable,
    ERC2981
{
    uint256 private _nextTokenId;

    event Mint(uint tokenId);

    constructor(
        address initialOwner,
        address _royaltyReceiver,
        uint96 _royaltyFeeNumerator,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(initialOwner) {
        // Set default royalty
        _setDefaultRoyalty(_royaltyReceiver, _royaltyFeeNumerator);
    }

    function safeMint(address to, string memory uri)
        public
        onlyOwner
    {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        emit Mint(tokenId);
    }

    //Set token specific royalty
    function setTokenRoyalty(uint _id,address _receiver,uint96 _feeNumerator) public onlyOwner{
        _setTokenRoyalty(_id, _receiver, _feeNumerator);
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
