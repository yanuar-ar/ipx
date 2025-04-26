// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {RoyaltyTokenFactory} from "./RoyaltyTokenFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IPX is ERC721 {
    error InsufficientFunds();
    error InvalidTokenId();

    struct IP {
        string title;
        string description;
        string category;
    }

    struct Rent {
        uint256 expiresAt;
        address renter;
    }

    uint256 public nextTokenId = 1;
    RoyaltyTokenFactory public royaltyTokenFactory;

    // id IP => ipData
    mapping(uint256 => IP) public ipData;

    // id IP => user => data rent
    mapping(uint256 => mapping(address => Rent)) public rents;

    // id IP => parent IP
    mapping(uint256 => uint256) public parentIds;

    // id IP => royalty token
    mapping(uint256 => address) public royaltyTokens;

    constructor(address _royaltyTokenFactory) ERC721("IPX", "IPX") {
        royaltyTokenFactory = RoyaltyTokenFactory(_royaltyTokenFactory);
    }

    function registerIP(string memory title, string memory description, string memory category)
        public
        returns (uint256)
    {
        uint256 tokenId = nextTokenId++;
        ipData[tokenId] = IP(title, description, category);
        _safeMint(msg.sender, tokenId);

        address rt = royaltyTokenFactory.createRoyaltyToken(title, title, tokenId);
        royaltyTokens[tokenId] = rt;
        IERC20(rt).transfer(msg.sender, 100_000_000e18);
        return tokenId;
    }

    function buyIP(uint256 tokenId) public payable {
        uint256 price = 1000;
        if (msg.value < price) revert InsufficientFunds();
        address owner = ownerOf(tokenId);
        _transfer(owner, msg.sender, tokenId);
    }

    function rentIP(uint256 tokenId) public payable {
        if (tokenId > nextTokenId) revert InvalidTokenId();
        uint256 price = 1000;
        uint256 duration = 30 days;
        if (msg.value < price) revert InsufficientFunds();
        rents[tokenId][msg.sender] = Rent({expiresAt: block.timestamp + duration, renter: msg.sender});
    }

    function remixIP(string memory title, string memory description, string memory category, uint256 parentId)
        public
        returns (uint256)
    {
        if (parentId > nextTokenId) revert InvalidTokenId();

        uint256 parentRoyaltyRightPercentage = 20; // equal to 20%
        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);
        ipData[tokenId] = IP(title, description, category);
        parentIds[tokenId] = parentId;

        address rt = royaltyTokenFactory.createRoyaltyToken(title, title, tokenId);
        royaltyTokens[tokenId] = rt;
        uint256 parentRoyaltyRight = 100_000_000e18 * parentRoyaltyRightPercentage / 100;
        uint256 creatorRoyaltyRight = 100_000_000e18 - parentRoyaltyRight;

        // transfer to parent royalty token
        IERC20(rt).transfer(royaltyTokens[parentId], parentRoyaltyRight);

        // transfer to creator
        IERC20(rt).transfer(msg.sender, creatorRoyaltyRight);

        return tokenId;
    }
}
