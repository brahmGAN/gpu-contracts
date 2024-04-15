// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract paymentHandler is Ownable, ReentrancyGuard {

    address public fundsHandler;
    uint public totalMinted;

    //mappings
    mapping(uint => uint) public tierLeftover;
    mapping (uint => uint) public tierMaxSupply;
    mapping(uint => uint) public tierToPrice;
    mapping (address => uint) public userMinted;
    mapping (address => uint) public rewardsEarned;
    mapping(address => mapping(uint=> uint)) public userTierLeftover;
    mapping(address => string) public referralCodes;
    mapping(string => address) public codeToAddress;
    mapping (address => bool) public isInitialized;
    
    //events
    event paymentReceived(address indexed minter, uint256 amount, uint quantity, string refCode);
    event Refer(address indexed referrer, address indexed referee, uint tokenId, uint referralRewards);

    constructor(address initialOwner) 
        Ownable(initialOwner) {}
    

    function mint(uint quantity, string memory refCode) public payable nonReentrant {
        
        if(!isInitialized[msg.sender]){
            initializeUser(msg.sender);
        }
        require(msg.value == calcPrice(quantity, msg.sender, refCode), "Low value sent");
        uint finalPayment = msg.value;

        if (codeToAddress[refCode] != address(0)) {
            address referrer = codeToAddress[refCode];
            uint referRewards = msg.value * 10 / 100;
            finalPayment = finalPayment * 90 / 100;
            (bool referSuccess, ) = payable(referrer).call{value: referRewards}("");
            require(referSuccess, "Payment failed");
            rewardsEarned[referrer]+= referRewards;
            emit Refer(referrer, msg.sender, quantity, referRewards);
        }

        (bool success, ) = payable(fundsHandler).call{value: finalPayment}("");
        require(success, "Payment failed");
        deductMint(quantity,msg.sender);
        userMinted[msg.sender] += quantity;
        totalMinted += quantity;
        emit paymentReceived( msg.sender, finalPayment, quantity, refCode );
    }

    // Core logic set functions
    function setTiers(uint tier, uint totalAllocated, uint priceTier) external onlyOwner {
        require(tier >0 && tier <= 15 && priceTier >= 0.075 ether);
        tierLeftover[tier] = totalAllocated;
        tierMaxSupply[tier] = totalAllocated;
        tierToPrice[tier] = priceTier;
    }

    function setReferralCode(string[] memory code, address[] memory wallet) external  onlyOwner {
        require(code.length == wallet.length);
        for (uint i = 0; i< code.length; i++) {
            referralCodes[wallet[i]] = code[i];
            codeToAddress[code[i]] = wallet[i];
        }
    }

    function setFundsHandler(address _newFundsHandler) external onlyOwner{
        require(_newFundsHandler != address(0), "Invalid address");
        fundsHandler = _newFundsHandler;
    }
    
    //internal functions
    function initializeUser(address userToInit) internal {
        require(!isInitialized[userToInit]);
        for(uint i=1; i<=15; i++) {
            userTierLeftover[userToInit][i] = i;
            if(i == 5) {
                userTierLeftover[userToInit][i] = 0;
            }
        }
        isInitialized[userToInit] = !isInitialized[userToInit];
    }

    function deductMint(uint amount, address minter) internal {
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

    

    

    //view functions
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
        if(codeToAddress[refCode] != address(0)) {
            finalPrice = finalPrice * 90 / 100;
        }
        return finalPrice;
    }

    function maxMintable(address userToCheck) public view returns(uint) {
        uint maxMint;
        if (!isInitialized[userToCheck]) {
            for(uint i = 1; i<= 15; i++) {
                if(tierLeftover[i]>=i) {
                    maxMint += i;
                }
                else {
                    maxMint += tierLeftover[i];
                }
            }
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

}