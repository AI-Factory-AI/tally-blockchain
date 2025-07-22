// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/Election.sol";
import "../src/interfaces/IElection.sol";

contract ElectionTest is Test {
    Election election;
    address owner = address(0xABCD);
    address voter1 = address(0xBEEF);
    address voter2 = address(0xCAFE);
    address paymaster = address(0xDEAD);
    address factory = address(this); // test contract as factory

    function setUp() public {
        Election.ElectionBasicParams memory basic = Election.ElectionBasicParams({
            creator: owner,
            title: "Test Election",
            description: "A demo election",
            startTime: block.timestamp + 1 hours,
            endTime: block.timestamp + 2 hours,
            timezone: "UTC"
        });
        Election.ElectionVotingParams memory voting = Election.ElectionVotingParams({
            ballotReceipt: true,
            submitConfirmation: true,
            maxVotersCount: 2,
            allowVoterRegistration: true
        });
        Election.ElectionMessagesParams memory messages = Election.ElectionMessagesParams({
            loginInstructions: "Login to vote",
            voteConfirmation: "Vote cast!",
            afterElectionMessage: "Thank you"
        });
        Election.ElectionResultsParams memory results = Election.ElectionResultsParams({
            publicResults: true,
            realTimeResults: false,
            resultsReleaseTime: block.timestamp + 3 hours,
            allowResultsDownload: true
        });
        election = new Election(basic, voting, messages, results);
    }

    function testInitialConfig() public {
        Election.ElectionBasicInfo memory info = election.getElectionBasicInfo();
        assertEq(info.title, "Test Election");
    }

    function testUpdateElectionBasicInfo() public {
        vm.prank(owner);
        election.updateElectionBasicInfo("New Title", "New Desc");
        Election.ElectionBasicInfo memory info = election.getElectionBasicInfo();
        assertEq(info.title, "New Title");
        assertEq(info.description, "New Desc");
    }

    function testUpdateElectionBasicInfoRevertsIfNotDraft() public {
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        vm.expectRevert("Election: Can only update draft elections");
        election.updateElectionBasicInfo("Title", "Desc");
    }

    function testUpdateElectionBasicInfoRevertsIfNotCreator() public {
        vm.prank(voter1);
        vm.expectRevert("Election: Not the election creator");
        election.updateElectionBasicInfo("Title", "Desc");
    }

    function testUpdateElectionBasicInfoRevertsOnInvalidTitle() public {
        vm.prank(owner);
        vm.expectRevert("Election: Invalid title length");
        election.updateElectionBasicInfo("", "Desc");
    }

    function testUpdateElectionBasicInfoRevertsOnLongDescription() public {
        vm.prank(owner);
        string memory longDesc = new string(5001);
        vm.expectRevert("Election: Description too long");
        election.updateElectionBasicInfo("Title", longDesc);
    }

    function testUpdateElectionTiming() public {
        vm.prank(owner);
        election.updateElectionTiming(block.timestamp + 2 hours, block.timestamp + 3 hours, "PST");
        Election.ElectionTiming memory timing = election.getElectionTiming();
        assertEq(timing.timezone, "PST");
    }

    function testUpdateElectionTimingRevertsIfNotDraft() public {
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        vm.expectRevert("Election: Can only update draft elections");
        election.updateElectionTiming(block.timestamp + 2 hours, block.timestamp + 3 hours, "PST");
    }

    function testUpdateVotingSettings() public {
        IElection.VotingSettings memory settings = IElection.VotingSettings({
            ballotReceipt: false,
            submitConfirmation: false,
            maxVotersCount: 10,
            allowVoterRegistration: false
        });
        vm.prank(owner);
        election.updateVotingSettings(settings);
        IElection.VotingSettings memory s = election.getVotingSettings();
        assertEq(s.maxVotersCount, 10);
    }

    function testUpdateVotingSettingsRevertsIfNotDraft() public {
        IElection.VotingSettings memory settings = IElection.VotingSettings({
            ballotReceipt: false,
            submitConfirmation: false,
            maxVotersCount: 10,
            allowVoterRegistration: false
        });
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        vm.expectRevert("Election: Can only update draft elections");
        election.updateVotingSettings(settings);
    }

    function testUpdateElectionMessages() public {
        IElection.ElectionMessages memory messages = IElection.ElectionMessages({
            loginInstructions: "A",
            voteConfirmation: "B",
            afterElectionMessage: "C"
        });
        vm.prank(owner);
        election.updateElectionMessages(messages);
        IElection.ElectionMessages memory m = election.getElectionMessages();
        assertEq(m.loginInstructions, "A");
    }

    function testUpdateElectionMessagesRevertsIfNotDraft() public {
        IElection.ElectionMessages memory messages = IElection.ElectionMessages({
            loginInstructions: "A",
            voteConfirmation: "B",
            afterElectionMessage: "C"
        });
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        vm.expectRevert("Election: Can only update draft elections");
        election.updateElectionMessages(messages);
    }

    function testUpdateElectionMessagesRevertsOnLongMessage() public {
        string memory longMsg = new string(2001);
        IElection.ElectionMessages memory messages = IElection.ElectionMessages({
            loginInstructions: longMsg,
            voteConfirmation: "B",
            afterElectionMessage: "C"
        });
        vm.prank(owner);
        vm.expectRevert("Election: Login instructions too long");
        election.updateElectionMessages(messages);
    }

    function testUpdateResultsConfig() public {
        IElection.ResultsConfig memory results = IElection.ResultsConfig({
            publicResults: false,
            realTimeResults: true,
            resultsReleaseTime: block.timestamp + 4 hours,
            allowResultsDownload: false
        });
        vm.prank(owner);
        election.updateResultsConfig(results);
        IElection.ResultsConfig memory r = election.getResultsConfig();
        assertEq(r.realTimeResults, true);
    }

    function testUpdateResultsConfigRevertsIfNotDraft() public {
        IElection.ResultsConfig memory results = IElection.ResultsConfig({
            publicResults: false,
            realTimeResults: true,
            resultsReleaseTime: block.timestamp + 4 hours,
            allowResultsDownload: false
        });
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        vm.expectRevert("Election: Can only update draft elections");
        election.updateResultsConfig(results);
    }

    function testChangeElectionStatusValidTransitions() public {
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.COMPLETED);
    }

    function testChangeElectionStatusInvalidTransitions() public {
        vm.prank(owner);
        vm.expectRevert();
        election.changeElectionStatus(IElection.ElectionStatus.COMPLETED);
    }

    function testDeleteElection() public {
        vm.prank(owner);
        election.deleteElection();
        // Do not call view functions after deletion, as notDeleted modifier will revert
        // Just assert that deleteElection does not revert
        assertTrue(true);
    }

    function testDeleteElectionRevertsIfActive() public {
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(owner);
        vm.expectRevert("Election: Cannot delete active election");
        election.deleteElection();
    }

    function testAddBallot() public {
        vm.prank(owner);
        election.addBallot("Ballot 1", "Desc", true, "ipfs1");
        Election.Ballot memory ballot = election.getBallot(1);
        assertEq(ballot.title, "Ballot 1");
    }

    function testAddBallotRevertsIfNotDraft() public {
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        vm.expectRevert("Election: Can only add ballots to draft elections");
        election.addBallot("Ballot 1", "Desc", true, "ipfs1");
    }

    function testAddVoter() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        Election.Voter memory voter = election.getVoter("voter1");
        assertEq(voter.voterAddress, voter1);
    }

    function testAddVoterRevertsOnDuplicate() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        vm.expectRevert("Election: Voter ID already exists");
        election.addVoter(voter1, "voter1", 1, voterKey);
    }

    function testAddVoterRevertsOnMaxVoters() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        election.addVoter(voter2, "voter2", 1, voterKey);
        vm.prank(owner);
        vm.expectRevert("Election: Maximum voters reached");
        election.addVoter(address(0x1234), "voter3", 1, voterKey);
    }

    function testAddVotersBatch() public {
        address[] memory addrs = new address[](2);
        addrs[0] = voter1;
        addrs[1] = voter2;
        string[] memory ids = new string[](2);
        ids[0] = "voter1";
        ids[1] = "voter2";
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 1;
        vm.prank(owner);
        election.addVoters(addrs, ids, weights, "ipfsVoters");
        Election.Voter memory voter = election.getVoter("voter1");
        assertEq(voter.voterAddress, voter1);
    }

    function testAddVotersBatchRevertsOnDuplicate() public {
        address[] memory addrs = new address[](1);
        addrs[0] = voter1;
        string[] memory ids = new string[](1);
        ids[0] = "voter1";
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1;
        vm.prank(owner);
        election.addVoters(addrs, ids, weights, "ipfsVoters");
        vm.prank(owner);
        vm.expectRevert("Election: Voter ID already exists");
        election.addVoters(addrs, ids, weights, "ipfsVoters");
    }

    function testRegisterVoterKey() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.registerVoterKey(voterKey);
        // Should not revert
    }

    function testRegisterVoterKeyRevertsOnDuplicate() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.registerVoterKey(voterKey);
        vm.prank(owner);
        vm.expectRevert("Election: Voter key hash already registered");
        election.registerVoterKey(voterKey);
    }

    function testCastVote() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(voter1);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        election.castVote("voter1", choices, "ipfsVote");
        Election.Vote memory vote = election.getVote("voter1");
        assertEq(vote.voterId, "voter1");
    }

    function testCastVoteRevertsIfAlreadyVoted() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(voter1);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        election.castVote("voter1", choices, "ipfsVote");
        vm.prank(voter1);
        vm.expectRevert("Election: Voter has already voted");
        election.castVote("voter1", choices, "ipfsVote");
    }

    function testCastVoteWithKey() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(voter1);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        election.castVoteWithKey("voter1", voterKey, choices, "ipfsVote");
        Election.Vote memory vote = election.getVote("voter1");
        assertEq(vote.voterId, "voter1");
    }

    function testCastVoteWithKeyRevertsOnInvalidKey() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(voter1);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        vm.expectRevert("Election: Invalid voter key");
        election.castVoteWithKey("voter1", keccak256(abi.encodePacked("wrong")), choices, "ipfsVote");
    }

    function testCastVoteWithPaymaster() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        election.setPaymaster(paymaster, true);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(paymaster);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        election.castVoteWithPaymaster("voter1", voterKey, choices, "ipfsVote");
        Election.Vote memory vote = election.getVote("voter1");
        assertEq(vote.voterId, "voter1");
    }

    function testCastVoteWithPaymasterRevertsIfNotAuthorized() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        election.setPaymaster(paymaster, false);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(paymaster);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        vm.expectRevert("Election: Not an authorized paymaster");
        election.castVoteWithPaymaster("voter1", voterKey, choices, "ipfsVote");
    }

    function testSetElectionUrl() public {
        vm.prank(owner);
        election.setElectionUrl("https://tally/vote/1");
        assertEq(election.electionUrl(), "https://tally/vote/1");
    }

    function testSetPaymaster() public {
        vm.prank(owner);
        election.setPaymaster(paymaster, true);
        assertEq(election.paymaster(), paymaster);
    }

    function testPauseUnpause() public {
        vm.prank(owner);
        election.pause();
        vm.prank(owner);
        election.unpause();
    }

    function testPauseRevertsIfNotOwner() public {
        vm.prank(voter1);
        vm.expectRevert();
        election.pause();
    }

    function testViewFunctions() public {
        election.getElection();
        election.getElectionBasicInfo();
        election.getElectionTiming();
        election.getVotingSettings();
        election.getElectionMessages();
        election.getResultsConfig();
    }

    function testGetBallotRevertsOnInvalidId() public {
        vm.expectRevert("Election: Invalid ballot ID");
        election.getBallot(1);
    }

    function testGetVoterByAddress() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        Election.Voter memory voter = election.getVoterByAddress(voter1);
        assertEq(voter.voterId, "voter1");
    }

    function testVerifyVoterAccess() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        bool access = election.verifyVoterAccess("voter1", voterKey);
        assertTrue(access);
    }

    function testVerifyVoterAccessFalseCases() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        bool access = election.verifyVoterAccess("not-registered", voterKey);
        assertFalse(access);
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        access = election.verifyVoterAccess("voter1", keccak256(abi.encodePacked("wrong")));
        assertFalse(access);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(voter1);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        election.castVote("voter1", choices, "ipfsVote");
        access = election.verifyVoterAccess("voter1", voterKey);
        assertFalse(access);
    }

    // Additional branch coverage tests
    function testAddVoterRevertsIfEmptyId() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        vm.expectRevert("Election: Voter ID cannot be empty");
        election.addVoter(voter1, "", 1, voterKey);
    }
    function testAddVotersBatchRevertsOnInputLengthMismatch() public {
        address[] memory addrs = new address[](2);
        addrs[0] = voter1;
        addrs[1] = voter2;
        string[] memory ids = new string[](1);
        ids[0] = "voter1";
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 1;
        vm.prank(owner);
        vm.expectRevert("Election: Input arrays must have same length");
        election.addVoters(addrs, ids, weights, "ipfsVoters");
    }
    function testAddVotersBatchRevertsOnMaxVotersExceeded() public {
        address[] memory addrs = new address[](3);
        addrs[0] = voter1;
        addrs[1] = voter2;
        addrs[2] = address(0x1234);
        string[] memory ids = new string[](3);
        ids[0] = "voter1";
        ids[1] = "voter2";
        ids[2] = "voter3";
        uint256[] memory weights = new uint256[](3);
        weights[0] = 1;
        weights[1] = 1;
        weights[2] = 1;
        vm.prank(owner);
        vm.expectRevert("Election: Maximum voters would be exceeded");
        election.addVoters(addrs, ids, weights, "ipfsVoters");
    }
    function testAddVotersBatchRevertsIfEmptyId() public {
        address[] memory addrs = new address[](1);
        addrs[0] = voter1;
        string[] memory ids = new string[](1);
        ids[0] = "";
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1;
        vm.prank(owner);
        vm.expectRevert("Election: Voter ID cannot be empty");
        election.addVoters(addrs, ids, weights, "ipfsVoters");
    }
    function testRegisterVoterKeyRevertsIfAlreadyRegistered() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.registerVoterKey(voterKey);
        vm.prank(owner);
        vm.expectRevert("Election: Voter key hash already registered");
        election.registerVoterKey(voterKey);
    }
    function testCastVoteRevertsIfNotActive() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        vm.prank(voter1);
        vm.expectRevert("Election: Election is not active");
        election.castVote("voter1", choices, "ipfsVote");
    }
    function testCastVoteRevertsIfNotRegistered() public {
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        vm.prank(voter1);
        vm.expectRevert("Election: Election is not active");
        election.castVote("not-registered", choices, "ipfsVote");
    }
    function testCastVoteRevertsIfNotAuthorized() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        address notVoter = address(0x9999);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        vm.prank(notVoter);
        vm.expectRevert("Election: Not authorized to vote for this ID");
        election.castVote("voter1", choices, "ipfsVote");
    }
    function testCastVoteWithPaymasterRevertsIfNotAuthorizedPaymaster() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(owner);
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(owner);
        election.setPaymaster(paymaster, false);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        address notPaymaster = address(0x8888);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        vm.prank(notPaymaster);
        vm.expectRevert("Election: Not an authorized paymaster");
        election.castVoteWithPaymaster("voter1", voterKey, choices, "ipfsVote");
    }
    function testSetPaymasterRevertsIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Election: Invalid paymaster address");
        election.setPaymaster(address(0), true);
    }
    function testPauseRevertsIfNotCreator() public {
        vm.prank(voter1);
        vm.expectRevert();
        election.pause();
    }
    function testUnpauseRevertsIfNotCreator() public {
        vm.prank(voter1);
        vm.expectRevert();
        election.unpause();
    }
    function testChangeElectionStatusRevertsIfUnchanged() public {
        vm.prank(owner);
        vm.expectRevert("Election: Status unchanged");
        election.changeElectionStatus(IElection.ElectionStatus.DRAFT);
    }
    function testChangeElectionStatusRevertsOnInvalidTransition() public {
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(owner);
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        vm.prank(owner);
        vm.expectRevert("Election: Invalid status transition from ACTIVE");
        election.changeElectionStatus(IElection.ElectionStatus.CANCELLED);
    }
    function testDeleteElectionRevertsIfDeleted() public {
        vm.prank(owner);
        election.deleteElection();
        vm.prank(owner);
        vm.expectRevert("Election: Election has been deleted");
        election.updateElectionBasicInfo("x", "y");
    }
} 