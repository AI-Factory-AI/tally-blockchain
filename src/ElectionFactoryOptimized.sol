// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IElectionFactory.sol";
import "./interfaces/IElection.sol";
import "./ElectionCore.sol";

/**
 * @title ElectionFactoryOptimized
 * @dev Optimized factory contract for creating elections
 */
contract ElectionFactoryOptimized is IElectionFactory, Ownable, ReentrancyGuard, Pausable {
    uint256 private _electionIds;
    uint256 public electionCreationFee;

    mapping(uint256 => address) public elections;
    mapping(address => uint256[]) public creatorElections;
    mapping(uint256 => bool) public electionExists;
    mapping(address => bool) public isElectionContract;

    event ElectionCreated(
        uint256 indexed electionId,
        address indexed electionContract,
        address indexed creator,
        string title,
        uint256 startTime,
        uint256 endTime
    );

    event ElectionDeleted(uint256 indexed electionId, address indexed electionContract, address indexed deleter);
    event ElectionFeeUpdated(uint256 oldFee, uint256 newFee);

    modifier validElectionTiming(uint256 _startTime, uint256 _endTime) {
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_endTime - _startTime >= 1 hours, "Election duration too short");
        require(_endTime - _startTime <= 365 days, "Election duration too long");
        _;
    }

    modifier electionMustExist(uint256 _electionId) {
        require(electionExists[_electionId], "Election does not exist");
        _;
    }

    constructor(uint256 _electionCreationFee) Ownable(msg.sender) {
        electionCreationFee = _electionCreationFee;
    }

    function createElection(CreateElectionInput calldata input)
        external
        payable
        override
        nonReentrant
        whenNotPaused
        validElectionTiming(input.startTime, input.endTime)
        returns (uint256 electionId, address electionContract)
    {
        require(msg.value >= electionCreationFee, "Insufficient fee");
        _validateElectionStrings(input);

        _electionIds++;
        electionId = _electionIds;

        // Deploy new Election contract with hardcoded values
        ElectionCore newElection = new ElectionCore();
        electionContract = address(newElection);

        // Initialize the election with custom parameters
        newElection.initializeElectionConfig(
            input.title,
            input.description,
            input.startTime,
            input.endTime,
            input.timezone,
            input.maxVotersCount,
            input.loginInstructions,
            input.voteConfirmation,
            input.afterElectionMessage,
            input.realTimeResults,
            input.resultsReleaseTime
        );

        // Update mappings
        elections[electionId] = electionContract;
        electionExists[electionId] = true;
        isElectionContract[electionContract] = true;
        creatorElections[msg.sender].push(electionId);

        // Generate election URL
        string memory electionUrl = string(abi.encodePacked("https://tally/vote/", _uint2str(electionId)));
        newElection.setElectionUrl(electionUrl);

        emit ElectionCreated(electionId, electionContract, msg.sender, input.title, input.startTime, input.endTime);

        // Refund excess payment
        if (msg.value > electionCreationFee) {
            payable(msg.sender).transfer(msg.value - electionCreationFee);
        }

        return (electionId, electionContract);
    }

    function deleteElection(uint256 _electionId) external override electionMustExist(_electionId) {
        address electionContract = elections[_electionId];
        ElectionCore election = ElectionCore(electionContract);

        IElection.ElectionBasicInfo memory basicInfo = election.getElectionBasicInfo();
        require(basicInfo.creator == msg.sender, "Not the election creator");

        election.deleteElection();
        emit ElectionDeleted(_electionId, electionContract, msg.sender);
    }

    // ============ View Functions ============
    function getElectionContract(uint256 _electionId) external view override electionMustExist(_electionId) returns (address) {
        return elections[_electionId];
    }

    function getElection(uint256 _electionId) external view override electionMustExist(_electionId) returns (IElection.ElectionConfig memory) {
        ElectionCore election = ElectionCore(elections[_electionId]);
        return election.getElection();
    }

    function getElectionBasicInfo(uint256 _electionId) external view override electionMustExist(_electionId) returns (IElection.ElectionBasicInfo memory) {
        ElectionCore election = ElectionCore(elections[_electionId]);
        return election.getElectionBasicInfo();
    }

    function getElectionsByCreator(address _creator) external view override returns (uint256[] memory) {
        return creatorElections[_creator];
    }

    function getCurrentElectionId() external view override returns (uint256) {
        return _electionIds;
    }

    function getAllElections() external view override returns (uint256[] memory electionIds, address[] memory electionContracts) {
        uint256 totalElections = _electionIds;
        electionIds = new uint256[](totalElections);
        electionContracts = new address[](totalElections);

        for (uint256 i = 1; i <= totalElections; i++) {
            electionIds[i - 1] = i;
            electionContracts[i - 1] = elections[i];
        }

        return (electionIds, electionContracts);
    }

    // ============ Owner Functions ============
    function updateElectionFee(uint256 _newFee) external onlyOwner {
        uint256 oldFee = electionCreationFee;
        electionCreationFee = _newFee;
        emit ElectionFeeUpdated(oldFee, _newFee);
    }

    function withdrawFees(address payable _to) external onlyOwner {
        require(_to != address(0), "Invalid address");
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        _to.transfer(balance);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // ============ Internal Functions ============
    function _validateElectionStrings(CreateElectionInput calldata input) internal pure {
        require(bytes(input.title).length > 0, "Title cannot be empty");
        require(bytes(input.title).length <= 200, "Title too long");
        require(bytes(input.description).length <= 5000, "Description too long");
        require(bytes(input.loginInstructions).length <= 2000, "Login instructions too long");
        require(bytes(input.voteConfirmation).length <= 2000, "Vote confirmation too long");
        require(bytes(input.afterElectionMessage).length <= 2000, "After election message too long");
    }

    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) { len++; j /= 10; }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            bstr[k] = bytes1(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }
}