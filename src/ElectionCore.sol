// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IElection.sol";
import "./ElectionStorage.sol";
import "./VotingLogic.sol";

/**
 * @title ElectionCore
 * @dev Core election contract with modular design
 */
contract ElectionCore is IElection, Ownable, ReentrancyGuard, Pausable {
    using ElectionStorage for ElectionStorage.ElectionData;
    using VotingLogic for ElectionStorage.ElectionData;

    ElectionStorage.ElectionData internal electionData;

    // ============ Events ============
    event ElectionUpdated(address indexed updater, string field);
    event ElectionStatusChanged(ElectionStatus oldStatus, ElectionStatus newStatus);
    event BallotAdded(uint256 indexed ballotId, string title, bool isMultipleChoice, string ipfsCid);
    event VoterAdded(string voterId, address voterAddress, uint256 voteWeight);
    event VotersBatchAdded(uint256 count, string ipfsCid);
    event ElectionMetadataUpdated(string electionMetadataUri, string ballotMetadataUri);
    event ElectionUrlGenerated(string electionUrl);
    event PaymasterUpdated(address paymaster, bool authorized);

    // ============ Modifiers ============
    modifier onlyElectionCreator() {
        require(electionData.config.basicInfo.creator == msg.sender, "Not the election creator");
        _;
    }

    modifier onlyCreatorOrFactory() {
        require(
            electionData.config.basicInfo.creator == msg.sender || msg.sender == electionData.factory,
            "Not authorized"
        );
        _;
    }

    modifier notDeleted() {
        require(electionData.config.basicInfo.status != ElectionStatus.DELETED, "Election has been deleted");
        _;
    }

    modifier onlyActiveElection() {
        require(electionData.config.basicInfo.status == ElectionStatus.ACTIVE, "Election is not active");
        _;
    }

    modifier onlyRegisteredVoter(string memory _voterId) {
        require(bytes(electionData.votersByVoterId[_voterId].voterId).length > 0, "Voter is not registered");
        _;
    }

    modifier onlyAuthorizedPaymaster() {
        require(
            electionData.authorizedPaymasters[msg.sender] || msg.sender == electionData.paymaster,
            "Not an authorized paymaster"
        );
        _;
    }

    // ============ Constructor ============
    constructor() Ownable(msg.sender) {
        // Hardcoded values for deployment optimization
        electionData.factory = msg.sender;
        electionData.config.basicInfo = ElectionBasicInfo({
            title: "Election 2025",
            description: "A test election to demonstrate full constructor parameters.",
            creator: tx.origin, // The original transaction sender
            createdAt: block.timestamp,
            status: ElectionStatus.DRAFT
        });
        electionData.config.timing = ElectionTiming({
            startTime: 1764000000, // Jan 1, 2025 00:00:00 UTC
            endTime: 1764086400,   // Jan 2, 2025 00:00:00 UTC
            timezone: "UTC"
        });
        electionData.config.votingSettings = VotingSettings({
            ballotReceipt: true,
            submitConfirmation: true,
            maxVotersCount: 1000,
            allowVoterRegistration: true
        });
        electionData.config.messages = ElectionMessages({
            loginInstructions: "Please follow the on-screen instructions carefully.",
            voteConfirmation: "Your vote has been recorded.",
            afterElectionMessage: "Thank you for voting in Election 2025."
        });
        electionData.config.resultsConfig = ResultsConfig({
            publicResults: true,
            realTimeResults: false,
            resultsReleaseTime: 1764090000, // Jan 2, 2025 01:00:00 UTC
            allowResultsDownload: true
        });
    }

    // ============ External Functions ============
    
    /**
     * @dev Updates all election configuration after deployment (only for hardcoded constructor)
     * @param _title Election title
     * @param _description Election description
     * @param _startTime Start time
     * @param _endTime End time
     * @param _timezone Timezone
     * @param _maxVotersCount Maximum voters
     * @param _loginInstructions Login instructions
     * @param _voteConfirmation Vote confirmation message
     * @param _afterElectionMessage After election message
     * @param _realTimeResults Whether to show real-time results
     * @param _resultsReleaseTime Results release time
     */
    function initializeElectionConfig(
        string calldata _title,
        string calldata _description,
        uint256 _startTime,
        uint256 _endTime,
        string calldata _timezone,
        uint256 _maxVotersCount,
        string calldata _loginInstructions,
        string calldata _voteConfirmation,
        string calldata _afterElectionMessage,
        bool _realTimeResults,
        uint256 _resultsReleaseTime
    ) external onlyElectionCreator notDeleted {
        require(electionData.config.basicInfo.status == ElectionStatus.DRAFT, "Can only update draft elections");
        
        // Validate timing and strings
        ElectionStorage.validateTiming(_startTime, _endTime);
        ElectionStorage.validateStrings(_title, _description, _loginInstructions, _voteConfirmation, _afterElectionMessage);
        
        // Update configuration
        electionData.config.basicInfo.title = _title;
        electionData.config.basicInfo.description = _description;
        electionData.config.timing.startTime = _startTime;
        electionData.config.timing.endTime = _endTime;
        electionData.config.timing.timezone = _timezone;
        electionData.config.votingSettings.maxVotersCount = _maxVotersCount;
        electionData.config.messages.loginInstructions = _loginInstructions;
        electionData.config.messages.voteConfirmation = _voteConfirmation;
        electionData.config.messages.afterElectionMessage = _afterElectionMessage;
        electionData.config.resultsConfig.realTimeResults = _realTimeResults;
        electionData.config.resultsConfig.resultsReleaseTime = _resultsReleaseTime;
        
        emit ElectionUpdated(msg.sender, "fullConfig");
    }

    function updateElectionBasicInfo(string calldata _title, string calldata _description)
        external onlyElectionCreator notDeleted
    {
        require(electionData.config.basicInfo.status == ElectionStatus.DRAFT, "Can only update draft elections");
        ElectionStorage.validateStrings(_title, _description, "", "", "");
        electionData.config.basicInfo.title = _title;
        electionData.config.basicInfo.description = _description;
        emit ElectionUpdated(msg.sender, "basicInfo");
    }

    function changeElectionStatus(ElectionStatus _newStatus) external override onlyCreatorOrFactory notDeleted {
        ElectionStatus currentStatus = electionData.config.basicInfo.status;
        require(currentStatus != _newStatus, "Status unchanged");
        ElectionStorage.validateStatusTransition(currentStatus, _newStatus);
        electionData.config.basicInfo.status = _newStatus;
        emit ElectionStatusChanged(currentStatus, _newStatus);
    }

    function deleteElection() external override onlyElectionCreator notDeleted {
        require(electionData.config.basicInfo.status != ElectionStatus.ACTIVE, "Cannot delete active election");
        electionData.config.basicInfo.status = ElectionStatus.DELETED;
        emit ElectionStatusChanged(electionData.config.basicInfo.status, ElectionStatus.DELETED);
    }

    function addElectionMetadata(string calldata _electionMetadataUri, string calldata _ballotMetadataUri)
        external override onlyCreatorOrFactory notDeleted
    {
        electionData.electionMetadataUri = _electionMetadataUri;
        electionData.ballotMetadataUri = _ballotMetadataUri;
        emit ElectionMetadataUpdated(_electionMetadataUri, _ballotMetadataUri);
    }

    function addBallot(string calldata _title, string calldata _description, bool _isMultipleChoice, string calldata _ipfsCid)
        external override onlyElectionCreator notDeleted
    {
        require(electionData.config.basicInfo.status == ElectionStatus.DRAFT, "Can only add ballots to draft elections");
        electionData.ballotCount++;
        uint256 ballotId = electionData.ballotCount;
        electionData.ballots[ballotId] = Ballot({
            id: ballotId,
            title: _title,
            description: _description,
            isMultipleChoice: _isMultipleChoice,
            ipfsCid: _ipfsCid,
            createdAt: block.timestamp
        });
        emit BallotAdded(ballotId, _title, _isMultipleChoice, _ipfsCid);
    }

    function addVoter(address _voterAddress, string calldata _voterId, uint256 _voteWeight, bytes32 _voterKeyHash)
        external override onlyElectionCreator notDeleted
    {
        electionData.addVoter(_voterAddress, _voterId, _voteWeight, _voterKeyHash);
        emit VoterAdded(_voterId, _voterAddress, _voteWeight);
    }

    function addVoters(
        address[] calldata _voterAddresses,
        string[] calldata _voterIds,
        uint256[] calldata _voteWeights,
        string calldata _ipfsCid
    ) external override onlyElectionCreator notDeleted {
        electionData.addVotersBatch(_voterAddresses, _voterIds, _voteWeights, _ipfsCid);
        emit VotersBatchAdded(_voterIds.length, _ipfsCid);
    }

    function castVote(string calldata _voterId, bytes32[] calldata _choices, string calldata _ipfsCid)
        external override onlyActiveElection onlyRegisteredVoter(_voterId) nonReentrant
    {
        Voter storage voter = electionData.votersByVoterId[_voterId];
        require(
            voter.voterAddress == msg.sender ||
            keccak256(abi.encodePacked(electionData.voterIdsByAddress[msg.sender])) == keccak256(abi.encodePacked(_voterId)),
            "Not authorized to vote for this ID"
        );
        require(!voter.hasVoted, "Voter has already voted");
        electionData.recordVote(_voterId, _choices, _ipfsCid);
    }

    function castVoteWithKey(string calldata _voterId, bytes32 _voterKeyHash, bytes32[] calldata _choices, string calldata _ipfsCid)
        external override onlyActiveElection onlyRegisteredVoter(_voterId) nonReentrant
    {
        require(electionData.voterKeyHashes[_voterKeyHash], "Invalid voter key");
        Voter storage voter = electionData.votersByVoterId[_voterId];
        require(!voter.hasVoted, "Voter has already voted");
        electionData.recordVote(_voterId, _choices, _ipfsCid);
    }

    function castVoteWithPaymaster(string calldata _voterId, bytes32 _voterKeyHash, bytes32[] calldata _choices, string calldata _ipfsCid)
        external override onlyAuthorizedPaymaster onlyActiveElection onlyRegisteredVoter(_voterId) nonReentrant
    {
        require(electionData.voterKeyHashes[_voterKeyHash], "Invalid voter key");
        Voter storage voter = electionData.votersByVoterId[_voterId];
        require(!voter.hasVoted, "Voter has already voted");
        electionData.recordVote(_voterId, _choices, _ipfsCid);
    }

    function setElectionUrl(string calldata _electionUrl) external override onlyCreatorOrFactory notDeleted {
        electionData.electionUrl = _electionUrl;
        emit ElectionUrlGenerated(_electionUrl);
    }

    function setPaymaster(address _paymaster, bool _authorized) external override onlyElectionCreator notDeleted {
        require(_paymaster != address(0), "Invalid paymaster address");
        if (_authorized && electionData.paymaster == address(0)) {
            electionData.paymaster = _paymaster;
        }
        electionData.authorizedPaymasters[_paymaster] = _authorized;
        emit PaymasterUpdated(_paymaster, _authorized);
    }

    // ============ View Functions ============
    function getElection() external view notDeleted returns (ElectionConfig memory) {
        return electionData.config;
    }

    function getElectionBasicInfo() external view notDeleted returns (ElectionBasicInfo memory) {
        return electionData.config.basicInfo;
    }

    function getBallot(uint256 _ballotId) external view notDeleted returns (Ballot memory) {
        require(_ballotId > 0 && _ballotId <= electionData.ballotCount, "Invalid ballot ID");
        return electionData.ballots[_ballotId];
    }

    function getVoter(string calldata _voterId) external view notDeleted returns (Voter memory) {
        return electionData.votersByVoterId[_voterId];
    }

    function verifyVoterAccess(string calldata _voterId, bytes32 _voterKeyHash) external view notDeleted returns (bool) {
        return electionData.verifyVoterAccess(_voterId, _voterKeyHash);
    }

    function getVote(string calldata _voterId) external view notDeleted returns (Vote memory) {
        return electionData.votesByVoterId[_voterId];
    }

    // ============ Additional View Functions ============
    function ballotCount() external view returns (uint256) { return electionData.ballotCount; }
    function voterCount() external view returns (uint256) { return electionData.voterCount; }
    function voteCount() external view returns (uint256) { return electionData.voteCount; }
    function electionUrl() external view returns (string memory) { return electionData.electionUrl; }
}