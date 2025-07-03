// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IElection
 * @dev Interface for the election contract
 */
interface IElection {
    // ============ Enums ============

    enum ElectionStatus {
        DRAFT,
        SCHEDULED,
        ACTIVE,
        COMPLETED,
        CANCELLED,
        DELETED
    }

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

    /**
     * @dev Struct for ballot information
     */
    struct Ballot {
        uint256 id;
        string title;
        string description;
        bool isMultipleChoice;
        string ipfsCid; // IPFS CID for detailed ballot data
        uint256 createdAt;
    }

    /**
     * @dev Struct for voter information
     */
    struct Voter {
        string voterId;
        address voterAddress;
        uint256 voteWeight;
        bool hasVoted;
        uint256 registeredAt;
    }

    /**
     * @dev Struct for vote information
     */
    struct Vote {
        string voterId;
        bytes32[] choices;
        uint256 timestamp;
        string ipfsCid;
    }

    // ============ Functions ============

    /**
     * @dev Changes election status
     * @param _newStatus New status
     */
    function changeElectionStatus(ElectionStatus _newStatus) external;

    /**
     * @dev Deletes an election (soft delete by changing status)
     */
    function deleteElection() external;

    /**
     * @dev Adds IPFS metadata to the election
     * @param _electionMetadataUri IPFS URI for election metadata
     * @param _ballotMetadataUri IPFS URI for ballot metadata
     */
    function addElectionMetadata(
        string calldata _electionMetadataUri,
        string calldata _ballotMetadataUri
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

    /**
     * @dev Sets the election URL
     * @param _electionUrl URL for accessing the election
     */
    function setElectionUrl(string calldata _electionUrl) external;

    /**
     * @dev Sets an authorized paymaster
     * @param _paymaster Address of the paymaster
     * @param _authorized Whether the paymaster is authorized
     */
    function setPaymaster(address _paymaster, bool _authorized) external;
}
