// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IElectionPaymaster
 * @dev Interface for the paymaster contract that sponsors gas fees for elections
 */
interface IElectionPaymaster {
    /**
     * @dev Authorizes an election to use this paymaster
     * @param _election Address of the election contract
     * @param _voteLimit Maximum number of sponsored votes for this election
     */
    function authorizeElection(address _election, uint256 _voteLimit) external;
    
    /**
     * @dev Unauthorizes an election from using this paymaster
     * @param _election Address of the election contract
     */
    function unauthorizeElection(address _election) external;
    
    /**
     * @dev Updates the vote limit for an election
     * @param _election Address of the election contract
     * @param _newLimit New vote limit
     */
    function updateVoteLimit(address _election, uint256 _newLimit) external;
    
    /**
     * @dev Executes a vote on behalf of a voter (gasless voting)
     * @param _election Address of the election contract
     * @param _voterId ID of the voter
     * @param _voterKeyHash Hash of the voter's key
     * @param _choices Array of candidate choices
     * @param _ipfsCid IPFS CID for vote receipt
     * @param _nonce Unique nonce to prevent replay attacks
     */
    function executeVote(
        address _election,
        string calldata _voterId,
        bytes32 _voterKeyHash,
        bytes32[] calldata _choices,
        string calldata _ipfsCid,
        bytes32 _nonce
    ) external;
}