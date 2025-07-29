// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IElection
 * @dev Interface for Election contracts
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
    struct ElectionBasicInfo {
        string title;
        string description;
        address creator;
        uint256 createdAt;
        ElectionStatus status;
    }

    struct ElectionTiming {
        uint256 startTime;
        uint256 endTime;
        string timezone;
    }

    struct VotingSettings {
        bool ballotReceipt;
        bool submitConfirmation;
        uint256 maxVotersCount;
        bool allowVoterRegistration;
    }

    struct ElectionMessages {
        string loginInstructions;
        string voteConfirmation;
        string afterElectionMessage;
    }

    struct ResultsConfig {
        bool publicResults;
        bool realTimeResults;
        uint256 resultsReleaseTime;
        bool allowResultsDownload;
    }

    struct ElectionConfig {
        ElectionBasicInfo basicInfo;
        ElectionTiming timing;
        VotingSettings votingSettings;
        ElectionMessages messages;
        ResultsConfig resultsConfig;
    }

    struct Ballot {
        uint256 id;
        string title;
        string description;
        bool isMultipleChoice;
        string ipfsCid;
        uint256 createdAt;
    }

    struct Voter {
        string voterId;
        address voterAddress;
        uint256 voteWeight;
        bool hasVoted;
        uint256 registeredAt;
    }

    struct Vote {
        string voterId;
        bytes32[] choices;
        uint256 timestamp;
        string ipfsCid;
    }

    // ============ Functions ============
    function changeElectionStatus(ElectionStatus _newStatus) external;
    function deleteElection() external;
    function addElectionMetadata(string calldata _electionMetadataUri, string calldata _ballotMetadataUri) external;
    function addBallot(string calldata _title, string calldata _description, bool _isMultipleChoice, string calldata _ipfsCid) external;
    function addVoter(address _voterAddress, string calldata _voterId, uint256 _voteWeight, bytes32 _voterKeyHash) external;
    function addVoters(address[] calldata _voterAddresses, string[] calldata _voterIds, uint256[] calldata _voteWeights, string calldata _ipfsCid) external;
    function castVote(string calldata _voterId, bytes32[] calldata _choices, string calldata _ipfsCid) external;
    function castVoteWithKey(string calldata _voterId, bytes32 _voterKeyHash, bytes32[] calldata _choices, string calldata _ipfsCid) external;
    function castVoteWithPaymaster(string calldata _voterId, bytes32 _voterKeyHash, bytes32[] calldata _choices, string calldata _ipfsCid) external;
    function setElectionUrl(string calldata _electionUrl) external;
    function setPaymaster(address _paymaster, bool _authorized) external;
}