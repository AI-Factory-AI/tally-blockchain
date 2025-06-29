pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ElectionFactory
 * @dev Professional smart contract for creating and managing elections
 * @author Election System
 */
contract ElectionFactory is Ownable, ReentrancyGuard, Pausable {
    // ============ State Variables ============

    uint256 private _electionIds;

    // Maximum limits for security
    uint256 public constant MAX_TITLE_LENGTH = 200;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 5000;
    uint256 public constant MAX_MESSAGE_LENGTH = 2000;
    uint256 public constant MIN_ELECTION_DURATION = 1 hours;
    uint256 public constant MAX_ELECTION_DURATION = 365 days;

    // Election fee (can be 0 for free elections)
    uint256 public electionCreationFee = 100000000000000;

    // ============ Structs ============

    /**
     * @dev Struct for election basic information
     */
    struct ElectionBasicInfo {
        string title;
        string description;
        address creator;
        uint256 createdAt;
        ElectionStatus status;
    }

    /**
     * @dev Struct for election timing configuration
     */
    struct ElectionTiming {
        uint256 startTime;
        uint256 endTime;
        string timezone; // For reference only
    }

    /**
     * @dev Struct for election voting settings
     */
    struct VotingSettings {
        bool weightedVoting;
        bool ballotReceipt;
        bool submitConfirmation;
        uint256 maxVotersCount;
        bool allowVoterRegistration;
    }

    /**
     * @dev Struct for election messages/instructions
     */
    struct ElectionMessages {
        string loginInstructions;
        string voteConfirmation;
        string afterElectionMessage;
    }

    /**
     * @dev Struct for results configuration
     */
    struct ResultsConfig {
        bool publicResults;
        bool realTimeResults;
        uint256 resultsReleaseTime;
        bool allowResultsDownload;
    }

    /**
     * @dev Complete election configuration struct
     */
    struct ElectionConfig {
        ElectionBasicInfo basicInfo;
        ElectionTiming timing;
        VotingSettings votingSettings;
        ElectionMessages messages;
        ResultsConfig resultsConfig;
    }

    /**
     * @dev Input struct for creating elections (avoids stack too deep)
     */
    struct CreateElectionInput {
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        string timezone;
        bool weightedVoting;
        bool ballotReceipt;
        bool submitConfirmation;
        uint256 maxVotersCount;
        bool allowVoterRegistration;
        string loginInstructions;
        string voteConfirmation;
        string afterElectionMessage;
        bool publicResults;
        bool realTimeResults;
        uint256 resultsReleaseTime;
        bool allowResultsDownload;
    }

    // ============ Enums ============

    enum ElectionStatus {
        DRAFT,
        SCHEDULED,
        ACTIVE,
        COMPLETED,
        CANCELLED,
        DELETED
    }

    // ============ Mappings ============

    mapping(uint256 => ElectionConfig) public elections;
    mapping(address => uint256[]) public creatorElections;
    mapping(uint256 => bool) public electionExists;

    // ============ Events ============

    event ElectionCreated(
        uint256 indexed electionId,
        address indexed creator,
        string title,
        uint256 startTime,
        uint256 endTime
    );

    event ElectionUpdated(
        uint256 indexed electionId,
        address indexed updater,
        string field
    );

    event ElectionStatusChanged(
        uint256 indexed electionId,
        ElectionStatus oldStatus,
        ElectionStatus newStatus
    );

    event ElectionDeleted(
        uint256 indexed electionId,
        address indexed deleter
    );

    event ElectionFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );

    // ============ Modifiers ============

    modifier onlyElectionCreator(uint256 _electionId) {
        require(
            elections[_electionId].basicInfo.creator == msg.sender,
            "ElectionFactory: Not the election creator"
        );
        _;
    }

    modifier electionMustExist(uint256 _electionId) {
        require(electionExists[_electionId], "ElectionFactory: Election does not exist");
        _;
    }

    modifier validElectionTiming(uint256 _startTime, uint256 _endTime) {
        require(_startTime > block.timestamp, "ElectionFactory: Start time must be in the future");
        require(_endTime > _startTime, "ElectionFactory: End time must be after start time");
        require(
            _endTime - _startTime >= MIN_ELECTION_DURATION,
            "ElectionFactory: Election duration too short"
        );
        require(
            _endTime - _startTime <= MAX_ELECTION_DURATION,
            "ElectionFactory: Election duration too long"
        );
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
     */
    function createElection(CreateElectionInput calldata input) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        validElectionTiming(input.startTime, input.endTime)
        returns (uint256 electionId) 
    {
        // Validate payment
        require(msg.value >= electionCreationFee, "ElectionFactory: Insufficient fee");
        
        // Validate input strings
        _validateElectionStrings(input);
        
        // Increment election ID counter
        _electionIds++;
        electionId = _electionIds;
        
        // Create election configuration
        ElectionConfig storage election = elections[electionId];
        
        // Set basic info
        election.basicInfo = ElectionBasicInfo({
            title: input.title,
            description: input.description,
            creator: msg.sender,
            createdAt: block.timestamp,
            status: ElectionStatus.DRAFT
        });
        
        // Set timing
        election.timing = ElectionTiming({
            startTime: input.startTime,
            endTime: input.endTime,
            timezone: input.timezone
        });
        
        // Set voting settings
        election.votingSettings = VotingSettings({
            weightedVoting: input.weightedVoting,
            ballotReceipt: input.ballotReceipt,
            submitConfirmation: input.submitConfirmation,
            maxVotersCount: input.maxVotersCount,
            allowVoterRegistration: input.allowVoterRegistration
        });
        
        // Set messages
        election.messages = ElectionMessages({
            loginInstructions: input.loginInstructions,
            voteConfirmation: input.voteConfirmation,
            afterElectionMessage: input.afterElectionMessage
        });
        
        // Set results config
        election.resultsConfig = ResultsConfig({
            publicResults: input.publicResults,
            realTimeResults: input.realTimeResults,
            resultsReleaseTime: input.resultsReleaseTime,
            allowResultsDownload: input.allowResultsDownload
        });
        
        // Update mappings
        electionExists[electionId] = true;
        creatorElections[msg.sender].push(electionId);
        
        // Emit event
        emit ElectionCreated(
            electionId,
            msg.sender,
            input.title,
            input.startTime,
            input.endTime
        );
        
        // Refund excess payment
        if (msg.value > electionCreationFee) {
            payable(msg.sender).transfer(msg.value - electionCreationFee);
        }
        
        return electionId;
    }

    /**
     * @dev Updates election basic information
     * @param _electionId ID of the election to update
     * @param _title New title
     * @param _description New description
     */
    function updateElectionBasicInfo(
        uint256 _electionId,
        string calldata _title,
        string calldata _description
    ) external onlyElectionCreator(_electionId) electionMustExist(_electionId) {
        require(
            elections[_electionId].basicInfo.status == ElectionStatus.DRAFT,
            "ElectionFactory: Can only update draft elections"
        );
        
        require(bytes(_title).length > 0 && bytes(_title).length <= MAX_TITLE_LENGTH, "ElectionFactory: Invalid title length");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "ElectionFactory: Description too long");
        
        elections[_electionId].basicInfo.title = _title;
        elections[_electionId].basicInfo.description = _description;
        
        emit ElectionUpdated(_electionId, msg.sender, "basicInfo");
    }

    /**
     * @dev Updates election timing
     * @param _electionId ID of the election to update
     * @param _startTime New start time
     * @param _endTime New end time
     * @param _timezone New timezone
     */
    function updateElectionTiming(
        uint256 _electionId,
        uint256 _startTime,
        uint256 _endTime,
        string calldata _timezone
    ) external 
        onlyElectionCreator(_electionId) 
        electionMustExist(_electionId)
        validElectionTiming(_startTime, _endTime)
    {
        require(
            elections[_electionId].basicInfo.status == ElectionStatus.DRAFT,
            "ElectionFactory: Can only update draft elections"
        );
        
        elections[_electionId].timing.startTime = _startTime;
        elections[_electionId].timing.endTime = _endTime;
        elections[_electionId].timing.timezone = _timezone;
        
        emit ElectionUpdated(_electionId, msg.sender, "timing");
    }

    /**
     * @dev Updates voting settings
     * @param _electionId ID of the election to update
     * @param _settings New voting settings
     */
    function updateVotingSettings(
        uint256 _electionId,
        VotingSettings calldata _settings
    ) external onlyElectionCreator(_electionId) electionMustExist(_electionId) {
        require(
            elections[_electionId].basicInfo.status == ElectionStatus.DRAFT,
            "ElectionFactory: Can only update draft elections"
        );
        
        elections[_electionId].votingSettings = _settings;
        
        emit ElectionUpdated(_electionId, msg.sender, "votingSettings");
    }

    /**
     * @dev Updates election messages
     * @param _electionId ID of the election to update
     * @param _messages New messages configuration
     */
    function updateElectionMessages(
        uint256 _electionId,
        ElectionMessages calldata _messages
    ) external onlyElectionCreator(_electionId) electionMustExist(_electionId) {
        require(
            elections[_electionId].basicInfo.status == ElectionStatus.DRAFT,
            "ElectionFactory: Can only update draft elections"
        );
        
        require(bytes(_messages.loginInstructions).length <= MAX_MESSAGE_LENGTH, "ElectionFactory: Login instructions too long");
        require(bytes(_messages.voteConfirmation).length <= MAX_MESSAGE_LENGTH, "ElectionFactory: Vote confirmation too long");
        require(bytes(_messages.afterElectionMessage).length <= MAX_MESSAGE_LENGTH, "ElectionFactory: After election message too long");
        
        elections[_electionId].messages = _messages;
        
        emit ElectionUpdated(_electionId, msg.sender, "messages");
    }

    /**
     * @dev Updates results configuration
     * @param _electionId ID of the election to update
     * @param _resultsConfig New results configuration
     */
    function updateResultsConfig(
        uint256 _electionId,
        ResultsConfig calldata _resultsConfig
    ) external onlyElectionCreator(_electionId) electionMustExist(_electionId) {
        require(
            elections[_electionId].basicInfo.status == ElectionStatus.DRAFT,
            "ElectionFactory: Can only update draft elections"
        );
        
        elections[_electionId].resultsConfig = _resultsConfig;
        
        emit ElectionUpdated(_electionId, msg.sender, "resultsConfig");
    }

    /**
     * @dev Changes election status
     * @param _electionId ID of the election
     * @param _newStatus New status
     */
    function changeElectionStatus(
        uint256 _electionId,
        ElectionStatus _newStatus
    ) external onlyElectionCreator(_electionId) electionMustExist(_electionId) {
        ElectionStatus currentStatus = elections[_electionId].basicInfo.status;
        require(currentStatus != _newStatus, "ElectionFactory: Status unchanged");
        
        // Validate status transitions
        _validateStatusTransition(currentStatus, _newStatus);
        
        elections[_electionId].basicInfo.status = _newStatus;
        
        emit ElectionStatusChanged(_electionId, currentStatus, _newStatus);
    }

    /**
     * @dev Deletes an election (soft delete by changing status)
     * @param _electionId ID of the election to delete
     */
    function deleteElection(uint256 _electionId) 
        external 
        onlyElectionCreator(_electionId) 
        electionMustExist(_electionId) 
    {
        require(
            elections[_electionId].basicInfo.status != ElectionStatus.ACTIVE,
            "ElectionFactory: Cannot delete active election"
        );
        
        elections[_electionId].basicInfo.status = ElectionStatus.DELETED;
        
        emit ElectionDeleted(_electionId, msg.sender);
    }

    // ============ View Functions ============

    /**
     * @dev Gets complete election configuration
     * @param _electionId ID of the election
     * @return Election configuration
     */
    function getElection(uint256 _electionId) 
        external 
        view 
        electionMustExist(_electionId) 
        returns (ElectionConfig memory) 
    {
        return elections[_electionId];
    }

    /**
     * @dev Gets election basic information
     * @param _electionId ID of the election
     * @return Basic election information
     */
    // function getElectionBasicInfo(uint256 _electionId) 
    //     external 
    //     view 
    //     electionMustExist(_electionId) 
    //     returns (ElectionBasicInfo memory) 
    // {
    //     return elections[_electionId].basicInfo;
    // }

    /**
     * @dev Gets elections created by a specific address
     * @param _creator Address of the creator
     * @return Array of election IDs
     */
    function getElectionsByCreator(address _creator) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return creatorElections[_creator];
    }

    /**
     * @dev Gets the current election ID counter
     * @return Current election count
     */
    // function getCurrentElectionId() external view returns (uint256) {
    //     return _electionIds;
    // }

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
        require(bytes(input.title).length <= MAX_TITLE_LENGTH, "ElectionFactory: Title too long");
        require(bytes(input.description).length <= MAX_DESCRIPTION_LENGTH, "ElectionFactory: Description too long");
        require(bytes(input.loginInstructions).length <= MAX_MESSAGE_LENGTH, "ElectionFactory: Login instructions too long");
        require(bytes(input.voteConfirmation).length <= MAX_MESSAGE_LENGTH, "ElectionFactory: Vote confirmation too long");
        require(bytes(input.afterElectionMessage).length <= MAX_MESSAGE_LENGTH, "ElectionFactory: After election message too long");
    }

    /**
     * @dev Validates status transitions
     * @param _currentStatus Current election status
     * @param _newStatus New election status
     */
    function _validateStatusTransition(ElectionStatus _currentStatus, ElectionStatus _newStatus) internal pure {
        if (_currentStatus == ElectionStatus.DRAFT) {
            require(
                _newStatus == ElectionStatus.SCHEDULED || _newStatus == ElectionStatus.CANCELLED,
                "ElectionFactory: Invalid status transition from DRAFT"
            );
        } else if (_currentStatus == ElectionStatus.SCHEDULED) {
            require(
                _newStatus == ElectionStatus.ACTIVE || _newStatus == ElectionStatus.CANCELLED,
                "ElectionFactory: Invalid status transition from SCHEDULED"
            );
        } else if (_currentStatus == ElectionStatus.ACTIVE) {
            require(
                _newStatus == ElectionStatus.COMPLETED,
                "ElectionFactory: Invalid status transition from ACTIVE"
            );
        } else {
            revert("ElectionFactory: Invalid status transition");
        }
    }
}
