// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketPosition is ERC721, Ownable {
    address public market;
    uint256 private _nextTokenId = 1;

    constructor() ERC721("Market Position", "POS") Ownable(msg.sender) {}

    function setMarket(address _market) external onlyOwner {
        market = _market;
    }

    function mint(address to) external returns (uint256) {
        require(msg.sender == market, "Only market can mint");
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}