// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IElectionPaymaster.sol";
import "./Election.sol";
import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";


/**
 * @title ElectionPaymaster
 * @dev Paymaster contract for gasless voting in elections
 * @author Election System
 */
contract ElectionPaymaster is BasePaymaster, Pausable, IElectionPaymaster {
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

    // ============ Constructor ============

    constructor(IEntryPoint _entryPoint, address _electionFactory) BasePaymaster(_entryPoint) {
        electionFactory = _electionFactory;
    }

    // ============ Election Management ============

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

    // ============ EIP-4337 Paymaster Logic ============

    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 /*maxCost*/
    ) internal override whenNotPaused returns (bytes memory context, uint256 validationData) {
        // Decode callData to extract election address and enforce authorization/limits
        (address electionAddr, string memory voterId, bytes32 voterKeyHash, bytes32[] memory choices, string memory ipfsCid) = abi.decode(userOp.callData[4:], (address, string, bytes32, bytes32[], string));
        require(authorizedElections[electionAddr], "ElectionPaymaster: Election not authorized");
        require(electionVotesProcessed[electionAddr] < electionVoteLimits[electionAddr], "ElectionPaymaster: Vote limit exceeded for this election");
        // Optionally, add more checks (e.g., time, signature, etc.)
        // Return context for postOp
        context = abi.encode(electionAddr, voterId);
        validationData = 0; // 0 = valid
    }
    function _postOp(
        IPaymaster.PostOpMode mode,
        bytes calldata context,
        uint256 /*actualGasCost*/,
        uint256 /*actualUserOpFeePerGas*/
    ) internal override {
        // Decode context
        (address electionAddr, string memory voterId) = abi.decode(context, (address, string));
        if (mode == IPaymaster.PostOpMode.opSucceeded) {
            electionVotesProcessed[electionAddr]++;
            totalVotesProcessed++;
            emit VoteProcessed(electionAddr, voterId, block.timestamp);
        }
        // If opReverted, you may want to handle differently (e.g., log, revert, etc.)
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

    function executeVote(
        address _election,
        string calldata _voterId,
        bytes32 _voterKeyHash,
        bytes32[] calldata _choices,
        string calldata _ipfsCid,
        bytes32 _nonce
    ) external override {
        revert("ElectionPaymaster: executeVote not implemented");
    }
}
