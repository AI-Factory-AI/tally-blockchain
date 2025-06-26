// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IElection
 * @dev Interface for the Election contract 
 */
interface IElection {
    /**
     * @dev Enum representing the different states an election can be in
     */
    enum ElectionState {
        Created,
        Registration,
        Voting,
        Ended
    }

    /**
     * @dev Enum representing the different types of voting systems 
     */
    enum VotingSystem {
        SingleChoice,
        RankedChoice,
        Weighted
    }

    /**
     * @dev Struct to represent a candidate
     */
    struct Candidate {
        uint256 id;
        string name;
        string information;
        uint256 voteCount;
    }

    /**
     * @dev Struct to represent a voter
     */
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        bytes32 voteHash; // For verification
    }

    /**
     * @dev Event emitted when a new election is created
     */
    event ElectionCreated(
        address indexed electionAddress,
        string name,
        uint256 startTime,
        uint256 endTime,
        VotingSystem votingSystem
    );

    /**
     * @dev Event emitted when a voter is registered
     */
    event VoterRegistered(address indexed voter);

    /**
     * @dev Event emitted when a vote is cast
     */
    event VoteCast(address indexed voter);

    /**
     * @dev Event emitted when the election state changes
     */
    event ElectionStateChanged(ElectionState newState);

    /**
     * @dev Function to register a voter
     * @param _voter Address of the voter to register
     */
    function registerVoter(address _voter) external;

    /**
     * @dev Function to cast a vote in a single choice election
     * @param _candidateId ID of the candidate to vote for
     */
    function castVote(uint256 _candidateId) external;

    /**
     * @dev Function to cast a ranked choice vote
     * @param _rankedCandidates Array of candidate IDs in order of preference
     */
    function castRankedVote(uint256[] calldata _rankedCandidates) external;

    /**
     * @dev Function to cast a weighted vote
     * @param _candidateIds Array of candidate IDs
     * @param _weights Array of weights corresponding to each candidate
     */
    function castWeightedVote(
        uint256[] calldata _candidateIds,
        uint256[] calldata _weights
    ) external;

    /**
     * @dev Function to verify a vote was recorded correctly
     * @param _voter Address of the voter
     * @return bool True if the vote was recorded
     */
    function verifyVote(address _voter) external view returns (bool);

    /**
     * @dev Function to get the current state of the election
     * @return ElectionState Current state
     */
    function getElectionState() external view returns (ElectionState);

    /**
     * @dev Function to get election results
     * @return Candidate[] Array of candidates with vote counts
     */
    function getResults() external view returns (Candidate[] memory);
}