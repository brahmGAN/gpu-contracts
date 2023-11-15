// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "@openzeppelin/contracts/access/Ownable.sol";


// Interface for ERC20 (like USDC)
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns(uint256);
}


contract GPURentalMarketplace is Ownable {
   
    // Struct for GPU details
    struct GPU {
        string cpuName;
        string gpuName;
        uint256 gpuVRAM;
        uint256 totalRAM;
        uint256 storageAvailable;
        uint256 coreCount;
        string IPAddress;
        uint256[] portsOpen;
        string region;
        uint256 bidPrice;  //in Gpoints
        bool isAvailable;
        bool isListed;
        bool isRented;
        // GPUStatus status;
    }


    // Struct for User details
    struct user {
        string name;
        uint UID;
        string organization;
        bool isProvider;
        uint gPointsBalance;
        uint refId;
        uint[] providedGpus;
        uint16 refCount;
        address[] referredUsers;
        address referredBy;
    }


    // Struct for Order details
    struct Order {
        address renter;
        uint256 machineId;
        uint orderTimestamp;
        uint256 rentalDuration; // in hours
        uint amountToHold;
        bool isPending;
    }


    enum gPointsOrderType {
        Buy,
        Spend,
        ReferRewards,
        Earn
    }


    // State variables
    uint public machineId = 10000;
    uint public userIdCount = 100;
    uint public orderId = 0;
    uint internal refIDHandler = 100000;
    uint gPerRefer = 5;
    address public USDC_ADDRESS = 0x6e54ebe8067bE3dc516D8a14bb40f4224b83FB46;
    address public funds_handler = 0xcE408f35c3D43F5609151310309De73f3e57Ec76;


    // Mappings
    mapping(uint256 => GPU) public machines;
    mapping(address => user) public users;
    mapping (uint => address) public UIDtoAddress;
    mapping (uint => address) public refCodeToUser;
    mapping(uint256 => Order) public orders;
    mapping(string => bool) public userNameStatus;
    mapping (address => bool) public isRegistered;
    mapping (uint => address) public machineToOwner;
    mapping (uint => uint) public bundleInfo;
    mapping (string => bool) public stripeTxProcessed;
    mapping (address => bool) public hasTweeted;
   
    // Events
    // event ProviderRegistered(uint256 providerId, string name);
    event MachineListed(uint256 machineId, string name);
    event MachineRented(uint256 orderId, uint256 machineId, address indexed renter);
    event gPointsUpdate(address indexed user, uint amount, gPointsOrderType orderType );
    event userRegistered(address indexed user, string userName);




    address public serverPublicAddress;




    function setKeys(address newSerPub, address _newFundshandler, address _newToken) public onlyOwner  {
        serverPublicAddress = newSerPub;
        funds_handler = _newFundshandler;
        USDC_ADDRESS = _newToken;
    }


    modifier onlyFromServer( ) {
        require(msg.sender == serverPublicAddress, "Unauthorized request");
        _;
    }


    function isValidUsernameCharacter(bytes1 char) private pure returns (bool) {
        return (char >= 0x30 && char <= 0x39) || // 0-9
            (char >= 0x61 && char <= 0x7A);   // a-z
    }


    function isValidUsername(string memory username) private pure returns (bool) {
        bytes memory usernameBytes = bytes(username);
        for (uint i = 0; i < usernameBytes.length; i++) {
            if (!isValidUsernameCharacter(usernameBytes[i])) {
                return false;
            }
        }
        return true;
    }


    // Register a new user
    function registerUser(string memory _name, uint referrerId, string memory _organization, address userAddress) public returns(uint) {
        require(msg.sender == userAddress || msg.sender == serverPublicAddress, "Unauthorized call");
        require(bytes(_name).length > 4, "User name is too small");
        require(isValidUsername(_name), "Not a valid format");
        require(!isRegistered[userAddress], "Already Registered");
        require(!userNameStatus[_name], "Username Taken");
        require(referrerId >= 100000 && referrerId <= refIDHandler, "Invalid ref code");
        userIdCount++;
        refIDHandler++;
        users[userAddress] = user(_name, userIdCount, _organization, false, gPerRefer, refIDHandler, new uint256[](0) , 0, new address[](0), refCodeToUser[referrerId] );
        refCodeToUser[refIDHandler] = userAddress;
        address refereeAdd = refCodeToUser[referrerId];
        users[refereeAdd].gPointsBalance += gPerRefer;
        users[refereeAdd].referredUsers.push(userAddress);
        userNameStatus[_name] = true;
        isRegistered[userAddress] = true;
        UIDtoAddress[userIdCount] = userAddress;
        emit userRegistered(userAddress, _name);
        emit gPointsUpdate(refereeAdd, gPerRefer, gPointsOrderType.ReferRewards);
        emit gPointsUpdate(userAddress, gPerRefer, gPointsOrderType.ReferRewards);
        return userIdCount;
    }


    function updateProfile(string memory _name, string memory _organization) public {
        require(isRegistered[msg.sender]);
        require(!userNameStatus[_name]);
        require(isValidUsername(_name));
        require(bytes(_name).length>4);
        users[msg.sender].name = _name;
        users[msg.sender].organization = _organization;
    }


    // Register a new machine/GPU
    function registerMachines(string memory _cpuname, string memory _gpuname, uint _spuVRam, uint _totalRam, uint256 _memorySize, uint256 _coreCount, string memory _ipAddr, uint[] memory _openedPorts, string memory _region, uint _bidprice, address provider) public onlyFromServer returns(uint) {
        require(bytes(_gpuname).length > 3, "Machine name is required");
        require(_memorySize > 0, "Memory size should be greater than 0");
        require(_coreCount > 0, "Core count should be greater than 0");
        require(isRegistered[provider], "Not a user");
       
        if (!users[provider].isProvider) {
            users[provider].isProvider = true;
        }
        machineId++;
        machines[machineId] = GPU(_cpuname, _gpuname , _spuVRam, _totalRam,  _memorySize,  _coreCount, _ipAddr, _openedPorts, _region, _bidprice, true, true,false);
        users[provider].providedGpus.push(machineId);
        machineToOwner[machineId] = provider;
        emit MachineListed(machineId, _gpuname);
        return machineId;
    }


    // Rent a machine/GPU
    function rentMachine(uint256 _machineId, uint256 _rentalDuration, uint256 _userId) public onlyFromServer returns(uint) {
        require(isRegistered[UIDtoAddress[_userId]], "Renter is not registered yet");
        require(machines[_machineId].isAvailable && machines[_machineId].isListed, "Machine is not available for rent");
        require(!machines[_machineId].isRented, "Machine already in use");
        require(_rentalDuration > 0, "Rental duration should be greater than 0");
        require(users[UIDtoAddress[_userId]].gPointsBalance >= machines[_machineId].bidPrice * _rentalDuration, "Not enough Gpoints");
        orderId++;
        uint amountToDeduct = machines[_machineId].bidPrice * _rentalDuration;
        users[UIDtoAddress[_userId]].gPointsBalance -=  amountToDeduct;
        orders[orderId] = Order(UIDtoAddress[_userId], _machineId, block.timestamp, _rentalDuration, amountToDeduct, true);
       
        machines[_machineId].isAvailable = false; // Set the machine as rented
        machines[_machineId].isListed = false;
        machines[_machineId].isRented =  true;
        emit MachineRented(orderId, _machineId, UIDtoAddress[_userId]);
        return orderId;
    }


    function completeOrder(uint _orderId) public onlyFromServer {
        require(machines[orders[_orderId].machineId].isRented, "Machine is not rented");
        uint rentalDurationInSeconds = orders[_orderId].rentalDuration * 3600;
        require(block.timestamp >= (orders[_orderId].orderTimestamp + rentalDurationInSeconds));
        require(orders[_orderId].isPending, "Order fulfilled already");
        orders[_orderId].isPending = false;
        users[machineToOwner[orders[_orderId].machineId]].gPointsBalance += orders[_orderId].amountToHold;
        machines[orders[_orderId].machineId].isAvailable = true;
        machines[orders[_orderId].machineId].isListed = true;
        machines[orders[_orderId].machineId].isRented = false;
        emit gPointsUpdate(machineToOwner[orders[_orderId].machineId], orders[_orderId].amountToHold, gPointsOrderType.Earn);
        emit gPointsUpdate(orders[_orderId].renter, orders[_orderId].amountToHold , gPointsOrderType.Spend);
    }


    function cancelOrder(uint _orderId) public onlyFromServer {
        require(machines[orders[_orderId].machineId].isRented, "Machine is not rented");
        uint rentalDurationInSeconds = orders[_orderId].rentalDuration * 3600;
        require( (orders[_orderId].orderTimestamp + rentalDurationInSeconds) > block.timestamp);
        require(orders[_orderId].isPending, "Order fulfilled already");
        orders[_orderId].isPending = false;
        users[orders[_orderId].renter].gPointsBalance += orders[_orderId].amountToHold;
        machines[orders[_orderId].machineId].isAvailable = true;
        machines[orders[_orderId].machineId].isListed = true;
        machines[orders[_orderId].machineId].isRented = false;
    }


    function listMachineToggle(uint _machineId) public  {
        require(machineToOwner[_machineId] == msg.sender || msg.sender == serverPublicAddress, "Not authorized");
        require(_machineId > 10000 && _machineId <= machineId);
        require(!machines[_machineId].isRented, "Machine already in use");
        machines[_machineId].isListed = !machines[_machineId].isListed;
        machines[_machineId].isAvailable = !machines[_machineId].isAvailable;
    }


    function setReferRewards (uint newAmount) public onlyOwner {
        gPerRefer = newAmount;
    }


    function setBundleInfo(uint _amount, uint _gPoints) public onlyOwner {
        bundleInfo[_amount] = _gPoints;
    }


    function gPBuy(uint amount) public {
        require(bundleInfo[amount] != 0, "Select an existing bundle");
        require(isRegistered[msg.sender], "User not eligible to buy gPoints");
        uint decimal = IERC20(USDC_ADDRESS).decimals();
        require(IERC20(USDC_ADDRESS).allowance(msg.sender, address(this)) >= amount* 10**decimal, "Contract is not allowed to spend user's USDC");
       
        // Transfer USDC from user to this contract
        require(IERC20(USDC_ADDRESS).transferFrom(msg.sender, funds_handler, amount* 10**decimal), "USDC transfer failed");
        users[msg.sender].gPointsBalance += bundleInfo[amount];
        emit  gPointsUpdate( msg.sender , bundleInfo[amount], gPointsOrderType.Buy);
    }


    function gPBuyWithStripe(string memory txId, uint gPToCredit, uint userId) public onlyFromServer {
        require(isRegistered[UIDtoAddress[userId]], "Invalid user");
        require(!stripeTxProcessed[txId], "Order already processed");
        users[UIDtoAddress[userId]].gPointsBalance += gPToCredit;
        stripeTxProcessed[txId] = true;
        emit gPointsUpdate(UIDtoAddress[userId], gPToCredit, gPointsOrderType.Buy);
    }


    function  setBidPrice(uint _machineId, uint _bidAmount) public {
        require(msg.sender == machineToOwner[_machineId] || msg.sender == serverPublicAddress);
        machines[_machineId].bidPrice = _bidAmount;
    }


    function verifyTweet(address tweetedUser) public onlyFromServer {
        require(isRegistered[tweetedUser], "Invalid user");
        require(!hasTweeted[tweetedUser], "Already verified");
        users[tweetedUser].gPointsBalance += 5;
        hasTweeted[tweetedUser] = true;
        emit gPointsUpdate(tweetedUser, 5, gPointsOrderType.Earn);
    }


    //viewfunctions
    function getUserGPoints(address toFetch) public view returns(uint) {
        return users[toFetch].gPointsBalance;
    }




    function isUserProvider(address toFetch) public view returns (bool) {
        return users[toFetch].isProvider;
    }


    function machinesOwned(address toFetch) public view returns(uint[] memory) {
        return users[toFetch].providedGpus;
    }




    function checkAvailability(uint idToFetch) public view returns (bool) {
        return machines[idToFetch].isAvailable;
    }


    function isReferCodeValid (uint codeToCheck) public view returns (bool) {
        return codeToCheck > 100000 && codeToCheck <= refIDHandler;
    }
}