// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract CollectionNFT1155 is ERC1155, Ownable, ERC2981 {
    uint256 private _nextTokenId;
    string public name;
    string public symbol;

    event Mint(uint _id,uint _amount);
    mapping(uint256 => string) private _tokenURIs;

    constructor(
        address initialOwner,
        string memory _name,
        string memory _symbol,
        address _royaltyReceiver,
        uint96 _royaltyFeeNumerator
        
    ) ERC1155("") Ownable(initialOwner) {
        name = _name;
        symbol = _symbol;

        // Set default royalty
        _setDefaultRoyalty(_royaltyReceiver, _royaltyFeeNumerator);
    }

    function mint(
        address account,
        uint256 amount,
        string calldata _uri,
        address _royaltyReceiver,
        uint96 _feeNumerator
    ) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _mint(account, tokenId, amount, " ");
        _setTokenURI(tokenId, _uri);
        _setTokenRoyalty(tokenId, _royaltyReceiver, _feeNumerator);
        emit Mint(tokenId, amount);
    }

    function _setTokenURI(uint256 _id, string calldata _uri) internal {
        _tokenURIs[_id] = _uri;
    }

    // Override uri to return token-specific URI
    function uri(uint256 _id) public view override returns (string memory) {
        require(bytes(_tokenURIs[_id]).length > 0, "URI not set for token");
        return _tokenURIs[_id];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC2981)
        returns (bool)
    {
        return
            ERC1155.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }
}
