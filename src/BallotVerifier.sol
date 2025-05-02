// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title BallotVerifier
 * @dev Contract for verifying ballot integrity and voter eligibility
 */
contract BallotVerifier is AccessControl {
    using ECDSA for bytes32;
    using MerkleProof for bytes32[];

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    // Merkle root for eligible voters
    bytes32 public voterMerkleRoot;

    // Mapping to track used nonces to prevent replay attacks
    mapping(address => mapping(uint256 => bool)) public usedNonces;

    // Mapping to track used voter commitments
    mapping(bytes32 => bool) public usedCommitments;

    // Events
    event VoterEligibilityVerified(address indexed voter);
    event BallotVerified(address indexed voter, bytes32 ballotHash);
    event MerkleRootUpdated(bytes32 newRoot);

    /**
     * @dev Constructor
     * @param _admin Admin address
     * @param _initialMerkleRoot Initial merkle root for voter eligibility
     */
    constructor(address _admin, bytes32 _initialMerkleRoot) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(ADMIN_ROLE, _admin);
        _setupRole(VERIFIER_ROLE, _admin);
        
        voterMerkleRoot = _initialMerkleRoot;
    }

    /**
     * @dev Update the merkle root for eligible voters
     * @param _newMerkleRoot New merkle root
     */
    function updateMerkleRoot(bytes32 _newMerkleRoot) external onlyRole(ADMIN_ROLE) {
        voterMerkleRoot = _newMerkleRoot;
        emit MerkleRootUpdated(_newMerkleRoot);
    }

    /**
     * @dev Verify voter eligibility using merkle proof
     * @param _voter Address of the voter
     * @param _proof Merkle proof
     * @return bool True if eligible
     */
    function verifyVoterEligibility(
        address _voter,
        bytes32[] calldata _proof
    ) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_voter));
        return MerkleProof.verify(_proof, voterMerkleRoot, leaf);
    }

    /**
     * @dev Verify a ballot signature
     * @param _electionAddress Address of the election contract
     * @param _ballotData Encoded ballot data
     * @param _signature Signature of the ballot data
     * @param _nonce Nonce to prevent replay attacks
     * @return address Signer address
     */
    function verifyBallotSignature(
        address _electionAddress,
        bytes calldata _ballotData,
        bytes calldata _signature,
        uint256 _nonce
    ) external returns (address) {
        // Create the message hash
        bytes32 messageHash = keccak256(abi.encodePacked(
            _electionAddress,
            _ballotData,
            _nonce
        ));
        
        // Recover the signer
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(_signature);
        
        // Ensure signer is not zero address
        require(signer != address(0), "Invalid signature");
        
        // Check if nonce has been used
        require(!usedNonces[signer][_nonce], "Nonce already used");
        
        // Mark nonce as used
        usedNonces[signer][_nonce] = true;
        
        // Create ballot hash for traceability
        bytes32 ballotHash = keccak256(abi.encodePacked(signer, _ballotData));
        
        emit BallotVerified(signer, ballotHash);
        
        return signer;
    }

    /**
     * @dev Register a vote commitment to prevent double voting
     * @param _commitment Hash commitment of the vote
     * @return bool True if commitment is accepted (not previously used)
     */
    function registerVoteCommitment(bytes32 _commitment) external onlyRole(VERIFIER_ROLE) returns (bool) {
        require(_commitment != bytes32(0), "Invalid commitment");
        
        if (usedCommitments[_commitment]) {
            return false;
        }
        
        usedCommitments[_commitment] = true;
        return true;
    }

    /**
     * @dev Check if a vote commitment has been used
     * @param _commitment Hash commitment of the vote
     * @return bool True if commitment has been used
     */
    function isCommitmentUsed(bytes32 _commitment) external view returns (bool) {
        return usedCommitments[_commitment];
    }

    /**
     * @dev Generate a vote commitment from voter and vote data
     * @param _voter Address of the voter
     * @param _voteData Encoded vote data
     * @return bytes32 Commitment hash
     */
    function generateCommitment(
        address _voter,
        bytes calldata _voteData
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_voter, _voteData));
    }
}