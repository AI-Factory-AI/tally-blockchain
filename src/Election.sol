// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Election
 * @dev Individual election contract for managing a single election
 * @author Election System
 */
contract ElectionSetup is Ownable, ReentrancyGuard, Pausable {
    // ============ Constants ============
    
    uint256 public constant MAX_TITLE_LENGTH = 200;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 5000;
    uint256 public constant MAX_MESSAGE_LENGTH = 2000;
    uint256 public constant MIN_ELECTION_DURATION = 1 hours;
    uint256 public constant MAX_ELECTION_DURATION = 365 days;
    
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
    
    // ============ Enums ============
    
    enum ElectionStatus {
        DRAFT,
        SCHEDULED,
        ACTIVE,
        COMPLETED,
        CANCELLED,
        DELETED
    }
    
    // ============ State Variables ============
    
    ElectionConfig public electionConfig;
    address public immutable factory;
    
    // ============ Events ============
    
    event ElectionUpdated(
        address indexed updater,
        string field
    );
    
    event ElectionStatusChanged(
        ElectionStatus oldStatus,
        ElectionStatus newStatus
    );
    
    // ============ Modifiers ============
    
    modifier onlyElectionCreator() {
        require(
            electionConfig.basicInfo.creator == msg.sender,
            "Election: Not the election creator"
        );
        _;
    }
    
    modifier onlyCreatorOrFactory() {
        require(
            electionConfig.basicInfo.creator == msg.sender || msg.sender == factory,
            "Election: Not authorized"
        );
        _;
    }
    
    modifier validElectionTiming(uint256 _startTime, uint256 _endTime) {
        require(_startTime > block.timestamp, "Election: Start time must be in the future");
        require(_endTime > _startTime, "Election: End time must be after start time");
        require(
            _endTime - _startTime >= MIN_ELECTION_DURATION,
            "Election: Election duration too short"
        );
        require(
            _endTime - _startTime <= MAX_ELECTION_DURATION,
            "Election: Election duration too long"
        );
        _;
    }
    
    modifier notDeleted() {
        require(
            electionConfig.basicInfo.status != ElectionStatus.DELETED,
            "Election: Election has been deleted"
        );
        _;
    }
    
    modifier electionMustExist(uint256 _electionId) {
        // Removed: require(electionExists[_electionId], "ElectionFactory: Election does not exist");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        address _creator,
        string memory _title,
        string memory _description,
        uint256 _startTime,
        uint256 _endTime,
        string memory _timezone,
    
        bool _ballotReceipt,
        bool _submitConfirmation,
        uint256 _maxVotersCount,
        bool _allowVoterRegistration,
        string memory _loginInstructions,
        string memory _voteConfirmation,
        string memory _afterElectionMessage,
        bool _publicResults,
        bool _realTimeResults,
        uint256 _resultsReleaseTime,
        bool _allowResultsDownload
    ) Ownable(_creator) {
        factory = msg.sender;
        
        // Initialize election configuration
        electionConfig.basicInfo = ElectionBasicInfo({
            title: _title,
            description: _description,
            creator: _creator,
            createdAt: block.timestamp,
            status: ElectionStatus.DRAFT
        });
        
        electionConfig.timing = ElectionTiming({
            startTime: _startTime,
            endTime: _endTime,
            timezone: _timezone
        });
        
        electionConfig.votingSettings = VotingSettings({
            ballotReceipt: _ballotReceipt,
            submitConfirmation: _submitConfirmation,
            maxVotersCount: _maxVotersCount,
            allowVoterRegistration: _allowVoterRegistration
        });
        
        electionConfig.messages = ElectionMessages({
            loginInstructions: _loginInstructions,
            voteConfirmation: _voteConfirmation,
            afterElectionMessage: _afterElectionMessage
        });
        
        electionConfig.resultsConfig = ResultsConfig({
            publicResults: _publicResults,
            realTimeResults: _realTimeResults,
            resultsReleaseTime: _resultsReleaseTime,
            allowResultsDownload: _allowResultsDownload
        });
    }
    
    // ============ External Functions ============
     
    /**
     * @dev Updates election basic information
     * @param _title New title
     * @param _description New description
     */
    function updateElectionBasicInfo(
        string calldata _title,
        string calldata _description
    ) external onlyElectionCreator notDeleted {
        require(
            electionConfig.basicInfo.status == ElectionStatus.DRAFT,
            "Election: Can only update draft elections"
        );
        
        require(bytes(_title).length > 0 && bytes(_title).length <= MAX_TITLE_LENGTH, "Election: Invalid title length");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Election: Description too long");
        
        electionConfig.basicInfo.title = _title;
        electionConfig.basicInfo.description = _description;
        
        emit ElectionUpdated(msg.sender, "basicInfo");
    }
    
    /**
     * @dev Updates election timing
     * @param _startTime New start time
     * @param _endTime New end time
     * @param _timezone New timezone
     */
    function updateElectionTiming(
        uint256 _startTime,
        uint256 _endTime,
        string calldata _timezone
    ) external 
        onlyElectionCreator 
        notDeleted
        validElectionTiming(_startTime, _endTime)
    {
        require(
            electionConfig.basicInfo.status == ElectionStatus.DRAFT,
            "Election: Can only update draft elections"
        );
        
        electionConfig.timing.startTime = _startTime;
        electionConfig.timing.endTime = _endTime;
        electionConfig.timing.timezone = _timezone;
        
        emit ElectionUpdated(msg.sender, "timing");
    }
    
    /**
     * @dev Updates voting settings
     * @param _settings New voting settings
     */
    function updateVotingSettings(
        VotingSettings calldata _settings
    ) external onlyElectionCreator notDeleted {
        require(
            electionConfig.basicInfo.status == ElectionStatus.DRAFT,
            "Election: Can only update draft elections"
        );
        
        electionConfig.votingSettings = _settings;
        
        emit ElectionUpdated(msg.sender, "votingSettings");
    }
    
    /**
     * @dev Updates election messages
     * @param _messages New messages configuration
     */
    function updateElectionMessages(
        ElectionMessages calldata _messages
    ) external onlyElectionCreator notDeleted {
        require(
            electionConfig.basicInfo.status == ElectionStatus.DRAFT,
            "Election: Can only update draft elections"
        );
        
        require(bytes(_messages.loginInstructions).length <= MAX_MESSAGE_LENGTH, "Election: Login instructions too long");
        require(bytes(_messages.voteConfirmation).length <= MAX_MESSAGE_LENGTH, "Election: Vote confirmation too long");
        require(bytes(_messages.afterElectionMessage).length <= MAX_MESSAGE_LENGTH, "Election: After election message too long");
        
        electionConfig.messages = _messages;
        
        emit ElectionUpdated(msg.sender, "messages");
    }
    
    /**
     * @dev Updates results configuration
     * @param _resultsConfig New results configuration
     */
    function updateResultsConfig(
        ResultsConfig calldata _resultsConfig
    ) external onlyElectionCreator notDeleted {
        require(
            electionConfig.basicInfo.status == ElectionStatus.DRAFT,
            "Election: Can only update draft elections"
        );
        
        electionConfig.resultsConfig = _resultsConfig;
        
        emit ElectionUpdated(msg.sender, "resultsConfig");
    }
    
    /**
     * @dev Changes election status
     * @param _newStatus New status
     */
    function changeElectionStatus(
        ElectionStatus _newStatus
    ) external onlyCreatorOrFactory notDeleted {
        ElectionStatus currentStatus = electionConfig.basicInfo.status;
        require(currentStatus != _newStatus, "Election: Status unchanged");
        
        // Validate status transitions
        _validateStatusTransition(currentStatus, _newStatus);
        
        electionConfig.basicInfo.status = _newStatus;
        
        emit ElectionStatusChanged(currentStatus, _newStatus);
    }
    
    /**
     * @dev Deletes an election (soft delete by changing status)
     */
    function deleteElection() external onlyElectionCreator notDeleted {
        require(
            electionConfig.basicInfo.status != ElectionStatus.ACTIVE,
            "Election: Cannot delete active election"
        );
        
        electionConfig.basicInfo.status = ElectionStatus.DELETED;
        
        emit ElectionStatusChanged(electionConfig.basicInfo.status, ElectionStatus.DELETED);
    }
    
    // ============ View Functions ============
    
    /**
     * @dev Gets complete election configuration
     * @return Election configuration
     */
    function getElection() external view notDeleted returns (ElectionConfig memory) {
        return electionConfig;
    }
    
    /**
     * @dev Gets election basic information
     * @return Basic election information
     */
    function getElectionBasicInfo() external view notDeleted returns (ElectionBasicInfo memory) {
        return electionConfig.basicInfo;
    }
    
    /**
     * @dev Gets election timing information
     * @return Election timing information
     */
    function getElectionTiming() external view notDeleted returns (ElectionTiming memory) {
        return electionConfig.timing;
    }
    
    /**
     * @dev Gets voting settings
     * @return Voting settings
     */
    function getVotingSettings() external view notDeleted returns (VotingSettings memory) {
        return electionConfig.votingSettings;
    }
    
    /**
     * @dev Gets election messages
     * @return Election messages
     */
    function getElectionMessages() external view notDeleted returns (ElectionMessages memory) {
        return electionConfig.messages;
    }
    
    /**
     * @dev Gets results configuration
     * @return Results configuration
     */
    function getResultsConfig() external view notDeleted returns (ResultsConfig memory) {
        return electionConfig.resultsConfig;
    }
    
    // ============ Internal Functions ============
    
    /**
     * @dev Validates status transitions
     * @param _currentStatus Current election status
     * @param _newStatus New election status
     */
    function _validateStatusTransition(ElectionStatus _currentStatus, ElectionStatus _newStatus) internal pure {
        if (_currentStatus == ElectionStatus.DRAFT) {
            require(
                _newStatus == ElectionStatus.SCHEDULED || _newStatus == ElectionStatus.CANCELLED,
                "Election: Invalid status transition from DRAFT"
            );
        } else if (_currentStatus == ElectionStatus.SCHEDULED) {
            require(
                _newStatus == ElectionStatus.ACTIVE || _newStatus == ElectionStatus.CANCELLED,
                "Election: Invalid status transition from SCHEDULED"
            );
        } else if (_currentStatus == ElectionStatus.ACTIVE) {
            require(
                _newStatus == ElectionStatus.COMPLETED,
                "Election: Invalid status transition from ACTIVE"
            );
        } else {
            revert("Election: Invalid status transition");
        }
    }
    
    /**
     * @dev Pauses the election
     */
    function pause() external onlyElectionCreator {
        _pause();
    }
    
    /**
     * @dev Unpauses the election
     */
    function unpause() external onlyElectionCreator {
        _unpause();
    }
}