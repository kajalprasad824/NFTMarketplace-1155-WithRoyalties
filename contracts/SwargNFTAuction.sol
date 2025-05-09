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

contract SwargNFTAuction is
    Ownable,
    ReentrancyGuard,
    ERC721Holder,
    ERC1155Holder
{
    using SafeERC20 for IERC20;

    event AuctionCreated(
        address indexed nftAddress,
        uint256 tokenId,
        uint256 quantity
    );

    event UpdateAuctionEndTime(
        address indexed nftAddress,
        uint256 tokenId,
        uint256 endTime
    );

    event UpdateAuctionStartTime(
        address indexed nftAddress,
        uint256 tokenId,
        uint256 startTime
    );

    event UpdateAuctionReservePrice(
        address indexed nftAddress,
        uint256 tokenId,
        uint256 reservePrice
    );

    event UpdatePlatformFee(uint256 platformFee);

    event UpdatePlatformFeeRecipient(address platformFeeRecipient);

    event BidPlaced(
        address indexed nftAddress,
        uint256 tokenId,
        address indexed bidder,
        uint256 bid
    );

    event BidRefunded(
        address indexed nftAddress,
        uint256 tokenId,
        address indexed bidder,
        uint256 bid
    );

    event AuctionResulted(
        address indexed nftAddress,
        uint256 tokenId,
        uint256 quantity,
        address indexed winner,
        uint256 winningbid
    );

    event AuctionCancelled(
        address indexed nftAddress,
        uint256 tokenId,
        address indexed owner
    );

    event UpdateMinBidIncrementPercent(uint256 minBidIncrementPercent);

    /// @notice Parameters of an auction
    struct Auction {
        uint256 quantity;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
    }
    /// @notice NFT Address -> Token ID -> Auction Parameters
    mapping(address => mapping(uint256 => mapping (address => Auction))) public auctions;

    struct BidderInfo {
        uint256 highBid;
        address bidderAddress;
    }
    /// @notice NFT Address -> Token ID -> Bidding Info
    mapping(address => mapping(uint256 => BidderInfo)) public bidderInfo;

    IERC20 USDT;

    /// @notice Platform fee
    uint256 public platformFee;

    /// @notice Platform fee receipient
    address public platformFeeReceipient;

    uint256 public minBidIncrementPercent;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    modifier onlyValidAuction(address nftAddress, uint256 tokenId,address _owner) {
        Auction memory auction = auctions[nftAddress][tokenId][_owner];

        require(auction.endTime != 0, "No such auction exists");
        require(
            block.timestamp < auction.startTime,
            "Cannot change anything after auction has started"
        );
        _;
    }

    modifier onlyValidOwner(address nftAddress, uint256 tokenId,address _owner) {
        Auction memory auction = auctions[nftAddress][tokenId][_owner];

        require(auction.endTime != 0, "No such auction exists");
        require(
            block.timestamp >= auction.endTime,
            "Only call after the auction end time"
        );
        _;
    }

    constructor(
        address _initialOwner,
        address _platformFeeReceipient,
        uint16 _platformFee,
        uint256 _minBidIncrementPercent,
        address _usdt
    ) Ownable(_initialOwner) {
        require(
            _platformFee <= 1000,
            "Platform fee can not be greater than 10%"
        );

        platformFee = _platformFee;
        platformFeeReceipient = _platformFeeReceipient;
        USDT = IERC20(_usdt);
        minBidIncrementPercent = _minBidIncrementPercent;
    }

    function createAuction(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _reservePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) public {
        // Ensure this contract is approved to move the token
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

        // Ensure a token cannot be re-listed if already on auction
        require(
            auctions[_nftAddress][_tokenId][msg.sender].endTime == 0,
            "auction already exist"
        );

        // Check end time not before start time and that end is in the future
        require(
            _startTimestamp > block.timestamp,
            "start time should be greater than current time"
        );

        require(
            _endTimestamp > _startTimestamp,
            "end time must be greater than start"
        );

        // Setup the auction
        auctions[_nftAddress][_tokenId][msg.sender] = Auction({
            quantity: _quantity,
            reservePrice: _reservePrice,
            startTime: _startTimestamp,
            endTime: _endTimestamp
        });

        emit AuctionCreated(_nftAddress, _tokenId, _quantity);
    }

    function placeBid(
        address _nftAddress,
        address _owner,
        uint256 _tokenId,
        uint256 _bidAmount
    ) public nonReentrant {
        Auction storage auction = auctions[_nftAddress][_tokenId][_owner];
        BidderInfo storage biddingInfo = bidderInfo[_nftAddress][_tokenId];

        require(auction.endTime != 0, "No such auction exists");

        // Ensure auction is in flight
        require(
            block.timestamp >= auction.startTime &&
                block.timestamp <= auction.endTime,
            "bidding outside of the auction window"
        );

        require(
            biddingInfo.bidderAddress != msg.sender,
            "You are already the higher bidder"
        );

        require(
            isValidBid(_nftAddress, _tokenId, _bidAmount, auction.reservePrice),
            "Bid too low"
        );

        if (biddingInfo.bidderAddress != address(0)) {
            USDT.safeTransferFrom(
                address(this),
                biddingInfo.bidderAddress,
                biddingInfo.highBid
            );
        }

        emit BidRefunded(
            _nftAddress,
            _tokenId,
            biddingInfo.bidderAddress,
            biddingInfo.highBid
        );

        biddingInfo.bidderAddress = msg.sender;
        biddingInfo.highBid = _bidAmount;

        USDT.safeTransferFrom(
            biddingInfo.bidderAddress,
            address(this),
            biddingInfo.highBid
        );

        emit BidPlaced(
            _nftAddress,
            _tokenId,
            biddingInfo.bidderAddress,
            biddingInfo.highBid
        );
    }

    function resultAuction(address _nftAddress, uint256 _tokenId)
        public
        nonReentrant onlyValidOwner(_nftAddress, _tokenId, msg.sender)
    {
        Auction memory auction = auctions[_nftAddress][_tokenId][msg.sender];
        BidderInfo memory bid = bidderInfo[_nftAddress][_tokenId];
  
        require(
            block.timestamp >= auction.endTime,
            "Only call after the auction end"
        );

        // Delete storage early to prevent reentrancy
        delete auctions[_nftAddress][_tokenId][msg.sender];
        delete bidderInfo[_nftAddress][_tokenId];

        // === Case 1: No valid bid ===
        if (bid.bidderAddress == address(0)) {
            // Return NFT back to seller
            if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
                IERC721(_nftAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _tokenId
                );
            } else if (
                IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
            ) {
                IERC1155(_nftAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _tokenId,
                    auction.quantity,
                    ""
                );
            } else {
                revert("Invalid NFT contract");
            }

            emit AuctionResulted(
                _nftAddress,
                _tokenId,
                auction.quantity,
                address(0),
                0
            );
            return;
        }

        // === Case 2: Valid bid exists ===
        (address royaltyReceiver, uint256 royaltyAmount) = royalty(_nftAddress)
            .royaltyInfo(_tokenId, bid.highBid);

        uint256 platformAmount = (bid.highBid * platformFee) / 10000;

        // Calculate the seller's share
        uint256 sellerAmount = bid.highBid - royaltyAmount - platformFee;

        // Transfer USDT to respective parties
        USDT.safeTransferFrom(address(this), royaltyReceiver, royaltyAmount); // Royalty to creator
        USDT.safeTransferFrom(
            address(this),
            platformFeeReceipient,
            platformAmount
        ); // Platform fee to platform
        USDT.safeTransferFrom(address(this), msg.sender, sellerAmount); // Seller receives the rest

        // Transfer NFT to winning bidder
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftAddress).safeTransferFrom(
                address(this),
                bid.bidderAddress,
                _tokenId
            );
        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155(_nftAddress).safeTransferFrom(
                address(this),
                bid.bidderAddress,
                _tokenId,
                auction.quantity,
                ""
            );
        }

        emit AuctionResulted(_nftAddress, _tokenId, auction.quantity, bid.bidderAddress, bid.highBid);
    }

    function isValidBid(
        address nftAddress,
        uint256 tokenId,
        uint256 newBidAmount,
        uint256 _reservePrice
    ) public view returns (bool) {
        uint256 currentBid = bidderInfo[nftAddress][tokenId].highBid;

        if (currentBid == 0) {
            // First bid: must be at least the reserve price
            return newBidAmount >= _reservePrice;
        }

        // Subsequent bids: must exceed current bid by minimum increment
        uint256 minRequired = currentBid +
            ((currentBid * minBidIncrementPercent) / 10000);
        return newBidAmount >= minRequired;
    }

    function cancelAuction(address _nftAddress, uint256 _tokenId)
        public
        onlyValidAuction(_nftAddress, _tokenId,msg.sender)
    {
        Auction memory auction = auctions[_nftAddress][_tokenId][msg.sender];

        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155 nft = IERC1155(_nftAddress);

            nft.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                auction.quantity,
                " "
            );
        } else {
            revert("invalid nft address");
        }

        // Optional: cleanup any bids (though there should be none)
        delete auctions[_nftAddress][_tokenId][msg.sender];

        emit AuctionCancelled(_nftAddress, _tokenId, msg.sender);
    }

    /**
     @notice Update the current end time for an auction
     @dev Only admin
     @dev Auction must exist
     @param _nftAddress Address
     @param _tokenId Token ID of the NFT being auctioned
     @param _endTimestamp New end time (unix epoch in seconds)
     */
    function updateAuctionEndTime(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _endTimestamp
    ) public onlyValidAuction(_nftAddress, _tokenId,msg.sender) {
        Auction storage auction = auctions[_nftAddress][_tokenId][msg.sender];
        require(
            auction.startTime < _endTimestamp,
            "end time must be greater than start"
        );

        auction.endTime = _endTimestamp;
        emit UpdateAuctionEndTime(_nftAddress, _tokenId, _endTimestamp);
    }

    /**
     @notice Update the current start time for an auction
     @dev Only admin
     @dev Auction must exist
     @param _nftAddress ddress
     @param _tokenId Token ID of the NFT being auctioned
     @param _startTime New start time (unix epoch in seconds)
     */
    function updateAuctionStartTime(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _startTime
    ) public onlyValidAuction(_nftAddress, _tokenId,msg.sender) {
        Auction storage auction = auctions[_nftAddress][_tokenId][msg.sender];

        require(
            _startTime < auction.endTime,
            "start time must be before end time"
        );
        auction.startTime = _startTime;
        emit UpdateAuctionStartTime(_nftAddress, _tokenId, _startTime);
    }

    /**
     @notice Update the current reserve price for an auction
     @dev Only admin
     @dev Auction must exist
     @param _nftAddress ERC 721 Address
     @param _tokenId Token ID of the NFT being auctioned
     @param _reservePrice New Ether reserve price (WEI value)
     */
    function updateAuctionReservePrice(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _reservePrice
    ) public onlyValidAuction(_nftAddress, _tokenId,msg.sender) {
        Auction storage auction = auctions[_nftAddress][_tokenId][msg.sender];
        auction.reservePrice = _reservePrice;
        emit UpdateAuctionReservePrice(_nftAddress, _tokenId, _reservePrice);
    }

    /**
     @notice Method for updating platform fee
     @dev Only admin
     @param _platformFee uint256 the platform fee to set
     */
    function updatePlatformFee(uint256 _platformFee) external onlyOwner {
        require(
            _platformFee <= 1000,
            "Platform fee can not be greater than 10%"
        );
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
        require(_platformFeeRecipient != address(0), "zero address");

        platformFeeReceipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    function updateMinBidIncrementPercent(uint256 _minBidIncrementPercent)
        public
        onlyOwner
    {
        require(
            _minBidIncrementPercent <= 1000,
            "Platform fee can not be greater than 10%"
        );
        minBidIncrementPercent = _minBidIncrementPercent;
        emit UpdateMinBidIncrementPercent(minBidIncrementPercent);
    }
}

//000000000000000000
