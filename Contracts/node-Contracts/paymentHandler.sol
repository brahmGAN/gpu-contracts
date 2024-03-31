// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract paymentHandler is Ownable {
    using ECDSA for bytes32;
    address public fundsHandler;
    address public serverPublicAddress;

    mapping (bytes32 => bool) public usedNonces;

    event minted(address indexed minter, uint256 amount, uint quantity, string refCode);

    constructor(address initialOwner) 
        Ownable(initialOwner) {}
    
    function isAuthorized(bytes32 messageHash, bytes memory sigHash) internal view returns(bool) {
        require(!usedNonces[messageHash]);
        bytes32 ethSignedMessageHash = messageHash;
        address resolvedAddress = ethSignedMessageHash.recover(sigHash);
        return resolvedAddress == serverPublicAddress ;
    }

    function mint(uint quantity, string memory refCode, bytes32 messageHash, bytes memory sigHash) public payable {
        require(!usedNonces[messageHash]);
        require(isAuthorized(messageHash, sigHash));
        require(msg.value > 0.075 ether, "No value sent");
        usedNonces[messageHash] = true;

        (bool success, ) = payable(fundsHandler).call{value: msg.value}("");
        require(success, "Payment failed");

        emit minted( msg.sender, msg.value, quantity, refCode );
    }

    function setFundsHandler(address _newFundsHandler) external onlyOwner{
        require(_newFundsHandler != address(0), "Invalid address");
        fundsHandler = _newFundsHandler;
    }

    function setServerAddress (address _newSerPubKey) external onlyOwner {
        require(_newSerPubKey != address(0));
        serverPublicAddress = _newSerPubKey;
    }
}
