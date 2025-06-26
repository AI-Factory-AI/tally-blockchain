// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IElection.sol";
import "../interfaces/IVoteVerification.sol";

/**
 * @title Election
 * @dev Implementation of the IElection interface for managing a blockchain-based election
 */
contract Election is IElection, AccessControl, ReentrancyGuard {
    using ECDSA for bytes32;

    // Constants for role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VOTER_REGISTRAR_ROLE = keccak256("VOTER_REGISTRAR_ROLE");

    // Election metadata
    string public name;
    string public description;
    uint256 public startTime;
    uint256 public endTime;
    VotingSystem public votingSystem;
    ElectionState public state;

    // Election data structures
    Candidate[] public candidates;
    mapping(address => Voter) public voters;
    mapping(uint256 => bool) public candidateExists;
    uint256 public voterCount;
    uint256 public totalVotes;

    // For ranked choice voting
    mapping(address => uint256[]) private rankedVotes;
    
    // For weighted voting
    mapping(address => mapping(uint256 => uint256)) private weightedVotes;
    uint256 public constant WEIGHT_PRECISION = 1e6; // precision for weighted votes

    // For additional verification
    mapping(address => bytes) private signatures;

    // Modifiers
    modifier onlyDuringState(ElectionState _state) {
        require(state == _state, "Invalid election state for this operation");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        _;
    }

    modifier hasNotVoted() {
        require(!voters[msg.sender].hasVoted, "Voter has already voted");
        _;
    }

    modifier electionActive() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Election not active");
        require(state == ElectionState.Voting, "Election not in voting state");
        _;
    }

    /**
     * @dev Constructor to create a new election
     */
    constructor(
        string memory _name,
        string memory _description,
        uint256 _startTime,
        uint256 _endTime,
        VotingSystem _votingSystem,
        string[] memory _candidateNames,
        string[] memory _candidateInfo,
        address _admin
    ) {
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_candidateNames.length > 0, "Must have at least one candidate");
        require(_candidateNames.length == _candidateInfo.length, "Candidate names and info must match");

        name = _name;
        description = _description;
        startTime = _startTime;
        endTime = _endTime;
        votingSystem = _votingSystem;
        state = ElectionState.Registration;

        // Setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(ADMIN_ROLE, _admin);
        _setupRole(VOTER_REGISTRAR_ROLE, _admin);

        // Add candidates
        for (uint256 i = 0; i < _candidateNames.length; i++) {
            candidates.push(
                Candidate({
                    id: i + 1,
                    name: _candidateNames[i],
                    information: _candidateInfo[i],
                    voteCount: 0
                })
            );
            candidateExists[i + 1] = true;
        }

        emit ElectionCreated(address(this), _name, _startTime, _endTime, _votingSystem);
    }

    /**
     * @dev Function to register a voter
     * @param _voter Address of the voter
     */
    function registerVoter(address _voter) external override onlyRole(VOTER_REGISTRAR_ROLE) onlyDuringState(ElectionState.Registration) {
        require(_voter != address(0), "Invalid voter address");
        require(!voters[_voter].isRegistered, "Voter already registered");

        voters[_voter].isRegistered = true;
        voterCount++;

        emit VoterRegistered(_voter);
    }

    /**
     * @dev Function to cast a vote in a single choice election
     * @param _candidateId ID of the candidate
     */
    function castVote(uint256 _candidateId) external override onlyRegisteredVoter hasNotVoted electionActive {
        require(votingSystem == VotingSystem.SingleChoice, "Incorrect voting method");
        require(candidateExists[_candidateId], "Invalid candidate ID");

        _recordVote(msg.sender);
        candidates[_candidateId - 1].voteCount++;
        totalVotes++;

        // Create a hash of the vote for verification
        voters[msg.sender].voteHash = keccak256(abi.encodePacked(msg.sender, _candidateId));

        emit VoteCast(msg.sender);
    }

    /**
     * @dev Function to cast a ranked choice vote
     * @param _rankedCandidates Array of candidate IDs in order of preference
     */
    function castRankedVote(uint256[] calldata _rankedCandidates) external override onlyRegisteredVoter hasNotVoted electionActive {
        require(votingSystem == VotingSystem.RankedChoice, "Incorrect voting method");
        require(_rankedCandidates.length > 0, "Must rank at least one candidate");
        
        // Validate candidate IDs
        for (uint256 i = 0; i < _rankedCandidates.length; i++) {
            require(candidateExists[_rankedCandidates[i]], "Invalid candidate ID");
        }

        _recordVote(msg.sender);
        
        // Store ranked vote
        rankedVotes[msg.sender] = _rankedCandidates;
        
        // Count first choice votes for initial tally
        candidates[_rankedCandidates[0] - 1].voteCount++;
        totalVotes++;

        // Create a hash of the vote for verification
        voters[msg.sender].voteHash = keccak256(abi.encodePacked(msg.sender, _rankedCandidates));

        emit VoteCast(msg.sender);
    }

    /**
     * @dev Function to cast a weighted vote
     * @param _candidateIds Array of candidate IDs
     * @param _weights Array of weights corresponding to each candidate
     */
    function castWeightedVote(
        uint256[] calldata _candidateIds,
        uint256[] calldata _weights
    ) external override onlyRegisteredVoter hasNotVoted electionActive {
        require(votingSystem == VotingSystem.Weighted, "Incorrect voting method");
        require(_candidateIds.length > 0, "Must vote for at least one candidate");
        require(_candidateIds.length == _weights.length, "Candidate IDs and weights must match");
        
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _weights.length; i++) {
            totalWeight += _weights[i];
        }
        require(totalWeight == WEIGHT_PRECISION, "Total weight must equal precision value");

        _recordVote(msg.sender);
        
        // Store weighted votes and update vote counts
        for (uint256 i = 0; i < _candidateIds.length; i++) {
            require(candidateExists[_candidateIds[i]], "Invalid candidate ID");
            weightedVotes[msg.sender][_candidateIds[i]] = _weights[i];
            
            // Update vote count proportionally
            candidates[_candidateIds[i] - 1].voteCount += _weights[i];
        }
        totalVotes++;

        // Create a hash of the vote for verification
        voters[msg.sender].voteHash = keccak256(abi.encodePacked(msg.sender, _candidateIds, _weights));

        emit VoteCast(msg.sender);
    }

    /**
     * @dev Internal function to record a vote
     * @param _voter Address of the voter
     */
    function _recordVote(address _voter) private {
        voters[_voter].hasVoted = true;
    }

    /**
     * @dev Function to verify a vote was recorded
     * @param _voter Address of the voter
     * @return bool True if the vote was recorded
     */
    function verifyVote(address _voter) external view override returns (bool) {
        return voters[_voter].hasVoted;
    }

    /**
     * @dev Function to get the hash of a voter's vote
     * @param _voter Address of the voter
     * @return bytes32 Hash of the vote
     */
    function getVoteHash(address _voter) external view returns (bytes32) {
        require(voters[_voter].hasVoted, "Voter has not voted");
        return voters[_voter].voteHash;
    }

    /**
     * @dev Function to start the election
     * Only callable by admin
     */
    function startElection() external onlyRole(ADMIN_ROLE) {
        require(block.timestamp >= startTime, "Start time not reached");
        require(state == ElectionState.Registration, "Election not in registration state");
        
        state = ElectionState.Voting;
        emit ElectionStateChanged(ElectionState.Voting);
    }

    /**
     * @dev Function to end the election
     * Only callable by admin, or automatically when endTime is reached
     */
    function endElection() external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || block.timestamp > endTime,
            "Not authorized or end time not reached"
        );
        require(state == ElectionState.Voting, "Election not in voting state");
        
        state = ElectionState.Ended;
        emit ElectionStateChanged(ElectionState.Ended);
    }

    /**
     * @dev Function to get the current state of the election
     * @return ElectionState Current state
     */
    function getElectionState() external view override returns (ElectionState) {
        if (state == ElectionState.Voting && block.timestamp > endTime) {
            return ElectionState.Ended;
        }
        return state;
    }

    /**
     * @dev Function to get all candidates
     * @return Candidate[] Array of candidates
     */
    function getCandidates() external view returns (Candidate[] memory) {
        return candidates;
    }

    /**
     * @dev Function to get the number of candidates
     * @return uint256 Number of candidates
     */
    function getCandidateCount() external view returns (uint256) {
        return candidates.length;
    }

    /**
     * @dev Function to get election results
     * @return Candidate[] Array of candidates with vote counts
     */
    function getResults() external view override returns (Candidate[] memory) {
        require(
            state == ElectionState.Ended || block.timestamp > endTime,
            "Election still in progress"
        );
        
        return candidates;
    }

    /**
     * @dev Function to calculate final results for ranked choice voting
     * Only relevant for ranked choice elections and callable after election ends
     * @return Candidate[] Final results after elimination rounds
     */
    function calculateRankedChoiceResults() external view onlyRole(ADMIN_ROLE) returns (Candidate[] memory) {
        require(votingSystem == VotingSystem.RankedChoice, "Not a ranked choice election");
        require(state == ElectionState.Ended || block.timestamp > endTime, "Election still in progress");
        
        // In a real implementation, this would run the instant-runoff algorithm
        // For simplicity, we're just returning the current vote counts
        return candidates;
    }

    /**
     * @dev Function to update the election metadata
     * Only callable by admin and before voting starts
     */
    function updateElectionMetadata(
        string calldata _newName,
        string calldata _newDescription
    ) external onlyRole(ADMIN_ROLE) {
        require(state == ElectionState.Registration, "Cannot update after registration period");
        
        name = _newName;
        description = _newDescription;
    }

    /**
     * @dev Function to extend voting period
     * Only callable by admin and before the election ends
     */
    function extendVotingPeriod(uint256 _newEndTime) external onlyRole(ADMIN_ROLE) {
        require(state == ElectionState.Voting, "Election not in voting state");
        require(block.timestamp < endTime, "Election already ended");
        require(_newEndTime > endTime, "New end time must be later than current end time");
        
        endTime = _newEndTime;
    }

    /**
     * @dev Function to get the participation rate
     * @return uint256 Participation rate as a percentage (with 2 decimal precision)
     */
    function getParticipationRate() external view returns (uint256) {
        if (voterCount == 0) return 0;
        return (totalVotes * 10000) / voterCount; // Returns percentage with 2 decimal places
    }
}