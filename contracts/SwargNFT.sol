// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract SwargNFT is ERC1155, Ownable, ERC2981 {

    string public name;
    string public symbol;

    event Mint(uint _id,uint _amount);
    mapping(uint256 => string) private _tokenURIs;

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyReceiver,
        uint96 _royaltyFeeNumerator,
        address _initialOwner
    ) ERC1155("") Ownable(_initialOwner) {
        name = _name;
        symbol = _symbol;
        
        // Set default royalty
        _setDefaultRoyalty(_royaltyReceiver, _royaltyFeeNumerator);
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _amount,
        string calldata _uri
    ) public onlyOwner {
        _mint(_to, _id, _amount, " ");
        _setTokenURI(_id, _uri);
        emit Mint(_id, _amount);
    }

    function _setTokenURI(uint256 _id, string calldata _uri) internal {
        _tokenURIs[_id] = _uri;
    }

    //Set token specific royalty
    function setTokenRoyalty(uint _id,address _receiver,uint96 _feeNumerator) public onlyOwner{
        _setTokenRoyalty(_id, _receiver, _feeNumerator);
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
