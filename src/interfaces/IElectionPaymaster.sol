// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@account-abstraction/contracts/interfaces/IPaymaster.sol";

/**
 * @title IElectionPaymaster
 * @dev Interface for the ElectionPaymaster contract which extends IPaymaster
 * This paymaster sponsors gas for election-related transactions
 */
interface IElectionPaymaster is IPaymaster {
    /**
     * @dev Event emitted when an election is registered for gas sponsorship
     */
    event ElectionRegistered(address indexed electionAddress);
    
    /**
     * @dev Event emitted when an election is removed from gas sponsorship
     */
    event ElectionRemoved(address indexed electionAddress);
    
    /**
     * @dev Event emitted when a gasless transaction is sponsored
     */
    event TransactionSponsored(
        address indexed electionAddress, 
        address indexed voter,
        uint256 gasUsed
    );

    /**
     * @dev Function to register an election for gas sponsorship
     * @param _electionAddress Address of the election contract
     */
    function registerElection(address _electionAddress) external;
    
    /**
     * @dev Function to remove an election from gas sponsorship
     * @param _electionAddress Address of the election contract
     */
    function removeElection(address _electionAddress) external;
    
    /**
     * @dev Function to check if an election is registered for gas sponsorship
     * @param _electionAddress Address of the election contract
     * @return bool True if the election is registered
     */
    function isElectionRegistered(address _electionAddress) external view returns (bool);
    
    /**
     * @dev Function to add funds to the paymaster
     * Only callable by the owner
     */
    function addFunds() external payable;
    
    /**
     * @dev Function to withdraw funds from the paymaster
     * @param _amount Amount to withdraw
     * Only callable by the owner
     */
    function withdrawFunds(uint256 _amount) external;
}