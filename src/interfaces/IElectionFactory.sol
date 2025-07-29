// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IElection.sol";

/**
 * @title IElectionFactory
 * @dev Interface for ElectionFactory contracts
 */
interface IElectionFactory {
    // ============ Structs ============
    struct CreateElectionInput {
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        string timezone;
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

    // ============ Functions ============
    function createElection(CreateElectionInput calldata input) external payable returns (uint256 electionId, address electionContract);
    function deleteElection(uint256 _electionId) external;
    function getElectionContract(uint256 _electionId) external view returns (address);
    function getElection(uint256 _electionId) external view returns (IElection.ElectionConfig memory);
    function getElectionBasicInfo(uint256 _electionId) external view returns (IElection.ElectionBasicInfo memory);
    function getElectionsByCreator(address _creator) external view returns (uint256[] memory);
    function getCurrentElectionId() external view returns (uint256);
    function getAllElections() external view returns (uint256[] memory electionIds, address[] memory electionContracts);
}