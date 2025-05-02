// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IElectionFactory.sol";
import "../interfaces/IElection.sol";
import "./Election.sol";

/**
 * @title ElectionFactory
 * @dev Contract for creating and managing election contracts
 */
contract ElectionFactory is IElectionFactory, Ownable, ReentrancyGuard {
    // Mapping from creator address to their elections
    mapping(address => address[]) private creatorToElections;
    
    // All elections created by this factory
    address[] private allElections;
    
    // Mapping to check if an address is a valid election
    mapping(address => bool) private validElections;
    
    // Election creation fee (if any)
    uint256 public creationFee;

    /**
     * @dev Constructor
     * @param _initialOwner The initial owner of the contract
     * @param _initialFee The initial fee for creating an election (can be 0)
     */
    constructor(address _initialOwner, uint256 _initialFee) Ownable(_initialOwner) {
        creationFee = _initialFee;
    }

    /**
     * @dev Creates a new election contract
     * @param _name Name of the election
     * @param _description Description of the election
     * @param _startTime Start time of the election
     * @param _endTime End time of the election
     * @param _votingSystem Type of voting system
     * @param _candidateNames Array of candidate names
     * @param _candidateInfo Array of candidate information
     * @return address Address of the created election contract
     */
    function createElection(
        string calldata _name,
        string calldata _description,
        uint256 _startTime,
        uint256 _endTime,
        IElection.VotingSystem _votingSystem,
        string[] calldata _candidateNames,
        string[] calldata _candidateInfo
    ) external payable override nonReentrant returns (address) {
        // Validate inputs
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_candidateNames.length > 0, "Must have at least one candidate");
        require(_candidateNames.length == _candidateInfo.length, "Candidate names and info must match");
        
        // Check fee if applicable
        if (creationFee > 0) {
            require(msg.value >= creationFee, "Insufficient fee");
        }
        
        // Create new election contract
        Election election = new Election(
            _name,
            _description,
            _startTime,
            _endTime,
            _votingSystem,
            _candidateNames,
            _candidateInfo,
            msg.sender
        );
        
        // Store election
        address electionAddress = address(election);
        creatorToElections[msg.sender].push(electionAddress);
        allElections.push(electionAddress);
        validElections[electionAddress] = true;
        
        // Return excess fee if any
        if (msg.value > creationFee) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - creationFee}("");
            require(success, "Fee refund failed");
        }
        
        emit ElectionCreated(electionAddress, _name, msg.sender);
        
        return electionAddress;
    }

    /**
     * @dev Get all elections created by a specific address
     * @param _creator Address of the creator
     * @return address[] Array of election addresses
     */
    function getElectionsByCreator(address _creator) external view override returns (address[] memory) {
        return creatorToElections[_creator];
    }
    
    /**
     * @dev Get all elections created by this factory
     * @return address[] Array of all election addresses
     */
    function getAllElections() external view returns (address[] memory) {
        return allElections;
    }
    
    /**
     * @dev Check if an address is a valid election created by this factory
     * @param _election Address to check
     * @return bool True if the address is a valid election
     */
    function isValidElection(address _election) external view override returns (bool) {
        return validElections[_election];
    }
    
    /**
     * @dev Set the creation fee
     * @param _newFee New fee amount
     * Only callable by the owner
     */
    function setCreationFee(uint256 _newFee) external onlyOwner {
        creationFee = _newFee;
    }
    
    /**
     * @dev Withdraw accumulated fees
     * @param _amount Amount to withdraw
     * Only callable by the owner
     */
    function withdrawFees(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        (bool success, ) = owner().call{value: _amount}("");
        require(success, "Withdrawal failed");
    }
}