// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IPaymaster.sol";
import "./Election.sol";

/**
 * @title ElectionPaymaster
 * @dev Paymaster contract for gasless voting in elections
 * @author Election System
 */
contract ElectionPaymaster is IPaymaster, Ownable, ReentrancyGuard, Pausable {
    // ============ State Variables ============

    // Factory contract reference
    address public electionFactory;

    // Election contracts authorized to use this paymaster
    mapping(address => bool) public authorizedElections;

    // Total votes processed
    uint256 public totalVotesProcessed;

    // Sponsored votes limit per election
    mapping(address => uint256) public electionVoteLimits;

    // Votes processed per election
    mapping(address => uint256) public electionVotesProcessed;

    // Voter nonces to prevent replay attacks
    mapping(bytes32 => bool) public usedNonces;

    // ============ Events ============

    event ElectionAuthorized(address indexed election, uint256 voteLimit);

    event ElectionUnauthorized(address indexed election);

    event VoteProcessed(
        address indexed election,
        string voterId,
        uint256 timestamp
    );

    event VoteLimitUpdated(address indexed election, uint256 newLimit);

    event FactoryUpdated(address indexed newFactory);

    // ============ Modifiers ============

    modifier onlyAuthorizedElection(address _election) {
        require(
            authorizedElections[_election],
            "ElectionPaymaster: Election not authorized"
        );
        require(
            electionVotesProcessed[_election] < electionVoteLimits[_election],
            "ElectionPaymaster: Vote limit exceeded for this election"
        );
        _;
    }

    modifier nonceNotUsed(bytes32 _nonce) {
        require(!usedNonces[_nonce], "ElectionPaymaster: Nonce already used");
        _;
    }

    // ============ Constructor ============

    constructor(address _electionFactory) Ownable(msg.sender) {
        electionFactory = _electionFactory;
    }

    // ============ External Functions ============

    /**
     * @dev Authorizes an election to use this paymaster
     * @param _election Address of the election contract
     * @param _voteLimit Maximum number of sponsored votes for this election
     */
    function authorizeElection(
        address _election,
        uint256 _voteLimit
    ) external override onlyOwner {
        // Verify that this is a valid election contract created by our factory
        require(
            _election != address(0),
            "ElectionPaymaster: Invalid election address"
        );

        authorizedElections[_election] = true;
        electionVoteLimits[_election] = _voteLimit;

        // Set this paymaster as authorized in the election contract
        Election election = Election(_election);
        election.setPaymaster(address(this), true);

        emit ElectionAuthorized(_election, _voteLimit);
    }

    /**
     * @dev Unauthorizes an election from using this paymaster
     * @param _election Address of the election contract
     */
    function unauthorizeElection(
        address _election
    ) external override onlyOwner {
        require(
            authorizedElections[_election],
            "ElectionPaymaster: Election not authorized"
        );

        authorizedElections[_election] = false;

        // Remove this paymaster from authorized list in the election contract
        Election election = Election(_election);
        election.setPaymaster(address(this), false);

        emit ElectionUnauthorized(_election);
    }

    /**
     * @dev Updates the vote limit for an election
     * @param _election Address of the election contract
     * @param _newLimit New vote limit
     */
    function updateVoteLimit(
        address _election,
        uint256 _newLimit
    ) external override onlyOwner {
        require(
            authorizedElections[_election],
            "ElectionPaymaster: Election not authorized"
        );

        electionVoteLimits[_election] = _newLimit;

        emit VoteLimitUpdated(_election, _newLimit);
    }

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
    )
        external
        override
        nonReentrant
        whenNotPaused
        onlyAuthorizedElection(_election)
        nonceNotUsed(_nonce)
    {
        // Mark nonce as used
        usedNonces[_nonce] = true;

        // Call the election contract
        Election election = Election(_election);
        election.castVoteWithPaymaster(
            _voterId,
            _voterKeyHash,
            _choices,
            _ipfsCid
        );

        // Update vote counts
        electionVotesProcessed[_election]++;
        totalVotesProcessed++;

        emit VoteProcessed(_election, _voterId, block.timestamp);
    }

    /**
     * @dev Updates the election factory address
     * @param _newFactory Address of the new factory
     */
    function updateFactory(address _newFactory) external onlyOwner {
        require(
            _newFactory != address(0),
            "ElectionPaymaster: Invalid factory address"
        );

        electionFactory = _newFactory;

        emit FactoryUpdated(_newFactory);
    }

    /**
     * @dev Pauses the paymaster
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the paymaster
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Allows the contract to receive ETH for gas costs
     */
    receive() external payable {}

    /**
     * @dev Withdraws ETH from the contract
     * @param _to Address to send ETH to
     * @param _amount Amount of ETH to withdraw
     */
    function withdraw(address payable _to, uint256 _amount) external onlyOwner {
        require(
            _to != address(0),
            "ElectionPaymaster: Invalid recipient address"
        );
        require(
            _amount <= address(this).balance,
            "ElectionPaymaster: Insufficient balance"
        );

        _to.transfer(_amount);
    }
}
