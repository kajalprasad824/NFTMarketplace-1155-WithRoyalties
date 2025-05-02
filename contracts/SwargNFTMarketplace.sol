// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

interface royalty {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address, uint96);
}

contract SwargNFTMarketplace is
    Ownable,
    ReentrancyGuard,
    ERC721Holder,
    ERC1155Holder
{
    using SafeERC20 for IERC20;
    IERC20 USDT;

    ///@notice events for the contract
    event ItemListed(
        address indexed owner,
        address indexed nft,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerItem
    );

    event ItemSold(
        address indexed seller,
        address indexed buyer,
        address indexed nft,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerItem
    );

    event ItemUpdated(
        address indexed owner,
        address indexed nft,
        uint256 tokenId,
        uint256 newPrice
    );

    event ItemCanceled(
        address indexed owner,
        address indexed nft,
        uint256 tokenId
    );

    event UpdatePlatformFee(uint16 platformFee);
    event UpdatePlatformFeeRecipient(address payable platformFeeRecipient);

    /// @notice Structure for listed items
    struct Listing {
        uint256 quantity;
        uint256 pricePerItem;
    }

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    /// @notice NftAddress -> TokenId -> Owner -> Listing item
    mapping(address => mapping(uint256 => mapping(address => Listing)))
        public listings;

    /// @notice Platform fee
    uint16 public platformFee;

    /// @notice Platform fee receipient
    address payable public platformFeeReceipient;

    modifier isListed(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId][_owner];
        require(listing.quantity > 0, "not listed item");
        _;
    }

    modifier notListed(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId][_owner];
        require(listing.quantity == 0, "already listed");
        _;
    }

    modifier validListing(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            require(nft.ownerOf(_tokenId) == _owner, "not owning item");
        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155 nft = IERC1155(_nftAddress);
            require(
                nft.balanceOf(_owner, _tokenId) >= listedItem.quantity,
                "not owning item"
            );
        } else {
            revert("invalid nft address");
        }
        _;
    }

    constructor(
        address _initialOwner,
        address payable _platformFeeReceipient,
        uint16 _platformFee,
        address _usdt
    ) Ownable(_initialOwner) {
        require(
            _platformFee <= 1000,
            "Platform fee can not be greater than 10%"
        );

        platformFee = _platformFee;
        platformFeeReceipient = _platformFeeReceipient;
        USDT = IERC20(_usdt);
    }

    /*
     @notice Method for listing NFT
     @param _nftAddress Address of NFT contract
     @param _tokenId Token ID of NFT
     @param _quantity token amount to list (needed for ERC-1155 NFTs, set as 1 for ERC-721)
     @param _pricePerItem sale price for each iteam
    */
    function listItem(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _pricePerItem
    ) public notListed(_nftAddress, _tokenId, _msgSender()) {
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            require(nft.ownerOf(_tokenId) == _msgSender(), "not owning item");
            require(
                nft.isApprovedForAll(_msgSender(), address(this)),
                "item not approved"
            );
            nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155 nft = IERC1155(_nftAddress);
            require(
                nft.balanceOf(_msgSender(), _tokenId) >= _quantity,
                "must hold enough nfts"
            );
            require(
                nft.isApprovedForAll(_msgSender(), address(this)),
                "item not approved"
            );
            nft.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                _quantity,
                " "
            );
        } else {
            revert("invalid nft address");
        }

        listings[_nftAddress][_tokenId][_msgSender()] = Listing(
            _quantity,
            _pricePerItem
        );
        emit ItemListed(
            _msgSender(),
            _nftAddress,
            _tokenId,
            _quantity,
            _pricePerItem
        );
    }

    /// @notice Method for canceling listed NFT
    function cancelListing(address _nftAddress, uint256 _tokenId)
        external
        nonReentrant
        isListed(_nftAddress, _tokenId, _msgSender())
    {
        Listing memory listedItem = listings[_nftAddress][_tokenId][
            _msgSender()
        ];
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155 nft = IERC1155(_nftAddress);
            nft.safeTransferFrom(
                address(this),
                msg.sender,
                _tokenId,
                listedItem.quantity,
                " "
            );
        } else {
            revert("invalid nft address");
        }

        delete (listings[_nftAddress][_tokenId][_msgSender()]);
        emit ItemCanceled(_msgSender(), _nftAddress, _tokenId);
    }

    /*
     @notice Method for updating listed NFT
     @param _nftAddress Address of NFT contract
     @param _tokenId Token ID of NFT
     @param _newPrice New sale price for each item
    */
    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _newPrice
    ) external nonReentrant isListed(_nftAddress, _tokenId, _msgSender()) {
        Listing storage listedItem = listings[_nftAddress][_tokenId][
            _msgSender()
        ];

        listedItem.pricePerItem = _newPrice;
        emit ItemUpdated(_msgSender(), _nftAddress, _tokenId, _newPrice);
    }

    function _handlePaymentAndTransfer(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _quantity,
        address _seller,
        address _buyer,
        uint256 totalPrice
    ) internal {
        // Calculate royalty
        (address royaltyReceiver, uint256 royaltyAmount) = royalty(_nftAddress)
            .royaltyInfo(_tokenId, totalPrice);

        // Calculate platform fee
        uint256 platformAmount = (totalPrice * platformFee) / 10000;

        // Calculate the seller's share
        uint256 sellerAmount = totalPrice - royaltyAmount - platformAmount;

        // Transfer USDT to respective parties from the owner's account
        USDT.safeTransferFrom(msg.sender, royaltyReceiver, royaltyAmount); // Royalty to creator
        USDT.safeTransferFrom(
            msg.sender,
            platformFeeReceipient,
            platformAmount
        ); // Platform fee to platform
        USDT.safeTransferFrom(msg.sender, _seller, sellerAmount); // Seller receives the rest

        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftAddress).safeTransferFrom(
                address(this),
                _buyer,
                _tokenId
            );
        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155(_nftAddress).safeTransferFrom(
                address(this),
                _buyer,
                _tokenId,
                _quantity,
                ""
            );
        } else {
            revert("Invalid NFT contract");
        }

        // Update or delete listing
        listings[_nftAddress][_tokenId][_seller].quantity -= _quantity;
        if (listings[_nftAddress][_tokenId][_seller].quantity == 0) {
            delete listings[_nftAddress][_tokenId][_seller];
        }

        emit ItemSold(
            _seller,
            _buyer,
            _nftAddress,
            _tokenId,
            _quantity,
            totalPrice
        );
    }

    function buyWithCrypto(
        uint256 _tokenId,
        uint256 _quantity,
        address _nftAddress,
        address _owner
    ) external nonReentrant {
        Listing memory item = listings[_nftAddress][_tokenId][_owner];
        require(item.quantity >= _quantity, "Insufficient quantity");

        uint256 totalPrice = item.pricePerItem * _quantity;

        // Call the common function to handle payment and NFT transfer
        _handlePaymentAndTransfer(
            _nftAddress,
            _tokenId,
            _quantity,
            _owner, // Seller
            msg.sender, // Buyer
            totalPrice
        );
    }

    function buyWithFiat(
        address _nftAddress,
        uint256 _tokenId,
        address _seller,
        address _buyer,
        uint256 _quantity
    ) external onlyOwner nonReentrant {
        // Get the listing details
        Listing memory item = listings[_nftAddress][_tokenId][_seller];
        require(item.quantity >= _quantity, "Not enough quantity");

        uint256 totalPrice = item.pricePerItem * _quantity;

        // Call the common function to handle payment and NFT transfer
        _handlePaymentAndTransfer(
            _nftAddress,
            _tokenId,
            _quantity,
            _seller,
            _buyer,
            totalPrice
        );
    }

    /**
     @notice Method for updating platform fee
     @dev Only admin
     @param _platformFee uint16 the platform fee to set
     */
    function updatePlatformFee(uint16 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }

    /**
     @notice Method for updating platform fee address
     @dev Only admin
     @param _platformFeeRecipient payable address the address to sends the funds to
     */
    function updatePlatformFeeRecipient(address payable _platformFeeRecipient)
        external
        onlyOwner
    {
        platformFeeReceipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }
}
