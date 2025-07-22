// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IElection.sol";

/**
 * @title Election
 * @dev Individual election contract for managing a single election with IPFS integration
 * @author Election System
 */
contract Election is IElection, Ownable, ReentrancyGuard, Pausable {
    // ============ Constants ============

    uint256 public constant MAX_TITLE_LENGTH = 200;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 5000;
    uint256 public constant MAX_MESSAGE_LENGTH = 2000;
    uint256 public constant MIN_ELECTION_DURATION = 1 hours;
    uint256 public constant MAX_ELECTION_DURATION = 365 days;

    // ============ State Variables ============

    ElectionConfig public electionConfig;
    address public immutable factory;

    // IPFS integration
    string public electionMetadataUri;
    string public ballotMetadataUri;
    string public voterMetadataUri;

    // Election URL
    string public electionUrl;

    // Ballot management
    mapping(uint256 => Ballot) public ballots;
    uint256 public ballotCount;

    // Voter management
    mapping(string => Voter) public votersByVoterId;
    mapping(address => string) public voterIdsByAddress;
    mapping(bytes32 => bool) public voterKeyHashes;
    uint256 public voterCount;

    // Vote tracking
    mapping(string => Vote) public votesByVoterId;
    uint256 public voteCount;

    // Paymaster support
    address public paymaster;
    mapping(address => bool) public authorizedPaymasters;

    // ============ Structs for Constructor ============

    struct ElectionBasicParams {
        address creator;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        string timezone;
    }

    struct ElectionVotingParams {
        bool ballotReceipt;
        bool submitConfirmation;
        uint256 maxVotersCount;
        bool allowVoterRegistration;
    }

    struct ElectionMessagesParams {
        string loginInstructions;
        string voteConfirmation;
        string afterElectionMessage;
    }

    struct ElectionResultsParams {
        bool publicResults;
        bool realTimeResults;
        uint256 resultsReleaseTime;
        bool allowResultsDownload;
    }

    // ============ Events ============

    event ElectionUpdated(address indexed updater, string field);

    event ElectionStatusChanged(
        ElectionStatus oldStatus,
        ElectionStatus newStatus
    );

    event BallotAdded(
        uint256 indexed ballotId,
        string title,
        bool isMultipleChoice,
        string ipfsCid
    );

    event VoterAdded(string voterId, address voterAddress, uint256 voteWeight);

    event VotersBatchAdded(uint256 count, string ipfsCid);

    event VoteCast(string voterId, uint256 timestamp, string ipfsCid);

    event ElectionMetadataUpdated(
        string electionMetadataUri,
        string ballotMetadataUri
    );

    event ElectionUrlGenerated(string electionUrl);

    event PaymasterUpdated(address paymaster, bool authorized);

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
            electionConfig.basicInfo.creator == msg.sender ||
                msg.sender == factory,
            "Election: Not authorized"
        );
        _;
    }

    modifier validElectionTiming(uint256 _startTime, uint256 _endTime) {
        require(
            _startTime > block.timestamp,
            "Election: Start time must be in the future"
        );
        require(
            _endTime > _startTime,
            "Election: End time must be after start time"
        );
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

    modifier onlyActiveElection() {
        require(
            electionConfig.basicInfo.status == ElectionStatus.ACTIVE,
            "Election: Election is not active"
        );
        _;
    }

    modifier onlyRegisteredVoter(string memory _voterId) {
        require(
            bytes(votersByVoterId[_voterId].voterId).length > 0,
            "Election: Voter is not registered"
        );
        _;
    }

    modifier onlyAuthorizedPaymaster() {
        require(
            authorizedPaymasters[msg.sender] || msg.sender == paymaster,
            "Election: Not an authorized paymaster"
        );
        _;
    }

    // ============ Constructor ============

    constructor(
        ElectionBasicParams memory _basicParams,
        ElectionVotingParams memory _votingParams,
        ElectionMessagesParams memory _messagesParams,
        ElectionResultsParams memory _resultsParams
    ) Ownable(_basicParams.creator) {
        factory = msg.sender;

        // Initialize election configuration
        electionConfig.basicInfo = ElectionBasicInfo({
            title: _basicParams.title,
            description: _basicParams.description,
            creator: _basicParams.creator,
            createdAt: block.timestamp,
            status: ElectionStatus.DRAFT
        });

        electionConfig.timing = ElectionTiming({
            startTime: _basicParams.startTime,
            endTime: _basicParams.endTime,
            timezone: _basicParams.timezone
        });

        electionConfig.votingSettings = VotingSettings({
            ballotReceipt: _votingParams.ballotReceipt,
            submitConfirmation: _votingParams.submitConfirmation,
            maxVotersCount: _votingParams.maxVotersCount,
            allowVoterRegistration: _votingParams.allowVoterRegistration
        });

        electionConfig.messages = ElectionMessages({
            loginInstructions: _messagesParams.loginInstructions,
            voteConfirmation: _messagesParams.voteConfirmation,
            afterElectionMessage: _messagesParams.afterElectionMessage
        });

        electionConfig.resultsConfig = ResultsConfig({
            publicResults: _resultsParams.publicResults,
            realTimeResults: _resultsParams.realTimeResults,
            resultsReleaseTime: _resultsParams.resultsReleaseTime,
            allowResultsDownload: _resultsParams.allowResultsDownload
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

        require(
            bytes(_title).length > 0 &&
                bytes(_title).length <= MAX_TITLE_LENGTH,
            "Election: Invalid title length"
        );
        require(
            bytes(_description).length <= MAX_DESCRIPTION_LENGTH,
            "Election: Description too long"
        );

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
    )
        external
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

        require(
            bytes(_messages.loginInstructions).length <= MAX_MESSAGE_LENGTH,
            "Election: Login instructions too long"
        );
        require(
            bytes(_messages.voteConfirmation).length <= MAX_MESSAGE_LENGTH,
            "Election: Vote confirmation too long"
        );
        require(
            bytes(_messages.afterElectionMessage).length <= MAX_MESSAGE_LENGTH,
            "Election: After election message too long"
        );

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
    ) external override onlyCreatorOrFactory notDeleted {
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
    function deleteElection() external override onlyElectionCreator notDeleted {
        require(
            electionConfig.basicInfo.status != ElectionStatus.ACTIVE,
            "Election: Cannot delete active election"
        );

        electionConfig.basicInfo.status = ElectionStatus.DELETED;

        emit ElectionStatusChanged(
            electionConfig.basicInfo.status,
            ElectionStatus.DELETED
        );
    }

    /**
     * @dev Adds IPFS metadata to the election
     * @param _electionMetadataUri IPFS URI for election metadata
     * @param _ballotMetadataUri IPFS URI for ballot metadata
     */
    function addElectionMetadata(
        string calldata _electionMetadataUri,
        string calldata _ballotMetadataUri
    ) external override onlyCreatorOrFactory notDeleted {
        electionMetadataUri = _electionMetadataUri;
        ballotMetadataUri = _ballotMetadataUri;

        emit ElectionMetadataUpdated(_electionMetadataUri, _ballotMetadataUri);
    }

    /**
     * @dev Adds a ballot to the election
     * @param _title Ballot title
     * @param _description Ballot description
     * @param _isMultipleChoice Whether multiple choices are allowed
     * @param _ipfsCid IPFS CID for detailed ballot data
     */
    function addBallot(
        string calldata _title,
        string calldata _description,
        bool _isMultipleChoice,
        string calldata _ipfsCid
    ) external override onlyElectionCreator notDeleted {
        require(
            electionConfig.basicInfo.status == ElectionStatus.DRAFT,
            "Election: Can only add ballots to draft elections"
        );

        ballotCount++;
        uint256 ballotId = ballotCount;

        ballots[ballotId] = Ballot({
            id: ballotId,
            title: _title,
            description: _description,
            isMultipleChoice: _isMultipleChoice,
            ipfsCid: _ipfsCid,
            createdAt: block.timestamp
        });

        emit BallotAdded(ballotId, _title, _isMultipleChoice, _ipfsCid);
    }

    /**
     * @dev Adds a single voter to the election
     * @param _voterAddress Voter's wallet address
     * @param _voterId Unique ID for the voter
     * @param _voteWeight Weight of the voter's vote
     * @param _voterKeyHash Hash of the voter's key for authentication
     */
    function addVoter(
        address _voterAddress,
        string calldata _voterId,
        uint256 _voteWeight,
        bytes32 _voterKeyHash
    ) external override onlyElectionCreator notDeleted {
        require(
            bytes(_voterId).length > 0,
            "Election: Voter ID cannot be empty"
        );
        require(
            bytes(votersByVoterId[_voterId].voterId).length == 0,
            "Election: Voter ID already exists"
        );
        require(
            voterCount < electionConfig.votingSettings.maxVotersCount,
            "Election: Maximum voters reached"
        );

        votersByVoterId[_voterId] = Voter({
            voterId: _voterId,
            voterAddress: _voterAddress,
            voteWeight: _voteWeight,
            hasVoted: false,
            registeredAt: block.timestamp
        });

        voterIdsByAddress[_voterAddress] = _voterId;
        voterKeyHashes[_voterKeyHash] = true;
        voterCount++;

        emit VoterAdded(_voterId, _voterAddress, _voteWeight);
    }

    /**
     * @dev Adds multiple voters to the election in a batch
     * @param _voterAddresses Array of voter wallet addresses
     * @param _voterIds Array of unique IDs for voters
     * @param _voteWeights Array of vote weights
     * @param _ipfsCid IPFS CID for detailed voter data
     */
    function addVoters(
        address[] calldata _voterAddresses,
        string[] calldata _voterIds,
        uint256[] calldata _voteWeights,
        string calldata _ipfsCid
    ) external override onlyElectionCreator notDeleted {
        require(
            _voterAddresses.length == _voterIds.length &&
                _voterIds.length == _voteWeights.length,
            "Election: Input arrays must have same length"
        );
        require(
            voterCount + _voterIds.length <=
                electionConfig.votingSettings.maxVotersCount,
            "Election: Maximum voters would be exceeded"
        );

        for (uint256 i = 0; i < _voterIds.length; i++) {
            require(
                bytes(_voterIds[i]).length > 0,
                "Election: Voter ID cannot be empty"
            );
            require(
                bytes(votersByVoterId[_voterIds[i]].voterId).length == 0,
                "Election: Voter ID already exists"
            );

            votersByVoterId[_voterIds[i]] = Voter({
                voterId: _voterIds[i],
                voterAddress: _voterAddresses[i],
                voteWeight: _voteWeights[i],
                hasVoted: false,
                registeredAt: block.timestamp
            });

            voterIdsByAddress[_voterAddresses[i]] = _voterIds[i];
        }

        voterCount += _voterIds.length;
        voterMetadataUri = _ipfsCid;

        emit VotersBatchAdded(_voterIds.length, _ipfsCid);
    }

    /**
     * @dev Registers a voter key for authentication
     * @param _voterKeyHash Hash of the voter's key
     */
    function registerVoterKey(
        bytes32 _voterKeyHash
    ) external onlyElectionCreator notDeleted {
        require(
            !voterKeyHashes[_voterKeyHash],
            "Election: Voter key hash already registered"
        );

        voterKeyHashes[_voterKeyHash] = true;
    }

    /**
     * @dev Casts a vote with wallet authentication
     * @param _voterId Voter's ID
     * @param _choices Array of candidate choices (as bytes32 hashes)
     * @param _ipfsCid IPFS CID for vote receipt
     */
    function castVote(
        string calldata _voterId,
        bytes32[] calldata _choices,
        string calldata _ipfsCid
    )
        external
        override
        onlyActiveElection
        onlyRegisteredVoter(_voterId)
        nonReentrant
    {
        Voter storage voter = votersByVoterId[_voterId];

        // Check if the sender is the registered voter
        require(
            voter.voterAddress == msg.sender ||
                keccak256(abi.encodePacked(voterIdsByAddress[msg.sender])) ==
                keccak256(abi.encodePacked(_voterId)),
            "Election: Not authorized to vote for this ID"
        );

        require(!voter.hasVoted, "Election: Voter has already voted");

        // Record the vote
        _recordVote(_voterId, _choices, _ipfsCid);
    }

    /**
     * @dev Casts a vote with key authentication (without wallet)
     * @param _voterId Voter's ID
     * @param _voterKeyHash Hash of the voter's key
     * @param _choices Array of candidate choices (as bytes32 hashes)
     * @param _ipfsCid IPFS CID for vote receipt
     */
    function castVoteWithKey(
        string calldata _voterId,
        bytes32 _voterKeyHash,
        bytes32[] calldata _choices,
        string calldata _ipfsCid
    )
        external
        override
        onlyActiveElection
        onlyRegisteredVoter(_voterId)
        nonReentrant
    {
        require(voterKeyHashes[_voterKeyHash], "Election: Invalid voter key");

        Voter storage voter = votersByVoterId[_voterId];
        require(!voter.hasVoted, "Election: Voter has already voted");

        // Record the vote
        _recordVote(_voterId, _choices, _ipfsCid);
    }

    /**
     * @dev Casts a vote through a paymaster (gasless voting)
     * @param _voterId Voter's ID
     * @param _voterKeyHash Hash of the voter's key
     * @param _choices Array of candidate choices (as bytes32 hashes)
     * @param _ipfsCid IPFS CID for vote receipt
     */
    function castVoteWithPaymaster(
        string calldata _voterId,
        bytes32 _voterKeyHash,
        bytes32[] calldata _choices,
        string calldata _ipfsCid
    )
        external
        override
        onlyAuthorizedPaymaster
        onlyActiveElection
        onlyRegisteredVoter(_voterId)
        nonReentrant
    {
        require(voterKeyHashes[_voterKeyHash], "Election: Invalid voter key");

        Voter storage voter = votersByVoterId[_voterId];
        require(!voter.hasVoted, "Election: Voter has already voted");

        // Record the vote
        _recordVote(_voterId, _choices, _ipfsCid);
    }

    /**
     * @dev Sets the election URL
     * @param _electionUrl URL for accessing the election
     */
    function setElectionUrl(
        string calldata _electionUrl
    ) external override onlyCreatorOrFactory notDeleted {
        electionUrl = _electionUrl;

        emit ElectionUrlGenerated(_electionUrl);
    }

    /**
     * @dev Sets an authorized paymaster
     * @param _paymaster Address of the paymaster
     * @param _authorized Whether the paymaster is authorized
     */
    function setPaymaster(
        address _paymaster,
        bool _authorized
    ) external override onlyElectionCreator notDeleted {
        require(
            _paymaster != address(0),
            "Election: Invalid paymaster address"
        );

        if (_authorized && paymaster == address(0)) {
            paymaster = _paymaster;
        }

        authorizedPaymasters[_paymaster] = _authorized;

        emit PaymasterUpdated(_paymaster, _authorized);
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

    // ============ View Functions ============

    /**
     * @dev Gets complete election configuration
     * @return Election configuration
     */
    function getElection()
        external
        view
        notDeleted
        returns (ElectionConfig memory)
    {
        return electionConfig;
    }

    /**
     * @dev Gets election basic information
     * @return Basic election information
     */
    function getElectionBasicInfo()
        external
        view
        notDeleted
        returns (ElectionBasicInfo memory)
    {
        return electionConfig.basicInfo;
    }

    /**
     * @dev Gets election timing information
     * @return Election timing information
     */
    function getElectionTiming()
        external
        view
        notDeleted
        returns (ElectionTiming memory)
    {
        return electionConfig.timing;
    }

    /**
     * @dev Gets voting settings
     * @return Voting settings
     */
    function getVotingSettings()
        external
        view
        notDeleted
        returns (VotingSettings memory)
    {
        return electionConfig.votingSettings;
    }

    /**
     * @dev Gets election messages
     * @return Election messages
     */
    function getElectionMessages()
        external
        view
        notDeleted
        returns (ElectionMessages memory)
    {
        return electionConfig.messages;
    }

    /**
     * @dev Gets results configuration
     * @return Results configuration
     */
    function getResultsConfig()
        external
        view
        notDeleted
        returns (ResultsConfig memory)
    {
        return electionConfig.resultsConfig;
    }

    /**
     * @dev Gets ballot information
     * @param _ballotId ID of the ballot
     * @return Ballot information
     */
    function getBallot(
        uint256 _ballotId
    ) external view notDeleted returns (Ballot memory) {
        require(
            _ballotId > 0 && _ballotId <= ballotCount,
            "Election: Invalid ballot ID"
        );

        return ballots[_ballotId];
    }

    /**
     * @dev Gets voter information by voter ID
     * @param _voterId ID of the voter
     * @return Voter information
     */
    function getVoter(
        string calldata _voterId
    ) external view notDeleted returns (Voter memory) {
        return votersByVoterId[_voterId];
    }

    /**
     * @dev Gets voter information by address
     * @param _voterAddress Address of the voter
     * @return Voter information
     */
    function getVoterByAddress(
        address _voterAddress
    ) external view notDeleted returns (Voter memory) {
        string memory voterId = voterIdsByAddress[_voterAddress];
        return votersByVoterId[voterId];
    }

    /**
     * @dev Verifies if a voter has access to vote
     * @param _voterId ID of the voter
     * @param _voterKeyHash Hash of the voter's key
     * @return Whether the voter has access
     */
    function verifyVoterAccess(
        string calldata _voterId,
        bytes32 _voterKeyHash
    ) external view notDeleted returns (bool) {
        if (bytes(votersByVoterId[_voterId].voterId).length == 0) {
            return false;
        }

        if (!voterKeyHashes[_voterKeyHash]) {
            return false;
        }

        if (votersByVoterId[_voterId].hasVoted) {
            return false;
        }

        return true;
    }

    /**
     * @dev Gets the vote cast by a voter
     * @param _voterId ID of the voter
     * @return Vote information
     */
    function getVote(
        string calldata _voterId
    ) external view notDeleted returns (Vote memory) {
        return votesByVoterId[_voterId];
    }

    // ============ Internal Functions ============

    /**
     * @dev Validates status transitions
     * @param _currentStatus Current election status
     * @param _newStatus New election status
     */
    function _validateStatusTransition(
        ElectionStatus _currentStatus,
        ElectionStatus _newStatus
    ) internal pure {
        if (_currentStatus == ElectionStatus.DRAFT) {
            require(
                _newStatus == ElectionStatus.SCHEDULED ||
                    _newStatus == ElectionStatus.CANCELLED,
                "Election: Invalid status transition from DRAFT"
            );
        } else if (_currentStatus == ElectionStatus.SCHEDULED) {
            require(
                _newStatus == ElectionStatus.ACTIVE ||
                    _newStatus == ElectionStatus.CANCELLED,
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
     * @dev Records a vote
     * @param _voterId ID of the voter
     * @param _choices Array of candidate choices
     * @param _ipfsCid IPFS CID for vote receipt
     */
    function _recordVote(
        string calldata _voterId,
        bytes32[] calldata _choices,
        string calldata _ipfsCid
    ) internal {
        // Mark voter as having voted
        votersByVoterId[_voterId].hasVoted = true;

        // Store the vote
        votesByVoterId[_voterId] = Vote({
            voterId: _voterId,
            choices: _choices,
            timestamp: block.timestamp,
            ipfsCid: _ipfsCid
        });

        voteCount++;

        emit VoteCast(_voterId, block.timestamp, _ipfsCid);
    }
}