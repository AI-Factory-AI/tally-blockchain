// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IElection.sol";

/**
 * @title IElectionFactory
 * @dev Interface for the election factory contract
 */
interface IElectionFactory {
    // ============ Structs ============
    
    /**
     * @dev Input struct for creating elections (avoids stack too deep)
     */
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
    
    /**
     * @dev Creates a new election with comprehensive configuration
     * @param input Complete election configuration input
     * @return electionId The ID of the newly created election
     * @return electionContract The address of the newly created election contract
     */
    function createElection(CreateElectionInput calldata input) 
        external 
        payable 
        returns (uint256 electionId, address electionContract);
    
    /**
     * @dev Deletes an election by marking it as deleted in the factory
     * @param _electionId ID of the election to delete
     */
    function deleteElection(uint256 _electionId) external;
    
    /**
     * @dev Gets the election contract address by ID
     * @param _electionId ID of the election
     * @return Address of the election contract
     */
    function getElectionContract(uint256 _electionId) external view returns (address);
    
    /**
     * @dev Gets complete election configuration by ID
     * @param _electionId ID of the election
     * @return Election configuration
     */
    function getElection(uint256 _electionId) 
        external 
        view 
        returns (IElection.ElectionConfig memory);
    
    /**
     * @dev Gets election basic information by ID
     * @param _electionId ID of the election
     * @return Basic election information
     */
    function getElectionBasicInfo(uint256 _electionId) 
        external 
        view 
        returns (IElection.ElectionBasicInfo memory);
    
    /**
     * @dev Gets elections created by a specific address
     * @param _creator Address of the creator
     * @return Array of election IDs
     */
    function getElectionsByCreator(address _creator) 
        external 
        view 
        returns (uint256[] memory);
    
    /**
     * @dev Gets the current election ID counter
     * @return Current election count
     */
    function getCurrentElectionId() external view returns (uint256);
    
    /**
     * @dev Gets all election IDs and their contract addresses
     * @return electionIds Array of election IDs
     * @return electionContracts Array of corresponding contract addresses
     */
    function getAllElections() 
        external 
        view 
        returns (uint256[] memory electionIds, address[] memory electionContracts);
}