// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.20;
import "./IGPU.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IERC721 {
    function balanceOf(address nftOwner) external view returns(uint);
}

contract GPU is IGPU, OwnableUpgradeable, UUPSUpgradeable {

    bool private initialized;
    uint256 tickSeconds;
    uint256 bufferTime;
    uint public machineId;
    address nftAddress;
    string[] public gpuTypes;
    address[] public providersList;
    address[] public queensList; 

    //Mappings
    mapping(address => mapping(uint16 => Job)) consumerJobs;
    mapping(address => Provider) providers;
    mapping(address => Consumer) consumers;
    mapping(address => Queen) queens;
    mapping(address => uint) public stakes;
    mapping(address => address) queenStakings;
    mapping(address => address) providerStakings;
    mapping(address => address[]) public queenProviders;
    mapping(address => address[]) public drillQueenProviders; 
    mapping(string => uint256) public gpuPrices;
    mapping(uint => Machine) public machineDetails;
    mapping(address => bool) public isStaked;

    // Modifiers
    modifier haveNft(address providerAddress){
        IERC721 nftContract = IERC721(nftAddress);
        require(nftContract.balanceOf(providerAddress) > 0, "Does not have nft");
        _;
    }

    modifier isStakedAddress(address StakerAddress){
        require(!isStaked[StakerAddress],"Staker already present");
        _;
    }

    // Events
    event JobCreated(address indexed consumerAddress, address indexed providerAddress, address queenValidationAddress, uint16 jobId, uint16 gpuType, uint256 gpuHoursInSeconds, uint256 price);
    event JobUpdated(address indexed consumerAddress, address indexed providerAddress, address indexed queenAddress, uint16 jobId, JobStatus status);
    event JobCompleted(address indexed consumerAddress, address indexed providerAddress, address indexed currentQueenAddress, uint16 jobID);
    event QueenAdded(address indexed sender, address indexed queenStakingAddress, string publicKey, string userName, uint256 stakedAmount);
    event ProviderAdded(address indexed providerAddress, uint256 machineId, uint16 gpuType, string ipAddress, address providerStakingAddress, address queenValidationAddress);
    event ProviderStatusUpdated(address indexed providerAddress, uint16 lastDrillResult);
    event DrillRequested( address indexed providerAddress);
    event QueenReassign(address indexed consumerAddress, address indexed providerAddress, address indexed queenAddress, uint16 jobId);
    event HealthCheckDataBundle(HealthCheckData[] healthCheckDataArray);
 
    //Functions
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


   function initialize(uint256 _tick, uint _id, address _nftAddress, uint256 _bufferTime) public initializer {
        require(!initialized, "Contract is already initialized");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        tickSeconds = _tick;
        machineId = _id;
        initialized = true;
        nftAddress = _nftAddress;       
        bufferTime = _bufferTime; 
    }

    function withdraw(uint amount) public onlyOwner {
        payable(msg.sender).transfer(amount);
    }

    
  
    //SETTER Functions
    function addGpuType(string calldata gpuType, uint256 priceInWei) public onlyOwner {
        gpuTypes.push(gpuType); 
        gpuPrices[gpuType] = priceInWei; 
    }


    function updateGpuPrice(uint16 gpuIndex, uint256 updatedPriceInWei) public onlyOwner{
        gpuPrices[gpuTypes[gpuIndex]] = updatedPriceInWei;
    }

    function addQueen(address queenStakingAddress, string calldata publicKey, string calldata userName) public haveNft(queenStakingAddress) isStakedAddress(queenStakingAddress)payable {
        require(!queens[msg.sender].exists, "Queen already present");
        require(msg.value == 100 ether, "You must stake some amount of GPU");
        require(msg.sender != address(0), "You must enter queen health check");
        require(bytes(publicKey).length > 0, "You must enter public key");
        stakes[queenStakingAddress] += msg.value;
        isStaked[queenStakingAddress] = true;
        queens[msg.sender] = Queen({
            publicKey: publicKey,
            userName : userName,
            status: QueenStatus.ACTIVE,
            exists: true
        });
        queensList.push(msg.sender);
        queenStakings[msg.sender] = queenStakingAddress;

        emit QueenAdded(msg.sender, queenStakingAddress, publicKey, userName, msg.value);

    }
    
    function addProvider(
        Machine memory providerDetails,
        uint16 gpuType,
        string calldata ipAddress,
        address providerStakingAddress
    ) external haveNft(providerStakingAddress) isStakedAddress(providerStakingAddress) payable {
        require(!providers[msg.sender].exists, "Provider already present");
        require(msg.value == 100 ether, "You must stake some amount of GPU");
        require(gpuType < gpuTypes.length, "Enter valid GPU type");
        require(bytes(providerDetails.gpuName).length > 0, "GPU name cannot be empty");
        require(providerDetails.gpuQuantity > 0, "GPU quantity must be greater than 0");
        require(providerDetails.gpuMemory > 0, "GPU memory required");
        require(bytes(providerDetails.connectionType).length > 0, "GPU name cannot be empty");
        require(bytes(providerDetails.cpuName).length > 0, "CPU name cannot be empty");
        require(providerDetails.cpuCoreCount > 0, "CPU core count required");
        require(providerDetails.uploadBandWidth > 0 && providerDetails.downloadBandWidth > 0, "Upload and download bandwidth must be present");
        require(bytes(providerDetails.storageType).length > 0, "GPU storage cannot be empty");
        require(providerDetails.storageAvailable > 0, "Storage not available");
        require(providerDetails.portsOpen.length > 0, "Open ports not given");
        require(bytes(providerDetails.region).length > 0, "Region cannot be empty");
        
        stakes[providerStakingAddress] += msg.value;
        isStaked[providerStakingAddress] = true;
        machineId++;
        machineDetails[machineId] = providerDetails;
        uint randomIndex = uint(keccak256(abi.encodePacked(block.timestamp, block.number, msg.sender)));
        address queenValidationAddress = queensList[randomIndex % queensList.length];
        providers[msg.sender] = Provider({
            gpuType: gpuType,
            ipAddress : ipAddress,
            machineId: machineId,
            currentJobId: 0,
            currentConsumer: address(0),
            currentQueen: queenValidationAddress,
            lastDrillResult: 0,
            lastDrillTime : 0,
            status: ProviderStatus.NEW,
            exists: true
        });
        
        providerStakings[msg.sender] = providerStakingAddress;
        drillQueenProviders[queenValidationAddress].push(msg.sender); 

        emit ProviderAdded( msg.sender, machineId, gpuType, ipAddress, providerStakingAddress, queenValidationAddress);
    }

    function updateProviderStatus(address providerAddress,uint16 value) external {
        require(msg.sender == providers[providerAddress].currentQueen, "Only assigned queen can call");
        if(drillTest(value)){

            providers[providerAddress].status = ProviderStatus.AVAILABLE;
            providersList.push(providerAddress);
        }
        providers[providerAddress].currentQueen = address(0);
        providers[providerAddress].lastDrillResult = value;
        providers[providerAddress].lastDrillTime = block.timestamp;

        emit ProviderStatusUpdated( providerAddress, value);

    }

    function providerDrillRequest() external {
        require(providers[msg.sender].exists, "Provider should be already present");
        if(block.timestamp - providers[msg.sender].lastDrillTime > tickSeconds){
        uint randomIndex = uint(keccak256(abi.encodePacked(block.timestamp, block.number, msg.sender)));
        address queenValidationAddress = queensList[randomIndex % queensList.length];
        providers[msg.sender].currentQueen = queenValidationAddress;
        drillQueenProviders[queenValidationAddress].push(msg.sender);
        }
        emit DrillRequested(msg.sender);
    }

    function addConsumer(address consumerAddress, string calldata publicKey ,string calldata userName,string calldata organisation)  external {
        require(!consumers[consumerAddress].exists, "Consumer already present");
        require(bytes(publicKey).length > 0, "You must enter public key");
        consumers[consumerAddress] = Consumer({
            publicKey : publicKey,  
            userName : userName, 
            organisation : organisation,
            nextJobId : 1 , 
            jobs :  new uint16[](0) ,
            exists : true
            });
    }
   
    function createJob(
        address providerAddress,
        uint16 gpuType,
        uint256 gpuHours ) public payable{
        uint256 cost = calculateCost(gpuType,gpuHours);
        require(consumers[msg.sender].exists, "Consumer must exist");
        require(msg.value == cost, "You must deposit some amount of GPU");
        require(providers[providerAddress].status == ProviderStatus.AVAILABLE, "Provider not available");
        require(providers[providerAddress].gpuType == gpuType, "Provider does not have the required GPU");
        require(queensList.length > 0, "No queens in the list");
        stakes[msg.sender] += msg.value;
        uint randomIndex = uint(keccak256(abi.encodePacked(block.timestamp, block.number, msg.sender)));
        address queenValidationAddress = queensList[randomIndex % queensList.length];
        uint16 jobId = consumers[msg.sender].nextJobId;
        uint256 gpuHoursInSeconds = gpuHours * tickSeconds;
        
        consumerJobs[msg.sender][jobId] = Job({
            providerAddress : providerAddress,
            consumerAddress : msg.sender,
            queenValidationAddress : queenValidationAddress,
            gpuType : gpuType,
            gpuHours : gpuHoursInSeconds,
            startedAt : 0,
            lastChecked : 0,
            completedTicks : 0,
            completedHours : 0,
            price : msg.value,
            status : JobStatus.VERIFYING
            });
        providers[providerAddress].currentConsumer = msg.sender;
        providers[providerAddress].status = ProviderStatus.VERIFYING;
        providers[providerAddress].currentJobId = jobId;
        providers[providerAddress].currentQueen = queenValidationAddress;
        queenProviders[queenValidationAddress].push(providerAddress);
        consumers[msg.sender].jobs.push(jobId);
        consumers[msg.sender].nextJobId = jobId  + 1;

        emit JobCreated( msg.sender, providerAddress, queenValidationAddress, jobId, gpuType, gpuHoursInSeconds, msg.value);
    }

    function drillTest(uint16 value) pure  internal returns(bool){
        uint16 minRange = 80;
        if (value > minRange)
        {
            return true;
        }
        return false;
    }

    function calculateCost(uint16 gpuIndex, uint256 gpuHours) view internal returns (uint256){
        uint256 cost = uint256(gpuPrices[gpuTypes[gpuIndex]]) * uint256(gpuHours);
        return cost;
    } 

    function updateAssignedJob(address providerAddress, uint16 value) public {
        require(msg.sender == providers[providerAddress].currentQueen, "Only assigned queen can call");
        address consumerAddress = providers[providerAddress].currentConsumer;
        uint16 jobId = providers[providerAddress].currentJobId;
        require(consumerJobs[consumerAddress][jobId].status ==  JobStatus.VERIFYING, "Can only call when job is verifying");
        
        if(drillTest(value)){
            providers[providerAddress].status = ProviderStatus.PROCESSING;
            consumerJobs[consumerAddress][jobId].status = JobStatus.RUNNING;
            consumerJobs[consumerAddress][jobId].startedAt = block.timestamp;
            consumerJobs[consumerAddress][jobId].lastChecked = block.timestamp; 
        }
        else{
            providers[providerAddress].status = ProviderStatus.AVAILABLE;
            providers[providerAddress].currentConsumer = address(0);
            providers[providerAddress].currentQueen = address(0);
            providers[providerAddress].currentJobId = 0;
            consumerJobs[consumerAddress][jobId].status = JobStatus.DISABLED;
        }
        providers[providerAddress].lastDrillResult = value;
        providers[providerAddress].lastDrillTime = block.timestamp;

        emit JobUpdated(consumerAddress, providerAddress, msg.sender, jobId, consumerJobs[consumerAddress][jobId].status); 
    }
  
    function reassignQueen() external {
        require(providers[msg.sender].status == ProviderStatus.PROCESSING, "Provider not running");
        address consumerAddress = providers[msg.sender].currentConsumer;
        uint16 jobId = providers[msg.sender].currentJobId;
        if (consumerJobs[consumerAddress][jobId].lastChecked < block.timestamp - (2 * tickSeconds)) {
            address newQueen = updateAssignQueen();
            consumerJobs[consumerAddress][jobId].queenValidationAddress = newQueen;
            providers[msg.sender].currentQueen = newQueen;

        if (consumerJobs[consumerAddress][jobId].gpuHours - consumerJobs[consumerAddress][jobId].completedHours >= (2 * tickSeconds)) {
            consumerJobs[consumerAddress][jobId].completedTicks += 2;
            consumerJobs[consumerAddress][jobId].completedHours += 2 * tickSeconds;
            consumerJobs[consumerAddress][jobId].lastChecked = block.timestamp;
        } else {
            consumerJobs[consumerAddress][jobId].completedTicks += 1;
            consumerJobs[consumerAddress][jobId].completedHours += tickSeconds;
            consumerJobs[consumerAddress][jobId].lastChecked = block.timestamp;
        }

        if (consumerJobs[consumerAddress][jobId].completedHours >= consumerJobs[consumerAddress][jobId].gpuHours) {
            consumerJobs[consumerAddress][jobId].status = JobStatus.COMPLETED;
            providers[msg.sender].status = ProviderStatus.AVAILABLE;
            providers[msg.sender].currentConsumer = address(0);
            providers[msg.sender].currentQueen = address(0);
            providers[msg.sender].currentJobId = 0;
          
         emit JobCompleted(consumerAddress, msg.sender, providers[msg.sender].currentQueen, jobId);
          
        } else {
            queenProviders[newQueen].push(msg.sender);
        }
    }
    emit QueenReassign(consumerAddress, msg.sender, providers[msg.sender].currentQueen, jobId);
    }

    function updateAssignQueen() view internal returns (address) {
        uint randomIndex = uint(keccak256(abi.encodePacked(block.timestamp, block.number, msg.sender)));
        address newQueen = queensList[randomIndex % queensList.length];
        return newQueen;
    }

    function healthCheckBundle(HealthCheckData[] calldata healthCheckDataArray) external {

        for (uint256 i = 0; i < healthCheckDataArray.length; i++) {
            healthCheckReport(healthCheckDataArray[i]);
        }
        emit HealthCheckDataBundle(healthCheckDataArray);
    }

    function healthCheckReport(HealthCheckData calldata data) internal {
        require(msg.sender == providers[data.providerAddress].currentQueen, "Only assigned queen can call");
        address consumerAddress = providers[data.providerAddress].currentConsumer;
        uint16 jobId = providers[data.providerAddress].currentJobId;
        
        require(consumerJobs[consumerAddress][jobId].status ==  JobStatus.RUNNING, "Can only call when job is running");
        
        if (block.timestamp - consumerJobs[consumerAddress][jobId].lastChecked >= (tickSeconds - bufferTime)) {

            if (healthCheckTest(data.availabilityData)) {
                consumerJobs[consumerAddress][jobId].completedTicks += 1;
            }
            consumerJobs[consumerAddress][jobId].completedHours += tickSeconds;
            consumerJobs[consumerAddress][jobId].lastChecked = block.timestamp;

            if (consumerJobs[consumerAddress][jobId].completedHours >= consumerJobs[consumerAddress][jobId].gpuHours) {
                consumerJobs[consumerAddress][jobId].status = JobStatus.COMPLETED; 
                providers[data.providerAddress].status = ProviderStatus.AVAILABLE;
                providers[data.providerAddress].currentConsumer = address(0);
                providers[data.providerAddress].currentQueen = address(0);
                providers[data.providerAddress].currentJobId = 0;
            
            emit JobCompleted(consumerAddress, data.providerAddress, providers[data.providerAddress].currentQueen, jobId);
            }

            else{
                emit JobUpdated(consumerAddress, data.providerAddress, msg.sender, jobId, consumerJobs[consumerAddress][jobId].status); 
            }
        }
    }

    function healthCheckTest(uint16[] calldata value) internal pure returns(bool){
        uint16 minAvailability = 54;
        uint16 maxUnavailability = 5;
        if (value[0] > minAvailability && value[1] < maxUnavailability) {
            return true;
        }
        return false;
    }

    //GETTER Functions
    function checkQueenLastCheck() view public returns (uint256){
        address consumerAddress = providers[msg.sender].currentConsumer;
        uint16 jobId = providers[msg.sender].currentJobId;
        return consumerJobs[consumerAddress][jobId].lastChecked;
    }

    function getProviderStatus(address providerAddress) public view returns(ProviderStatus){
        return providers[providerAddress].status;
    }

    function getJobStatus(address consumerAddress, uint16 jobId) public view returns(JobStatus){
        return consumerJobs[consumerAddress][jobId].status;
    }

    function getConsumerActiveJob() public view returns(uint16[] memory){
        return consumers[msg.sender].jobs;
    }

    function getProviders() public view returns(address[] memory) {
        return providersList;
    }
    function getProvider(address providerAddress) public view returns(Provider memory){
        return providers[providerAddress];
    }

    function getConsumer(address consumerAddress) public view returns(Consumer memory){
        return consumers[consumerAddress];
    }

    function getQueen(address queenAddress) public view returns(Queen memory){
        return queens[queenAddress];
    }

    function getGpuTypes() public view returns(string[] memory){
        return gpuTypes;
    }

    function getGpuPrice(uint index) public view returns(uint){
        return gpuPrices[gpuTypes[index]];
    }

    function getAssignedProviders() public view returns(address[] memory){
        return queenProviders[msg.sender];
    } 

    function getConsumerJobInfo(address consumerAddress, uint16 jobId) external view returns(Job memory){
        return consumerJobs[consumerAddress][jobId];
    }


    function machineInfo(uint id) public view  returns(Machine memory) {
        return machineDetails[id];
    }

     function getDrillProvider() public view returns(address[] memory){
        return drillQueenProviders[msg.sender];
    }
    
}