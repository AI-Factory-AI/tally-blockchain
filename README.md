# ElectionCore Contract Testing Guide

This comprehensive guide will walk you through testing every feature of the ElectionCore contract.

## Prerequisites

Before testing, you'll need:
- The ElectionCore contract deployed
- Supporting contracts: `ElectionStorage.sol`, `VotingLogic.sol`, `interfaces/IElection.sol`
- Test accounts with different roles
- Development environment (Hardhat, Foundry, or Remix)

## Contract Deployment & Initial State

### 1. Deploy the Contract
```javascript
// The constructor automatically sets up:
const election = await ElectionCore.deploy();
await election.deployed();

console.log("Election deployed to:", election.address);
```

### 2. Verify Initial State
```javascript
// Check initial configuration
const basicInfo = await election.getElectionBasicInfo();
console.log("Title:", basicInfo.title); // "Election 2025"
console.log("Status:", basicInfo.status); // 0 (DRAFT)
console.log("Creator:", basicInfo.creator); // tx.origin

const config = await election.getElection();
console.log("Start Time:", new Date(config.timing.startTime * 1000));
console.log("End Time:", new Date(config.timing.endTime * 1000));
console.log("Max Voters:", config.votingSettings.maxVotersCount); // 1000
```

## Phase 1: Configuration (DRAFT Status)

### 3. Update Election Configuration
```javascript
// Test the full configuration update
await election.initializeElectionConfig(
    "Presidential Election 2025",
    "Choose the next president",
    Math.floor(Date.now() / 1000) + 3600, // Start in 1 hour
    Math.floor(Date.now() / 1000) + 86400, // End in 24 hours
    "UTC",
    5000, // Max voters
    "Please login with your voter ID",
    "Your vote has been successfully recorded",
    "Thank you for participating in democracy",
    false, // No real-time results
    Math.floor(Date.now() / 1000) + 90000 // Results release time
);

console.log("✅ Election configuration updated");
```

### 4. Update Basic Info Only
```javascript
await election.updateElectionBasicInfo(
    "Updated Election Title",
    "Updated description"
);
console.log("✅ Basic info updated");
```

### 5. Add Ballots
```javascript
// Add first ballot (single choice)
await election.addBallot(
    "Presidential Candidates",
    "Choose one candidate for president",
    false, // Single choice
    "QmBallot1Hash..."
);

// Add second ballot (multiple choice)
await election.addBallot(
    "Referendum Questions",
    "Vote on multiple propositions",
    true, // Multiple choice
    "QmBallot2Hash..."
);

console.log("Ballot count:", await election.ballotCount()); // Should be 2
```

### 6. Verify Ballots
```javascript
const ballot1 = await election.getBallot(1);
console.log("Ballot 1:", ballot1.title, ballot1.isMultipleChoice);

const ballot2 = await election.getBallot(2);
console.log("Ballot 2:", ballot2.title, ballot2.isMultipleChoice);
```

### 7. Add Individual Voters
```javascript
const voterAddresses = [
    "0x1234567890123456789012345678901234567890",
    "0x2345678901234567890123456789012345678901"
];

const voterIds = ["VOTER001", "VOTER002"];
const voteWeights = [1, 1];
const voterKeyHashes = [
    ethers.utils.keccak256(ethers.utils.toUtf8Bytes("secret1")),
    ethers.utils.keccak256(ethers.utils.toUtf8Bytes("secret2"))
];

// Add first voter
await election.addVoter(
    voterAddresses[0],
    voterIds[0],
    voteWeights[0],
    voterKeyHashes[0]
);

console.log("✅ Voter 1 added");
console.log("Voter count:", await election.voterCount());
```

### 8. Add Batch Voters
```javascript
// Add multiple voters at once
await election.addVoters(
    voterAddresses,
    voterIds,
    voteWeights,
    "QmVotersListHash..."
);

console.log("✅ Batch voters added");
console.log("Total voter count:", await election.voterCount());
```

### 9. Verify Voters
```javascript
const voter1 = await election.getVoter("VOTER001");
console.log("Voter 1:", {
    id: voter1.voterId,
    address: voter1.voterAddress,
    weight: voter1.voteWeight.toString(),
    hasVoted: voter1.hasVoted
});
```

### 10. Add Metadata
```javascript
await election.addElectionMetadata(
    "QmElectionMetadata...",
    "QmBallotMetadata..."
);
console.log("✅ Metadata added");
```

### 11. Set Election URL
```javascript
await election.setElectionUrl("https://vote.example.com/election/123");
console.log("✅ Election URL set");
console.log("URL:", await election.electionUrl());
```

## Phase 2: Paymaster Setup (Optional)

### 12. Deploy and Configure Paymaster
```javascript
// Deploy paymaster (if using the paymaster from previous artifact)
const paymaster = await ElectionPaymaster.deploy();
await paymaster.deployed();

// Fund paymaster
await paymaster.depositToTreasury({ value: ethers.utils.parseEther("1.0") });

// Authorize election in paymaster
await paymaster.authorizeElection(election.address, true);

// Set paymaster in election
await election.setPaymaster(paymaster.address, true);

console.log("✅ Paymaster configured");
```

## Phase 3: Election Activation

### 13. Change Status to ACTIVE
```javascript
// Change from DRAFT to ACTIVE
await election.changeElectionStatus(1); // 1 = ACTIVE

const basicInfo = await election.getElectionBasicInfo();
console.log("✅ Election status:", basicInfo.status); // Should be 1 (ACTIVE)
```

## Phase 4: Voting Process

### 14. Test Voter Access Verification
```javascript
const canVote = await election.verifyVoterAccess("VOTER001", voterKeyHashes[0]);
console.log("Voter can access:", canVote); // Should be true
```

### 15. Cast Votes (Regular Method)
```javascript
// Connect as voter 1
const voterSigner = await ethers.getSigner(voterAddresses[0]);
const electionAsVoter = election.connect(voterSigner);

// Vote choices (ballot IDs as bytes32)
const choices = [
    ethers.utils.formatBytes32String("candidate1"),
    ethers.utils.formatBytes32String("proposition1")
];

// Cast vote
await electionAsVoter.castVote(
    "VOTER001",
    choices,
    "QmVoteMetadata..."
);

console.log("✅ Vote cast successfully");
console.log("Vote count:", await election.voteCount());
```

### 16. Cast Votes with Key Hash
```javascript
// Vote using key hash (gasless alternative)
await election.castVoteWithKey(
    "VOTER002",
    voterKeyHashes[1],
    choices,
    "QmVoteMetadata2..."
);

console.log("✅ Vote with key cast successfully");
```

### 17. Cast Votes with Paymaster
```javascript
// If paymaster is set up
await paymaster.payForVote(
    election.address,
    "VOTER003",
    voterKeyHashes[2],
    choices,
    "QmVoteMetadata3..."
);

console.log("✅ Paymaster vote cast successfully");
```

### 18. Verify Votes
```javascript
// Check vote details
const vote1 = await election.getVote("VOTER001");
console.log("Vote 1:", {
    voterId: vote1.voterId,
    choices: vote1.choices,
    timestamp: new Date(vote1.timestamp * 1000),
    ipfsCid: vote1.ipfsCid
});

// Check voter status
const voter1Updated = await election.getVoter("VOTER001");
console.log("Voter 1 has voted:", voter1Updated.hasVoted); // Should be true
```

## Phase 5: Error Testing

### 19. Test Access Controls
```javascript
// Try to vote twice (should fail)
try {
    await electionAsVoter.castVote("VOTER001", choices, "duplicate");
    console.log("❌ Should have failed - voter already voted");
} catch (error) {
    console.log("✅ Correctly prevented duplicate voting:", error.message);
}

// Try to vote as unauthorized user (should fail)
try {
    const unauthorizedSigner = await ethers.getSigner("0x9999999999999999999999999999999999999999");
    const electionUnauthorized = election.connect(unauthorizedSigner);
    await electionUnauthorized.castVote("VOTER002", choices, "unauthorized");
    console.log("❌ Should have failed - unauthorized voter");
} catch (error) {
    console.log("✅ Correctly prevented unauthorized voting:", error.message);
}
```

### 20. Test Status Restrictions
```javascript
// Try to add ballot to active election (should fail)
try {
    await election.addBallot("New Ballot", "Description", false, "hash");
    console.log("❌ Should have failed - election is active");
} catch (error) {
    console.log("✅ Correctly prevented ballot addition to active election");
}
```

## Phase 6: Election Management

### 21. Change Election Status to COMPLETED
```javascript
// Move to completed status
await election.changeElectionStatus(2); // 2 = COMPLETED

const finalInfo = await election.getElectionBasicInfo();
console.log("✅ Election completed, status:", finalInfo.status);
```

### 22. Final Statistics
```javascript
console.log("\n=== FINAL ELECTION STATISTICS ===");
console.log("Total Ballots:", await election.ballotCount());
console.log("Total Voters:", await election.voterCount());
console.log("Total Votes:", await election.voteCount());
console.log("Election URL:", await election.electionUrl());
```

## Phase 7: Administrative Testing

### 23. Test Owner Functions
```javascript
// Test pause functionality (if inherited)
await election.pause();
console.log("✅ Election paused");

await election.unpause();
console.log("✅ Election unpaused");
```

### 24. Test Edge Cases
```javascript
// Test invalid ballot ID
try {
    await election.getBallot(999);
    console.log("❌ Should have failed - invalid ballot ID");
} catch (error) {
    console.log("✅ Correctly handled invalid ballot ID");
}

// Test invalid voter ID
try {
    await election.getVoter("NONEXISTENT");
    console.log("❌ Should have failed - nonexistent voter");
} catch (error) {
    console.log("✅ Correctly handled nonexistent voter");
}
```

## Test Script Template

Here's a complete test script you can run:

```javascript
async function runFullElectionTest() {
    console.log("🗳️  Starting ElectionCore Full Test Suite\n");
    
    // Deploy contract
    const ElectionCore = await ethers.getContractFactory("ElectionCore");
    const election = await ElectionCore.deploy();
    await election.deployed();
    
    console.log("✅ Contract deployed to:", election.address);
    
    // Add all the test functions from above here...
    // Follow the phases in order
    
    console.log("\n🎉 All tests completed successfully!");
}

// Run the test
runFullElectionTest()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Test failed:", error);
        process.exit(1);
    });
```

## Expected Behaviors

### Success Cases:
- ✅ All configuration updates in DRAFT status
- ✅ Ballot and voter additions
- ✅ Status transitions: DRAFT → ACTIVE → COMPLETED
- ✅ Voting by registered voters
- ✅ Metadata and URL updates

### Failure Cases:
- ❌ Duplicate voting attempts
- ❌ Unauthorized voting
- ❌ Configuration changes in non-DRAFT status
- ❌ Invalid status transitions
- ❌ Operations on deleted elections

## Monitoring Events

During testing, watch for these events:
- `ElectionUpdated`
- `ElectionStatusChanged`
- `BallotAdded`
- `VoterAdded`
- `VotersBatchAdded`
- `ElectionMetadataUpdated`
- `ElectionUrlGenerated`
- `PaymasterUpdated`

This guide covers all major functionality and edge cases in your ElectionCore contract!
