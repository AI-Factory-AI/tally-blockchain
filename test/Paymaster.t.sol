// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/Paymaster.sol";
import "../src/Election.sol";
import "../src/interfaces/IElection.sol";

contract PaymasterTest is Test {
    ElectionPaymaster paymaster;
    Election election;
    address owner = address(0xABCD);
    address voter1 = address(0xBEEF);
    address pmOwner = address(this);
    address factory = address(0xF00D);
    address other = address(0xBEEF);

    function setUp() public {
        paymaster = new ElectionPaymaster(factory);
        // Deploy Election as paymaster (so paymaster is the creator)
        vm.startPrank(address(paymaster));
        Election.ElectionBasicParams memory basic = Election.ElectionBasicParams({
            creator: address(paymaster),
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
        vm.stopPrank();
    }

    function testSetPaymaster() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
    }

    function testAuthorizeElection() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        paymaster.authorizeElection(address(election), 5);
        assertTrue(paymaster.authorizedElections(address(election)));
        assertEq(paymaster.electionVoteLimits(address(election)), 5);
    }

    function testAuthorizeElectionRevertsIfNotOwner() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        paymaster.authorizeElection(address(election), 5);
    }

    function testUnauthorizeElection() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        paymaster.authorizeElection(address(election), 5);
        vm.prank(paymaster.owner());
        paymaster.unauthorizeElection(address(election));
        assertFalse(paymaster.authorizedElections(address(election)));
    }

    function testUnauthorizeElectionRevertsIfNotOwner() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        paymaster.authorizeElection(address(election), 5);
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        paymaster.unauthorizeElection(address(election));
    }

    function testUnauthorizeElectionRevertsIfNotAuthorized() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Election not authorized");
        paymaster.unauthorizeElection(address(election));
    }

    function testUpdateVoteLimit() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        paymaster.authorizeElection(address(election), 5);
        vm.prank(paymaster.owner());
        paymaster.updateVoteLimit(address(election), 10);
        assertEq(paymaster.electionVoteLimits(address(election)), 10);
    }

    function testUpdateVoteLimitRevertsIfNotOwner() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        paymaster.authorizeElection(address(election), 5);
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        paymaster.updateVoteLimit(address(election), 10);
    }

    function testUpdateVoteLimitRevertsIfNotAuthorized() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Election not authorized");
        paymaster.updateVoteLimit(address(election), 10);
    }

    function testExecuteVote() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        paymaster.authorizeElection(address(election), 2);
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(address(paymaster));
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(address(paymaster));
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(address(paymaster));
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        bytes32 nonce = keccak256(abi.encodePacked("nonce1"));
        paymaster.executeVote(address(election), "voter1", voterKey, choices, "ipfsVote", nonce);
        assertEq(paymaster.totalVotesProcessed(), 1);
        assertEq(paymaster.electionVotesProcessed(address(election)), 1);
    }

    function testExecuteVoteRevertsIfNotAuthorized() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        bytes32 nonce = keccak256(abi.encodePacked("nonce1"));
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Election not authorized");
        paymaster.executeVote(address(election), "voter1", voterKey, choices, "ipfsVote", nonce);
    }

    function testExecuteVoteRevertsIfVoteLimitExceeded() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        paymaster.authorizeElection(address(election), 1);
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(address(paymaster));
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(address(paymaster));
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(address(paymaster));
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        bytes32 nonce = keccak256(abi.encodePacked("nonce1"));
        paymaster.executeVote(address(election), "voter1", voterKey, choices, "ipfsVote", nonce);
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Vote limit exceeded for this election");
        paymaster.executeVote(address(election), "voter1", voterKey, choices, "ipfsVote", keccak256(abi.encodePacked("nonce2")));
    }

    function testExecuteVoteRevertsOnNonceReuse() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        paymaster.authorizeElection(address(election), 2);
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        vm.prank(address(paymaster));
        election.addVoter(voter1, "voter1", 1, voterKey);
        vm.prank(address(paymaster));
        election.changeElectionStatus(IElection.ElectionStatus.SCHEDULED);
        vm.prank(address(paymaster));
        election.changeElectionStatus(IElection.ElectionStatus.ACTIVE);
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        bytes32 nonce = keccak256(abi.encodePacked("nonce1"));
        paymaster.executeVote(address(election), "voter1", voterKey, choices, "ipfsVote", nonce);
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Nonce already used");
        paymaster.executeVote(address(election), "voter1", voterKey, choices, "ipfsVote", nonce);
    }

    function testPauseUnpause() public {
        vm.prank(paymaster.owner());
        paymaster.pause();
        vm.prank(paymaster.owner());
        paymaster.unpause();
    }

    function testPauseRevertsIfNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        paymaster.pause();
    }

    function testExecuteVoteRevertsIfPaused() public {
        vm.prank(address(paymaster));
        election.setPaymaster(address(paymaster), true);
        vm.prank(paymaster.owner());
        paymaster.authorizeElection(address(election), 2);
        vm.prank(paymaster.owner());
        paymaster.pause();
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        bytes32 nonce = keccak256(abi.encodePacked("nonce1"));
        vm.prank(paymaster.owner());
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        paymaster.executeVote(address(election), "voter1", voterKey, choices, "ipfsVote", nonce);
    }

    function testUpdateFactory() public {
        vm.prank(paymaster.owner());
        paymaster.updateFactory(address(0xBEEF));
        assertEq(paymaster.electionFactory(), address(0xBEEF));
    }

    function testUpdateFactoryRevertsIfZero() public {
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Invalid factory address");
        paymaster.updateFactory(address(0));
    }

    function testWithdrawRevertsIfNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        paymaster.withdraw(payable(pmOwner), 1 ether);
    }

    function testWithdrawRevertsIfZeroAddress() public {
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Invalid recipient address");
        paymaster.withdraw(payable(address(0)), 1 ether);
    }

    function testWithdrawRevertsIfInsufficientBalance() public {
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Insufficient balance");
        paymaster.withdraw(payable(pmOwner), 1 ether);
    }

    // Additional branch coverage tests
    function testAuthorizeElectionRevertsIfZeroAddress() public {
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Invalid election address");
        paymaster.authorizeElection(address(0), 5);
    }
    function testUpdateFactoryRevertsIfNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        paymaster.updateFactory(address(0xBEEF));
    }
    function testUpdateFactoryRevertsIfZeroAddress() public {
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Invalid factory address");
        paymaster.updateFactory(address(0));
    }
    function testPauseRevertsIfPaused() public {
        vm.prank(paymaster.owner());
        paymaster.pause();
        vm.prank(paymaster.owner());
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        paymaster.pause();
    }
    // function testUnpauseRevertsIfNotPaused() public {
    //     vm.prank(paymaster.owner());
    //     paymaster.unpause();
    //     // Should not revert
    // }
    function testWithdrawRevertsIfZeroAmount() public {
        vm.prank(paymaster.owner());
        paymaster.updateFactory(address(0xBEEF));
        vm.expectRevert();
        paymaster.withdraw(payable(pmOwner), 0);
    }
    function testExecuteVoteRevertsIfElectionNotAuthorized() public {
        bytes32 voterKey = keccak256(abi.encodePacked("key1"));
        bytes32[] memory choices = new bytes32[](1);
        choices[0] = bytes32(0);
        bytes32 nonce = keccak256(abi.encodePacked("nonce1"));
        vm.prank(paymaster.owner());
        vm.expectRevert("ElectionPaymaster: Election not authorized");
        paymaster.executeVote(address(0x1234), "voter1", voterKey, choices, "ipfsVote", nonce);
    }
} 