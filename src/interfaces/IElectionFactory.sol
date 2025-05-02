// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IElection.sol";

/**
 * @title IElectionFactory
 * @dev Interface for the ElectionFactory contract
 */
interface IElectionFactory {
    /**
     * @dev Event emitted when a new election is created
     */
    event ElectionCreated(
        address indexed electionAddress,
        string name,
        address indexed creator
    );

    /**
     * @dev Function to create a new election
     * @param _name Name of the election
     * @param _description Description of the election
     * @param _startTime Start time of the election (Unix timestamp)
     * @param _endTime End time of the election (Unix timestamp)
     * @param _votingSystem Type of voting system to use
     * @param _candidateNames Array of candidate names
     * @param _candidateInfo Array of candidate information
     * @return address Address of the created election contract
     */
    function createElection(
        string calldata _name,
        string calldata _description,
        uint256 _startTime,
        uint256 _endTime,
        IElection.VotingSystem _votingSystem,
        string[] calldata _candidateNames,
        string[] calldata _candidateInfo
    ) external returns (address);

    /**
     * @dev Function to get all elections created by a specific organization
     * @param _creator Address of the election creator
     * @return address[] Array of election addresses
     */
    function getElectionsByCreator(address _creator) external view returns (address[] memory);
    
    /**
     * @dev Function to validate if an address is a valid election
     * @param _election Address to check
     * @return bool True if the address is a valid election created by this factory
     */
    function isValidElection(address _election) external view returns (bool);
}