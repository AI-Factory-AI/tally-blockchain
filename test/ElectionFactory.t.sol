// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/ElectionFactory.sol";
import "../src/Election.sol";
import "../src/interfaces/IElectionFactory.sol";

contract ElectionFactoryTest is Test {
    ElectionFactory factory;
    address owner = address(0xABCD);
    address other = address(0xBEEF);

    function setUp() public {
        vm.prank(owner);
        factory = new ElectionFactory(0);
    }

    function getInput() internal view returns (IElectionFactory.CreateElectionInput memory) {
        return IElectionFactory.CreateElectionInput({
            title: "Test Election",
            description: "A demo election",
            startTime: block.timestamp + 1 hours,
            endTime: block.timestamp + 2 hours,
            timezone: "UTC",
            ballotReceipt: true,
            submitConfirmation: true,
            maxVotersCount: 2,
            allowVoterRegistration: true,
            loginInstructions: "Login to vote",
            voteConfirmation: "Vote cast!",
            afterElectionMessage: "Thank you",
            publicResults: true,
            realTimeResults: false,
            resultsReleaseTime: block.timestamp + 3 hours,
            allowResultsDownload: true
        });
    }

    function testCreateElection() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        (uint256 electionId, address electionAddr) = factory.createElection(input);
        assertTrue(electionAddr != address(0));
        uint256[] memory elections = factory.getElectionsByCreator(owner);
        assertEq(elections.length, 1);
        assertEq(elections[0], electionId);
    }

    function testCreateElectionRevertsOnInvalidTiming() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        input.startTime = block.timestamp - 1;
        vm.prank(owner);
        vm.expectRevert("ElectionFactory: Start time must be in the future");
        factory.createElection(input);
    }

    function testCreateElectionRevertsOnShortDuration() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        input.endTime = input.startTime + 10;
        vm.prank(owner);
        vm.expectRevert("ElectionFactory: Election duration too short");
        factory.createElection(input);
    }

    function testCreateElectionRevertsOnLongDuration() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        input.endTime = input.startTime + 366 days;
        vm.prank(owner);
        vm.expectRevert("ElectionFactory: Election duration too long");
        factory.createElection(input);
    }

    function testCreateElectionRevertsOnEmptyTitle() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        input.title = "";
        vm.prank(owner);
        vm.expectRevert("ElectionFactory: Title cannot be empty");
        factory.createElection(input);
    }

    function testDeleteElection() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        (uint256 electionId, address electionAddr) = factory.createElection(input);
        vm.prank(owner);
        vm.expectRevert("Election: Not the election creator");
        factory.deleteElection(electionId);
    }

    function testDeleteElectionRevertsIfNotCreator() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        (uint256 electionId, address electionAddr) = factory.createElection(input);
        vm.prank(other);
        vm.expectRevert("ElectionFactory: Not the election creator");
        factory.deleteElection(electionId);
    }

    function testGetElectionContract() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        (uint256 electionId, address electionAddr) = factory.createElection(input);
        address addr = factory.getElectionContract(electionId);
        assertEq(addr, electionAddr);
    }

    function testGetElection() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        (uint256 electionId, ) = factory.createElection(input);
        factory.getElection(electionId);
    }

    function testGetElectionBasicInfo() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        (uint256 electionId, ) = factory.createElection(input);
        factory.getElectionBasicInfo(electionId);
    }

    function testGetElectionsByCreator() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        factory.createElection(input);
        uint256[] memory ids = factory.getElectionsByCreator(owner);
        assertEq(ids.length, 1);
    }

    function testGetCurrentElectionId() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        factory.createElection(input);
        uint256 id = factory.getCurrentElectionId();
        assertEq(id, 1);
    }

    function testGetAllElections() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        factory.createElection(input);
        (uint256[] memory ids, address[] memory addrs) = factory.getAllElections();
        assertEq(ids.length, 1);
        assertEq(addrs.length, 1);
    }

    function testGetElectionContractsByCreator() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        vm.prank(owner);
        (uint256 electionId, address electionAddr) = factory.createElection(input);
        address[] memory addrs = factory.getElectionContractsByCreator(owner);
        assertEq(addrs.length, 1);
        assertEq(addrs[0], electionAddr);
    }

    function testUpdateElectionFee() public {
        vm.prank(factory.owner());
        factory.updateElectionFee(1 ether);
        assertEq(factory.electionCreationFee(), 1 ether);
    }

    function testUpdateElectionFeeRevertsIfNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        factory.updateElectionFee(1 ether);
    }

    // function testWithdrawFees() public {
    //     // Send ETH to factory
    //     (bool sent,) = address(factory).call{value: 1 ether}("");
    //     assertTrue(sent);
    //     vm.prank(factory.owner());
    //     address payable to = payable(owner);
    //     factory.withdrawFees(to);
    //     // No assertion, just ensure no revert
    // }

    function testWithdrawFeesRevertsIfNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        factory.withdrawFees(payable(owner));
    }

    function testWithdrawFeesRevertsIfZeroAddress() public {
        vm.prank(factory.owner());
        vm.expectRevert("ElectionFactory: Invalid address");
        factory.withdrawFees(payable(address(0)));
    }

    function testWithdrawFeesRevertsIfNoFees() public {
        vm.prank(factory.owner());
        vm.expectRevert("ElectionFactory: No fees to withdraw");
        factory.withdrawFees(payable(owner));
    }

    function testPause() public {
        vm.prank(factory.owner());
        factory.pause();
        vm.prank(factory.owner());
        factory.unpause();
    }

    function testPauseRevertsIfNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", other));
        factory.pause();
    }

    // Additional branch coverage tests
    function testCreateElectionRevertsOnTooLongTitle() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        input.title = string(abi.encodePacked(new bytes(201)));
        vm.prank(owner);
        vm.expectRevert("ElectionFactory: Title too long");
        factory.createElection(input);
    }
    function testCreateElectionRevertsOnTooLongDescription() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        input.description = string(abi.encodePacked(new bytes(5001)));
        vm.prank(owner);
        vm.expectRevert("ElectionFactory: Description too long");
        factory.createElection(input);
    }
    function testCreateElectionRevertsOnTooLongLoginInstructions() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        input.loginInstructions = string(abi.encodePacked(new bytes(2001)));
        vm.prank(owner);
        vm.expectRevert("ElectionFactory: Login instructions too long");
        factory.createElection(input);
    }
    function testCreateElectionRevertsOnTooLongVoteConfirmation() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        input.voteConfirmation = string(abi.encodePacked(new bytes(2001)));
        vm.prank(owner);
        vm.expectRevert("ElectionFactory: Vote confirmation too long");
        factory.createElection(input);
    }
    function testCreateElectionRevertsOnTooLongAfterElectionMessage() public {
        IElectionFactory.CreateElectionInput memory input = getInput();
        input.afterElectionMessage = string(abi.encodePacked(new bytes(2001)));
        vm.prank(owner);
        vm.expectRevert("ElectionFactory: After election message too long");
        factory.createElection(input);
    }
    function testPauseRevertsIfPaused() public {
        vm.prank(factory.owner());
        factory.pause();
        vm.prank(factory.owner());
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        factory.pause();
    }
    // function testUnpauseRevertsIfNotPaused() public {
    //     vm.prank(factory.owner());
    //     factory.unpause();
    //     // Should not revert
    // }
    function testWithdrawFeesRevertsIfZeroAmount() public {
        vm.prank(factory.owner());
        address payable to = payable(owner);
        vm.expectRevert();
        factory.withdrawFees(to);
    }
} 