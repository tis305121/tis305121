// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract MyHackNFTEveryone is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIdCounter;
    string public baseTokenURI;

    address public extensionStoreAddr;

    constructor() ERC721("MHDE", "MHDE") {}

    function mint(address toAddr) public nonReentrant returns (uint256) {
        require(msg.sender == extensionStoreAddr, "caller invalid");
        tokenIdCounter.increment();
        _safeMint(toAddr, tokenIdCounter.current());
        return(tokenIdCounter.current());
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseTokenURI = uri;
    }

    function setExtensionStoreAddr(address extensionStoreAddr_) external onlyOwner {
       extensionStoreAddr = extensionStoreAddr_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function currentId() external view returns (uint256){
        return(tokenIdCounter.current());
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return baseTokenURI;
    }
}
