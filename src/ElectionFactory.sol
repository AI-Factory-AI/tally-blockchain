// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IElectionFactory.sol";
import "./interfaces/IElection.sol";
import "./Election.sol";

/**
 * @title ElectionFactory
 * @dev Factory contract for creating and managing multiple elections
 * @author Election System
 */
contract ElectionFactory is IElectionFactory, Ownable, ReentrancyGuard, Pausable {
    // ============ State Variables ============
    
    uint256 private _electionIds;
    
    // Election fee (can be 0 for free elections)
    uint256 public electionCreationFee;
    
    // ============ Mappings ============
    
    mapping(uint256 => address) public elections;
    mapping(address => uint256[]) public creatorElections;
    mapping(uint256 => bool) public electionExists;
    mapping(address => bool) public isElectionContract;
    
    // ============ Events ============
    
    event ElectionCreated(
        uint256 indexed electionId,
        address indexed electionContract,
        address indexed creator,
        string title,
        uint256 startTime,
        uint256 endTime
    );
    
    event ElectionDeleted(
        uint256 indexed electionId,
        address indexed electionContract,
        address indexed deleter
    );
    
    event ElectionFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );
    
    // ============ Modifiers ============
    
    modifier validElectionTiming(uint256 _startTime, uint256 _endTime) {
        require(_startTime > block.timestamp, "ElectionFactory: Start time must be in the future");
        require(_endTime > _startTime, "ElectionFactory: End time must be after start time");
        require(
            _endTime - _startTime >= 1 hours,
            "ElectionFactory: Election duration too short"
        );
        require(
            _endTime - _startTime <= 365 days,
            "ElectionFactory: Election duration too long"
        );
        _;
    }
    
    modifier electionMustExist(uint256 _electionId) {
        require(electionExists[_electionId], "ElectionFactory: Election does not exist");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(uint256 _electionCreationFee) Ownable(msg.sender) {
        electionCreationFee = _electionCreationFee;
    }
    
    // ============ External Functions ============
    
    /**
     * @dev Creates a new election with comprehensive configuration
     * @param input Complete election configuration input
     * @return electionId The ID of the newly created election
     * @return electionContract The address of the newly created election contract
     */
    function createElection(CreateElectionInput calldata input) 
        external 
        payable 
        override
        nonReentrant 
        whenNotPaused 
        validElectionTiming(input.startTime, input.endTime)
        returns (uint256 electionId, address electionContract) 
    {
        require(msg.value >= electionCreationFee, "ElectionFactory: Insufficient fee");
        _validateElectionStrings(input);
        _electionIds++;
        electionId = _electionIds;
        // Deploy new Election contract via helper to avoid stack too deep
        electionContract = _deployElection(input);
        // Update mappings
        elections[electionId] = electionContract;
        electionExists[electionId] = true;
        isElectionContract[electionContract] = true;
        creatorElections[msg.sender].push(electionId);
        // Generate election URL
        string memory baseUrl = "https://tally/vote/";
        string memory electionUrl = string(abi.encodePacked(baseUrl, _uint2str(electionId)));
        Election(electionContract).setElectionUrl(electionUrl);
        // Emit event
        emit ElectionCreated(
            electionId,
            electionContract,
            msg.sender,
            input.title,
            input.startTime,
            input.endTime
        );
        // Refund excess payment
        if (msg.value > electionCreationFee) {
            payable(msg.sender).transfer(msg.value - electionCreationFee);
        }
        return (electionId, electionContract);
    }

    function _deployElection(CreateElectionInput calldata input) private returns (address) {
        Election.ElectionBasicParams memory basicParams = Election.ElectionBasicParams({
            creator: msg.sender,
            title: input.title,
            description: input.description,
            startTime: input.startTime,
            endTime: input.endTime,
            timezone: input.timezone
        });
        Election.ElectionVotingParams memory votingParams = Election.ElectionVotingParams({
            ballotReceipt: input.ballotReceipt,
            submitConfirmation: input.submitConfirmation,
            maxVotersCount: input.maxVotersCount,
            allowVoterRegistration: input.allowVoterRegistration
        });
        Election.ElectionMessagesParams memory messagesParams = Election.ElectionMessagesParams({
            loginInstructions: input.loginInstructions,
            voteConfirmation: input.voteConfirmation,
            afterElectionMessage: input.afterElectionMessage
        });
        Election.ElectionResultsParams memory resultsParams = Election.ElectionResultsParams({
            publicResults: input.publicResults,
            realTimeResults: input.realTimeResults,
            resultsReleaseTime: input.resultsReleaseTime,
            allowResultsDownload: input.allowResultsDownload
        });
        Election newElection = new Election(
            basicParams,
            votingParams,
            messagesParams,
            resultsParams
        );
        return address(newElection);
    }
    
    /**
     * @dev Deletes an election by marking it as deleted in the factory
     * @param _electionId ID of the election to delete
     */
    function deleteElection(uint256 _electionId) 
        external 
        override
        electionMustExist(_electionId)
    {
        address electionContract = elections[_electionId];
        Election election = Election(electionContract);
        
        // Check if caller is the creator
        IElection.ElectionBasicInfo memory basicInfo = election.getElectionBasicInfo();
        require(basicInfo.creator == msg.sender, "ElectionFactory: Not the election creator");
        
        // Call delete on the election contract
        election.deleteElection();
        
        emit ElectionDeleted(_electionId, electionContract, msg.sender);
    }
    
    // ============ View Functions ============
    
    /**
     * @dev Gets the election contract address by ID
     * @param _electionId ID of the election
     * @return Address of the election contract
     */
    function getElectionContract(uint256 _electionId) 
        external 
        view
        override 
        electionMustExist(_electionId) 
        returns (address) 
    {
        return elections[_electionId];
    }
    
    /**
     * @dev Gets complete election configuration by ID
     * @param _electionId ID of the election
     * @return Election configuration
     */
    function getElection(uint256 _electionId) 
        external 
        view
        override 
        electionMustExist(_electionId) 
        returns (IElection.ElectionConfig memory) 
    {
        Election election = Election(elections[_electionId]);
        return election.getElection();
    }
    
    /**
     * @dev Gets election basic information by ID
     * @param _electionId ID of the election
     * @return Basic election information
     */
    function getElectionBasicInfo(uint256 _electionId) 
        external 
        view
        override 
        electionMustExist(_electionId) 
        returns (IElection.ElectionBasicInfo memory) 
    {
        Election election = Election(elections[_electionId]);
        return election.getElectionBasicInfo();
    }
    
    /**
     * @dev Gets elections created by a specific address
     * @param _creator Address of the creator
     * @return Array of election IDs
     */
    function getElectionsByCreator(address _creator) 
        external 
        view
        override 
        returns (uint256[] memory) 
    {
        return creatorElections[_creator];
    }
    
    /**
     * @dev Gets the current election ID counter
     * @return Current election count
     */
    function getCurrentElectionId() external view override returns (uint256) {
        return _electionIds;
    }
    
    /**
     * @dev Gets all election IDs and their contract addresses
     * @return electionIds Array of election IDs
     * @return electionContracts Array of corresponding contract addresses
     */
    function getAllElections() 
        external 
        view
        override 
        returns (uint256[] memory electionIds, address[] memory electionContracts) 
    {
        uint256 totalElections = _electionIds;
        electionIds = new uint256[](totalElections);
        electionContracts = new address[](totalElections);
        
        for (uint256 i = 1; i <= totalElections; i++) {
            electionIds[i - 1] = i;
            electionContracts[i - 1] = elections[i];
        }
        
        return (electionIds, electionContracts);
    }
    
    /**
     * @dev Gets election contracts created by a specific address
     * @param _creator Address of the creator
     * @return Array of election contract addresses
     */
    function getElectionContractsByCreator(address _creator) 
        external 
        view
        returns (address[] memory) 
    {
        uint256[] memory electionIds = creatorElections[_creator];
        address[] memory electionContracts = new address[](electionIds.length);
        
        for (uint256 i = 0; i < electionIds.length; i++) {
            electionContracts[i] = elections[electionIds[i]];
        }
        
        return electionContracts;
    }
    
    // ============ Owner Functions ============
    
    /**
     * @dev Updates the election creation fee
     * @param _newFee New fee amount
     */
    function updateElectionFee(uint256 _newFee) external onlyOwner {
        uint256 oldFee = electionCreationFee;
        electionCreationFee = _newFee;
        
        emit ElectionFeeUpdated(oldFee, _newFee);
    }
    
    /**
     * @dev Withdraws accumulated fees
     * @param _to Address to send fees to
     */
    function withdrawFees(address payable _to) external onlyOwner {
        require(_to != address(0), "ElectionFactory: Invalid address");
        
        uint256 balance = address(this).balance;
        require(balance > 0, "ElectionFactory: No fees to withdraw");
        
        _to.transfer(balance);
    }
    
    /**
     * @dev Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ============ Internal Functions ============
    
    /**
     * @dev Validates election string inputs
     * @param input Election input to validate
     */
    function _validateElectionStrings(CreateElectionInput calldata input) internal pure {
        require(bytes(input.title).length > 0, "ElectionFactory: Title cannot be empty");
        require(bytes(input.title).length <= 200, "ElectionFactory: Title too long");
        require(bytes(input.description).length <= 5000, "ElectionFactory: Description too long");
        require(bytes(input.loginInstructions).length <= 2000, "ElectionFactory: Login instructions too long");
        require(bytes(input.voteConfirmation).length <= 2000, "ElectionFactory: Vote confirmation too long");
        require(bytes(input.afterElectionMessage).length <= 2000, "ElectionFactory: After election message too long");
    }
    
    /**
     * @dev Converts a uint to a string
     * @param _i uint to convert
     * @return _uintAsString string representation of the uint
     */
    function _uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        
        uint256 j = _i;
        uint256 len;
        
        while (j != 0) {
            len++;
            j /= 10;
        }
        
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        
        return string(bstr);
    }
}