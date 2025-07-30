// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IElection.sol";

/**
 * @title ElectionStorage
 * @dev Library for managing election storage structures
 */
library ElectionStorage {
    // ============ Constants ============
    uint256 internal constant MAX_TITLE_LENGTH = 200;
    uint256 internal constant MAX_DESCRIPTION_LENGTH = 5000;
    uint256 internal constant MAX_MESSAGE_LENGTH = 2000;
    uint256 internal constant MIN_ELECTION_DURATION = 1 hours;
    uint256 internal constant MAX_ELECTION_DURATION = 365 days;

    struct ElectionData {
        IElection.ElectionConfig config;
        address factory;
        string electionMetadataUri;
        string ballotMetadataUri;
        string voterMetadataUri;
        string electionUrl;
        mapping(uint256 => IElection.Ballot) ballots;
        uint256 ballotCount;
        mapping(string => IElection.Voter) votersByVoterId;
        mapping(address => string) voterIdsByAddress;
        mapping(bytes32 => bool) voterKeyHashes;
        uint256 voterCount;
        mapping(string => IElection.Vote) votesByVoterId;
        uint256 voteCount;
        address paymaster;
        mapping(address => bool) authorizedPaymasters;
    }

    function validateTiming(uint256 _startTime, uint256 _endTime) internal view {
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_endTime - _startTime >= MIN_ELECTION_DURATION, "Election duration too short");
        require(_endTime - _startTime <= MAX_ELECTION_DURATION, "Election duration too long");
    }

    function validateStrings(
        string memory _title,
        string memory _description,
        string memory _loginInstructions,
        string memory _voteConfirmation,
        string memory _afterElectionMessage
    ) internal pure {
        require(bytes(_title).length > 0 && bytes(_title).length <= MAX_TITLE_LENGTH, "Invalid title length");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(bytes(_loginInstructions).length <= MAX_MESSAGE_LENGTH, "Login instructions too long");
        require(bytes(_voteConfirmation).length <= MAX_MESSAGE_LENGTH, "Vote confirmation too long");
        require(bytes(_afterElectionMessage).length <= MAX_MESSAGE_LENGTH, "After election message too long");
    }

    function validateStatusTransition(
        IElection.ElectionStatus _currentStatus,
        IElection.ElectionStatus _newStatus
    ) internal pure {
        if (_currentStatus == IElection.ElectionStatus.DRAFT) {
            require(
                _newStatus == IElection.ElectionStatus.SCHEDULED ||
                _newStatus == IElection.ElectionStatus.CANCELLED,
                "Invalid status transition from DRAFT"
            );
        } else if (_currentStatus == IElection.ElectionStatus.SCHEDULED) {
            require(
                _newStatus == IElection.ElectionStatus.ACTIVE ||
                _newStatus == IElection.ElectionStatus.CANCELLED,
                "Invalid status transition from SCHEDULED"
            );
        } else if (_currentStatus == IElection.ElectionStatus.ACTIVE) {
            require(
                _newStatus == IElection.ElectionStatus.COMPLETED,
                "Invalid status transition from ACTIVE"
            );
        } else {
            revert("Invalid status transition");
        }
    }
}