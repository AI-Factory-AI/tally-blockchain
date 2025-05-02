// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "./interfaces/IElectionPaymaster.sol";
import "./interfaces/IElectionFactory.sol";

/**
 * @title ElectionPaymaster
 * @dev Paymaster contract that sponsors gas fees for election-related transactions
 */
contract ElectionPaymaster is IElectionPaymaster, BasePaymaster, Ownable {
    // The election factory contract
    IElectionFactory public electionFactory;
    
    // Map of registered elections eligible for gas sponsorship
    mapping(address => bool) public registeredElections;
    
    // Limits and counters for gas usage
    uint256 public maxGasLimit;
    mapping(address => uint256) public electionGasUsage;
    mapping(address => uint256) public voterGasUsage;
    
    // Maximum gas cost willing to pay for a transaction
    uint256 public maxGasCost;
    
    // Polling period before a transaction can be considered stale
    uint256 public constant STALE_VALIDATION_PERIOD = 1 hours;

    /**
     * @dev Constructor
     * @param _entryPoint EntryPoint contract address
     * @param _electionFactory ElectionFactory contract address
     * @param _initialOwner The initial owner of the contract
     */
    constructor(
        IEntryPoint _entryPoint,
        address _electionFactory,
        address _initialOwner
    ) BasePaymaster(_entryPoint) Ownable(_initialOwner) {
        require(_electionFactory != address(0), "Invalid election factory");
        electionFactory = IElectionFactory(_electionFactory);
        maxGasLimit = 1000000; // Default gas limit for transactions
        maxGasCost = 30 gwei;  // Default max gas price
    }
    
    /**
     * @dev Registers an election for gas sponsorship
     * @param _electionAddress Address of the election contract
     */
    function registerElection(address _electionAddress) external override onlyOwner {
        require(_electionAddress != address(0), "Invalid election address");
        require(electionFactory.isValidElection(_electionAddress), "Not a valid election");
        require(!registeredElections[_electionAddress], "Election already registered");
        
        registeredElections[_electionAddress] = true;
        emit ElectionRegistered(_electionAddress);
    }
    
    /**
     * @dev Removes an election from gas sponsorship
     * @param _electionAddress Address of the election contract
     */
    function removeElection(address _electionAddress) external override onlyOwner {
        require(registeredElections[_electionAddress], "Election not registered");
        
        registeredElections[_electionAddress] = false;
        emit ElectionRemoved(_electionAddress);
    }
    
    /**
     * @dev Checks if an election is registered for gas sponsorship
     * @param _electionAddress Address of the election contract
     * @return bool True if the election is registered
     */
    function isElectionRegistered(address _electionAddress) external view override returns (bool) {
        return registeredElections[_electionAddress];
    }
    
    /**
     * @dev Adds funds to the paymaster
     */
    function addFunds() external payable override onlyOwner {
        // Funds are automatically added to the contract balance
    }
    
    /**
     * @dev Withdraws funds from the paymaster
     * @param _amount Amount to withdraw
     */
    function withdrawFunds(uint256 _amount) external override onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        (bool success, ) = owner().call{value: _amount}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @dev Set maximum gas limit for sponsored transactions
     * @param _maxGasLimit New maximum gas limit
     */
    function setMaxGasLimit(uint256 _maxGasLimit) external onlyOwner {
        maxGasLimit = _maxGasLimit;
    }
    
    /**
     * @dev Set maximum gas cost willing to pay per transaction
     * @param _maxGasCost New maximum gas cost
     */
    function setMaxGasCost(uint256 _maxGasCost) external onlyOwner {
        maxGasCost = _maxGasCost;
    }
    
    /**
     * @dev Validate the paymaster user operation
     * @param userOp The user operation
     * @param userOpHash Hash of the user operation
     * @param maxCost Maximum cost of the operation
     * @return context Context for post-operation
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) internal view override returns (bytes memory context, uint256 validationData) {
        // Extract target contract from the user operation
        address target = address(bytes20(userOp.callData[16:36]));
        
        // Check if the target is a registered election
        require(registeredElections[target], "Target not a registered election");
        
        // Check if gas limit is within acceptable range
        require(userOp.callGasLimit <= maxGasLimit, "Gas limit too high");
        
        // Check if max fee per gas is acceptable
        require(userOp.maxFeePerGas <= maxGasCost, "Gas cost too high");
        
        // Create context with relevant information for post-op
        context = abi.encode(target, userOp.sender);
        
        // Return validationData with stale check time
        return (context, _packValidationData(false, STALE_VALIDATION_PERIOD, 0));
    }
    
    /**
     * @dev Post-operation hook to track gas usage
     * @param mode Mode of operation
     * @param context Context from pre-validation
     * @param actualGasCost Actual gas cost of the operation
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        // Only execute on successful operation
        if (mode != PostOpMode.opSucceeded) return;
        
        // Decode context
        (address election, address voter) = abi.decode(context, (address, address));
        
        // Track gas usage
        electionGasUsage[election] += actualGasCost;
        voterGasUsage[voter] += actualGasCost;
        
        emit TransactionSponsored(election, voter, actualGasCost);
    }
    
    /**
     * @dev Get gas usage for a specific election
     * @param _election Address of the election
     * @return uint256 Total gas used by the election
     */
    function getElectionGasUsage(address _election) external view returns (uint256) {
        return electionGasUsage[_election];
    }
    
    /**
     * @dev Get gas usage for a specific voter
     * @param _voter Address of the voter
     * @return uint256 Total gas used by the voter
     */
    function getVoterGasUsage(address _voter) external view returns (uint256) {
        return voterGasUsage[_voter];
    }
    
    /**
     * @dev Returns the stake requirements for this paymaster
     * @return The stake requirements
     */
    function getStakeRequirements() external view returns (uint256, uint256) {
        // Return the minimum stake value and time for this paymaster (can be customized)
        return (0.1 ether, 1 days);
    }
}