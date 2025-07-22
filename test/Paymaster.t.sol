// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/Paymaster.sol";
import "../src/Election.sol";
import "../src/interfaces/IElection.sol";

contract MockEntryPoint is IEntryPoint {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IEntryPoint).interfaceId;
    }
    // IStakeManager
    function addStake(uint32) external payable override {}
    function balanceOf(address) external view override returns (uint256) { return 0; }
    function depositTo(address) external payable override {}
    function getDepositInfo(address) external view override returns (DepositInfo memory) { return DepositInfo(0, false, 0, 0, 0); }
    function unlockStake() external override {}
    function withdrawStake(address payable) external override {}
    function withdrawTo(address payable, uint256) external override {}
    // INonceManager
    function getNonce(address, uint192) external view override returns (uint256) { return 0; }
    function incrementNonce(uint192) external override {}
    // IEntryPoint
    function delegateAndRevert(address, bytes calldata) external override {}
    function getSenderAddress(bytes memory) external override {}
    function getUserOpHash(PackedUserOperation calldata) external view override returns (bytes32) { return bytes32(0); }
    function handleAggregatedOps(UserOpsPerAggregator[] calldata, address payable) external override {}
    function handleOps(PackedUserOperation[] calldata, address payable) external override {}
    function senderCreator() external view override returns (ISenderCreator) { return ISenderCreator(address(0)); }
}

contract PaymasterTest is Test {
    ElectionPaymaster paymaster;
    Election election;
    address factory = address(0xF00D);
    address other = address(0xBEEF);
    address payable recipient = payable(address(0xCAFE));

    function setUp() public {
        MockEntryPoint entryPoint = new MockEntryPoint();
        paymaster = new ElectionPaymaster(entryPoint, factory);

        // Deploy an Election contract with the paymaster as its creator.
        // This is required so the paymaster can call `setPaymaster` on the election.
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
    }

    function testAuthorizeElection() public {
        vm.prank(address(this));
        paymaster.authorizeElection(address(election), 5);
        assertTrue(paymaster.authorizedElections(address(election)));
        assertEq(paymaster.electionVoteLimits(address(election)), 5);
    }

    function testAuthorizeElectionRevertsIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        vm.prank(other);
        paymaster.authorizeElection(address(election), 5);
    }

    function testAuthorizeElectionRevertsIfZeroAddress() public {
        vm.prank(address(this));
        vm.expectRevert("ElectionPaymaster: Invalid election address");
        paymaster.authorizeElection(address(0), 5);
    }

    function testUnauthorizeElection() public {
        vm.prank(address(this));
        paymaster.authorizeElection(address(election), 5);
        vm.prank(address(this));
        paymaster.unauthorizeElection(address(election));
        assertFalse(paymaster.authorizedElections(address(election)));
    }

    function testUnauthorizeElectionRevertsIfNotOwner() public {
        vm.prank(address(this));
        paymaster.authorizeElection(address(election), 5);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        vm.prank(other);
        paymaster.unauthorizeElection(address(election));
    }

    function testUnauthorizeElectionRevertsIfNotAuthorized() public {
        vm.prank(address(this));
        vm.expectRevert("ElectionPaymaster: Election not authorized");
        paymaster.unauthorizeElection(address(election));
    }

    function testUpdateVoteLimit() public {
        vm.prank(address(this));
        paymaster.authorizeElection(address(election), 5);
        vm.prank(address(this));
        paymaster.updateVoteLimit(address(election), 10);
        assertEq(paymaster.electionVoteLimits(address(election)), 10);
    }

    function testUpdateVoteLimitRevertsIfNotOwner() public {
        vm.prank(address(this));
        paymaster.authorizeElection(address(election), 5);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        vm.prank(other);
        paymaster.updateVoteLimit(address(election), 10);
    }

    function testUpdateVoteLimitRevertsIfNotAuthorized() public {
        vm.prank(address(this));
        vm.expectRevert("ElectionPaymaster: Election not authorized");
        paymaster.updateVoteLimit(address(election), 10);
    }

    function testUpdateFactory() public {
        vm.prank(address(this));
        paymaster.updateFactory(address(0xBEEF));
        assertEq(paymaster.electionFactory(), address(0xBEEF));
    }

    function testUpdateFactoryRevertsIfZero() public {
        vm.prank(address(this));
        vm.expectRevert("ElectionPaymaster: Invalid factory address");
        paymaster.updateFactory(address(0));
    }

    function testUpdateFactoryRevertsIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        vm.prank(other);
        paymaster.updateFactory(address(0xBEEF));
    }

    function testPauseUnpause() public {
        vm.prank(address(this));
        paymaster.pause();
        vm.prank(address(this));
        paymaster.unpause();
    }

    function testPauseRevertsIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        vm.prank(other);
        paymaster.pause();
    }

    function testUnpauseRevertsIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        vm.prank(other);
        paymaster.unpause();
    }

    function testWithdraw() public {
        vm.deal(address(paymaster), 1 ether);
        vm.prank(address(this));
        paymaster.withdraw(recipient, 1 ether);
        assertEq(recipient.balance, 1 ether);
    }

    function testWithdrawRevertsIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        vm.prank(other);
        paymaster.withdraw(recipient, 1 ether);
    }

    function testWithdrawRevertsIfZeroAddress() public {
        vm.prank(address(this));
        vm.expectRevert("ElectionPaymaster: Invalid recipient address");
        paymaster.withdraw(payable(address(0)), 1 ether);
    }

    function testWithdrawRevertsIfInsufficientBalance() public {
        vm.prank(address(this));
        vm.expectRevert("ElectionPaymaster: Insufficient balance");
        paymaster.withdraw(recipient, 1 ether);
    }

    function testExecuteVoteAlwaysReverts() public {
        vm.expectRevert("ElectionPaymaster: executeVote not implemented");
        paymaster.executeVote(address(election), "voter1", bytes32(0), new bytes32[](0), "ipfs", bytes32(0));
    }

    function testReceiveEther() public {
        (bool sent, ) = address(paymaster).call{value: 1 ether}("");
        assertTrue(sent);
        assertEq(address(paymaster).balance, 1 ether);
    }

    function testEvents() public {
        vm.prank(address(this));
        vm.expectEmit(true, true, false, true);
        emit ElectionPaymaster.ElectionAuthorized(address(election), 5);
        paymaster.authorizeElection(address(election), 5);
        vm.prank(address(this));
        vm.expectEmit(true, true, false, false);
        emit ElectionPaymaster.ElectionUnauthorized(address(election));
        paymaster.unauthorizeElection(address(election));
        vm.prank(address(this));
        paymaster.authorizeElection(address(election), 5);
        vm.prank(address(this));
        vm.expectEmit(true, true, false, true);
        emit ElectionPaymaster.VoteLimitUpdated(address(election), 10);
        paymaster.updateVoteLimit(address(election), 10);
        vm.prank(address(this));
        vm.expectEmit(true, false, false, true);
        emit ElectionPaymaster.FactoryUpdated(address(0xBEEF));
        paymaster.updateFactory(address(0xBEEF));
    }
} 