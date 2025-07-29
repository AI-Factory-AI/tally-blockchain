// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IElection.sol";
import "./ElectionStorage.sol";

/**
 * @title VotingLogic
 * @dev Library for voting-related functions
 */
library VotingLogic {
    event VoteCast(string voterId, uint256 timestamp, string ipfsCid);

    function addVoter(
        ElectionStorage.ElectionData storage data,
        address _voterAddress,
        string calldata _voterId,
        uint256 _voteWeight,
        bytes32 _voterKeyHash
    ) external {
        require(bytes(_voterId).length > 0, "Voter ID cannot be empty");
        require(bytes(data.votersByVoterId[_voterId].voterId).length == 0, "Voter ID already exists");
        require(data.voterCount < data.config.votingSettings.maxVotersCount, "Maximum voters reached");
        
        data.votersByVoterId[_voterId] = IElection.Voter({
            voterId: _voterId,
            voterAddress: _voterAddress,
            voteWeight: _voteWeight,
            hasVoted: false,
            registeredAt: block.timestamp
        });
        data.voterIdsByAddress[_voterAddress] = _voterId;
        data.voterKeyHashes[_voterKeyHash] = true;
        data.voterCount++;
    }

    function addVotersBatch(
        ElectionStorage.ElectionData storage data,
        address[] calldata _voterAddresses,
        string[] calldata _voterIds,
        uint256[] calldata _voteWeights,
        string calldata _ipfsCid
    ) external {
        require(
            _voterAddresses.length == _voterIds.length &&
            _voterIds.length == _voteWeights.length,
            "Input arrays must have same length"
        );
        require(
            data.voterCount + _voterIds.length <= data.config.votingSettings.maxVotersCount,
            "Maximum voters would be exceeded"
        );
        
        for (uint256 i = 0; i < _voterIds.length; i++) {
            require(bytes(_voterIds[i]).length > 0, "Voter ID cannot be empty");
            require(bytes(data.votersByVoterId[_voterIds[i]].voterId).length == 0, "Voter ID already exists");
            
            data.votersByVoterId[_voterIds[i]] = IElection.Voter({
                voterId: _voterIds[i],
                voterAddress: _voterAddresses[i],
                voteWeight: _voteWeights[i],
                hasVoted: false,
                registeredAt: block.timestamp
            });
            data.voterIdsByAddress[_voterAddresses[i]] = _voterIds[i];
        }
        data.voterCount += _voterIds.length;
        data.voterMetadataUri = _ipfsCid;
    }

    function recordVote(
        ElectionStorage.ElectionData storage data,
        string calldata _voterId,
        bytes32[] calldata _choices,
        string calldata _ipfsCid
    ) external {
        data.votersByVoterId[_voterId].hasVoted = true;
        data.votesByVoterId[_voterId] = IElection.Vote({
            voterId: _voterId,
            choices: _choices,
            timestamp: block.timestamp,
            ipfsCid: _ipfsCid
        });
        data.voteCount++;
        emit VoteCast(_voterId, block.timestamp, _ipfsCid);
    }

    function verifyVoterAccess(
        ElectionStorage.ElectionData storage data,
        string calldata _voterId,
        bytes32 _voterKeyHash
    ) external view returns (bool) {
        if (bytes(data.votersByVoterId[_voterId].voterId).length == 0) return false;
        if (!data.voterKeyHashes[_voterKeyHash]) return false;
        if (data.votersByVoterId[_voterId].hasVoted) return false;
        return true;
    }
}