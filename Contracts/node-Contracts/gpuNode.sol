// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact info@brahmgan.com
contract GANNode is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    

    uint public maxTokenId;
    uint public constant MAX_SUPPLY = 15000; //Change it to set the value using a new function
    string public URI; //Will change to the ipfs hash
    address public serverPublicAddress;
    mapping (address => uint) public userMinted;

    constructor(address initialOwner)
        ERC721("GAN-Node", "GN")
        Ownable(initialOwner)
    {}
    event minted(address indexed minter, uint quantity);
    

    function _baseURI() internal pure override returns (string memory) {
        return "https://gpu.net";
    }

    function safeMint(address to, uint mintQuantity) public onlyOwner {
        require(maxTokenId < MAX_SUPPLY, "We are sold out :(");
        
        for (uint i=1; i<= mintQuantity; i++) {
            maxTokenId+=1;
            _safeMint(to, maxTokenId);
            _setTokenURI(maxTokenId, URI);
        }
        userMinted[to] += mintQuantity;
        emit minted(to, mintQuantity);
    }


    function setServerKey (address newServerKey) public onlyOwner {
        require(serverPublicAddress != newServerKey && newServerKey != address(0) );
        serverPublicAddress = newServerKey;
    }

    function privateSale(address toSend, uint amount) public onlyOwner {
        require((amount + maxTokenId) <= MAX_SUPPLY );
        for (uint i=1; i<= amount; i++) {
            maxTokenId+=1;
            safeMint(toSend, maxTokenId);
        }
    }

    function setURI(string memory newURI) public onlyOwner {
        URI = newURI;
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
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

