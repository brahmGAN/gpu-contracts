// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @custom:security-contact info@brahmgan.com
contract GANNode is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    using ECDSA for bytes32;

    uint public maxTokenId;
    uint public constant MAX_SUPPLY = 15000; //Change it to set the value using a new function
    bool public isPrivateSale;
    string URI = "https://uri.gpu.net/"; //Will change to the ipfs hash
    address public serverPublicAddress;
    uint bigCheck;

    constructor(address initialOwner)
        ERC721("GAN-Node", "GN")
        Ownable(initialOwner)
    {}

    mapping(uint => uint) public tierLeftover;
    mapping(address => mapping(uint=> uint)) public userTierLeftover;

    // mapping(address => bool) public isWhitelisted;
    mapping(uint => uint) public tierToPrice;
    mapping(address => address[]) public referredUsers;
    mapping(address => string) public referralCodes;
    mapping(string => address) public codeToAddress;
    mapping (address => bool) public hasCode;
    mapping (string => bool) public isCodeValid;
    mapping (address => uint) public rewardsInKGwei;
    mapping (address => bool) public isInitialized;
    mapping (bytes32 => bool) public usedNonces;

    event Refer(address indexed referrer, address indexed referee, uint tokenId, uint referralRewards);
    event minted(address indexed minter, uint quantity, uint amountPaidInKGwei);
    event rewardsSent(address referrer, uint amountInKGwei);

    modifier privateSaleOn() {
        require(isPrivateSale);
        _;
    }


    function _baseURI() internal pure override returns (string memory) {
        return "https://gpu.net";
    }

    function initializeUser(address userToInit) internal onlyOwner {
        require(!isInitialized[userToInit]);
        for(uint i=1; i<=15; i++) {
            userTierLeftover[userToInit][i] = i;
            if(i == 5) {
                userTierLeftover[userToInit][i] = 0;
            }
        }
        isInitialized[userToInit] = !isInitialized[userToInit];
    }

    function isAuthorized(bytes32 messageHash, bytes memory sigHash) private view returns(bool) {
        require(!usedNonces[messageHash]);
        bytes32 ethSignedMessageHash = messageHash;
        address resolvedAddress = ethSignedMessageHash.recover(sigHash);
        return resolvedAddress == serverPublicAddress ;
    }

    function safeMint(address to, string memory referCode, uint mintQuantity, uint totalEthPaidInGwei, bytes32 mesHash, bytes memory sigHash) public onlyOwner {
        require(isAuthorized(mesHash, sigHash));
        require(totalEthPaidInGwei / mintQuantity >= bigCheck);
        require(maxTokenId < MAX_SUPPLY, "We are sold out :(");
        if(!isInitialized[to]){
            initializeUser(to);
        }
        uint pricePaid = calcPrice(mintQuantity, to, referCode);
        require(totalEthPaidInGwei == pricePaid);
        
        for (uint i=1; i<= mintQuantity; i++) {
            maxTokenId+=1;
            _safeMint(to, maxTokenId);
            _setTokenURI(maxTokenId, URI);
        }
        usedNonces[mesHash] = true;
        deductMint(mintQuantity,to);

        if (isCodeValid[referCode]) {
            address referrer = codeToAddress[referCode];
            referredUsers[referrer].push(to);
            uint referRewards = pricePaid * 10 / 100;
            emit Refer(referrer, to, mintQuantity, referRewards);
            rewardsInKGwei[referrer]+= referRewards;
        }
        emit minted(to, mintQuantity, pricePaid);
    }

    function setTiers(uint tier, uint totalAllocated, uint priceTier) public onlyOwner {
        require(tier >0 && tier <= 15 && priceTier >= 75000);
        require(maxTokenId ==0, "Minting already started");
        tierLeftover[tier] = totalAllocated;
        tierToPrice[tier] = priceTier;
    }

    function setServerKey (address newServerKey) public onlyOwner {
        require(serverPublicAddress != newServerKey && newServerKey != address(0) );
        serverPublicAddress = newServerKey;
    }

    function privateSale(address toSend, uint amount) public onlyOwner privateSaleOn {
        require((amount + maxTokenId) <= MAX_SUPPLY );
        for (uint i=1; i<= amount; i++) {
            maxTokenId+=1;
            _safeMint(toSend, maxTokenId);
            _setTokenURI(maxTokenId, URI);
        }
    }

    function calcPrice(uint amount, address minter, string memory refCode) public view returns (uint) {
        
        require(isInitialized[minter]);
        require(maxMintable(minter) >= amount);
        uint price;
        uint remAmount = amount;
        uint finalPrice;    
        for (uint256 i = 1; i <= 15; i++) {
            if(tierLeftover[i] >= userTierLeftover[minter][i] ) {
                if(remAmount >= userTierLeftover[minter][i]) {
                    price += tierToPrice[i] * userTierLeftover[minter][i];
                    remAmount -= userTierLeftover[minter][i];
                }
                
                else {
                    price += tierToPrice[i] * remAmount;
                    remAmount = 0;
                    break;
                }

            }
            else {
                price += tierToPrice[i] * (tierLeftover[i]);
                remAmount -= tierLeftover[i];
            }
        }
        finalPrice = price;
        if(isCodeValid[refCode]) {
            finalPrice = finalPrice * 90 / 100;
        }
        return finalPrice;
    }

    function deductMint(uint amount, address minter) public {
        
        require(isInitialized[minter]);
        require(maxMintable(minter) >= amount);
        uint remAmount = amount;   
        for (uint256 i = 1; i <= 15; i++) {
            if(tierLeftover[i] >= userTierLeftover[minter][i] ) {
                if(remAmount >= userTierLeftover[minter][i]) {
                    tierLeftover[i] -= userTierLeftover[minter][i];
                    remAmount -= userTierLeftover[minter][i];
                    userTierLeftover[minter][i] = 0;
                }
                else{
                    userTierLeftover[minter][i] -= remAmount;
                    tierLeftover[i] -= remAmount;
                    remAmount = 0;
                    break;
                }
            }
            else {
                userTierLeftover[minter][i] -= tierLeftover[i];
                
                remAmount -= tierLeftover[i];
                tierLeftover[i] = 0;
            }
        }
    }

    function sendReferRewards(address referrer) public onlyOwner {
        require(hasCode[referrer], "Not eligible");
        emit rewardsSent(referrer, rewardsInKGwei[referrer]);
        rewardsInKGwei[referrer] = 0;
    }

    function maxMintable(address userToCheck) public view returns(uint) {
        uint maxMint;
        if (!isInitialized[userToCheck]) {
            maxMint = 115;
        }
        else {
            for(uint i = 1; i<= 15; i++) {
                if(userTierLeftover[userToCheck][i] > tierLeftover[i]) {
                    maxMint += tierLeftover[i];
                }
                else{
                    maxMint += userTierLeftover[userToCheck][i]; 
                }
            }
        }
        return maxMint;
    }

    function togglePrivateSale() public onlyOwner {
        isPrivateSale = !isPrivateSale;
    }

    function updateBigCheck(uint newCheck) public onlyOwner {
        bigCheck = newCheck;
    }

    function setReferralCode(string memory code, address wallet) public onlyOwner {
        referralCodes[wallet] = code;
        codeToAddress[code] = wallet;
        isCodeValid[code] = !isCodeValid[code];
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
