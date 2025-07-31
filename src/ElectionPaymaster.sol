// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IElection.sol";

/**
 * @title ElectionPaymaster
 * @dev Paymaster contract for gasless voting in elections
 * @notice This contract pays for gas fees on behalf of voters
 */
contract ElectionPaymaster is Ownable, ReentrancyGuard, Pausable {
    
    // ============ State Variables ============
    mapping(address => bool) public authorizedElections;
    mapping(address => uint256) public gasLimits;
    mapping(address => uint256) public dailyGasSpent;
    mapping(address => uint256) public lastResetDay;
    
    uint256 public constant DEFAULT_GAS_LIMIT = 200000;
    uint256 public constant DAILY_GAS_LIMIT = 10000000; // 10M gas per day per election
    uint256 public treasuryBalance;
    
    // ============ Events ============
    event ElectionAuthorized(address indexed election, bool authorized);
    event GasLimitUpdated(address indexed election, uint256 newLimit);
    event VotePaidFor(address indexed election, string voterId, uint256 gasUsed, uint256 gasPrice);
    event TreasuryDeposit(address indexed depositor, uint256 amount);
    event TreasuryWithdraw(address indexed recipient, uint256 amount);
    event EmergencyWithdraw(address indexed owner, uint256 amount);

    // ============ Modifiers ============
    modifier onlyAuthorizedElection() {
        require(authorizedElections[msg.sender], "Election not authorized");
        _;
    }

    modifier hasBalance() {
        require(treasuryBalance > 0, "Insufficient treasury balance");
        _;
    }

    // ============ Constructor ============
    constructor() Ownable(msg.sender) {
        treasuryBalance = 0;
    }

    // ============ Admin Functions ============
    
    /**
     * @dev Authorize an election contract to use this paymaster
     * @param _election Address of the election contract
     * @param _authorized Whether to authorize or deauthorize
     */
    function authorizeElection(address _election, bool _authorized) external onlyOwner {
        require(_election != address(0), "Invalid election address");
        authorizedElections[_election] = _authorized;
        
        if (_authorized && gasLimits[_election] == 0) {
            gasLimits[_election] = DEFAULT_GAS_LIMIT;
        }
        
        emit ElectionAuthorized(_election, _authorized);
    }

    /**
     * @dev Set gas limit for a specific election
     * @param _election Address of the election contract
     * @param _gasLimit Maximum gas limit for transactions
     */
    function setGasLimit(address _election, uint256 _gasLimit) external onlyOwner {
        require(authorizedElections[_election], "Election not authorized");
        require(_gasLimit > 0 && _gasLimit <= 500000, "Invalid gas limit");
        
        gasLimits[_election] = _gasLimit;
        emit GasLimitUpdated(_election, _gasLimit);
    }

    /**
     * @dev Deposit funds to the treasury
     */
    function depositToTreasury() external payable {
        require(msg.value > 0, "Must send ETH");
        treasuryBalance += msg.value;
        emit TreasuryDeposit(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw funds from treasury (owner only)
     * @param _amount Amount to withdraw
     * @param _recipient Recipient address
     */
    function withdrawFromTreasury(uint256 _amount, address payable _recipient) external onlyOwner {
        require(_amount > 0 && _amount <= treasuryBalance, "Invalid amount");
        require(_recipient != address(0), "Invalid recipient");
        
        treasuryBalance -= _amount;
        _recipient.transfer(_amount);
        emit TreasuryWithdraw(_recipient, _amount);
    }

    /**
     * @dev Emergency withdraw all funds (owner only)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        treasuryBalance = 0;
        payable(owner()).transfer(balance);
        emit EmergencyWithdraw(owner(), balance);
    }

    // ============ Paymaster Functions ============
    
    /**
     * @dev Pay for a voter's gas fees and execute their vote
     * @param _election Address of the election contract
     * @param _voterId Voter's ID
     * @param _voterKeyHash Voter's key hash for verification
     * @param _choices Array of vote choices
     * @param _ipfsCid IPFS CID for vote metadata
     */
    function payForVote(
        address _election,
        string calldata _voterId,
        bytes32 _voterKeyHash,
        bytes32[] calldata _choices,
        string calldata _ipfsCid
    ) external nonReentrant whenNotPaused hasBalance {
        require(authorizedElections[_election], "Election not authorized");
        
        // Check daily gas limit
        _checkDailyGasLimit(_election);
        
        uint256 gasStart = gasleft();
        uint256 gasLimit = gasLimits[_election];
        
        // Execute the vote transaction
        try IElection(_election).castVoteWithPaymaster(_voterId, _voterKeyHash, _choices, _ipfsCid) {
            uint256 gasUsed = gasStart - gasleft();
            uint256 gasCost = gasUsed * tx.gasprice;
            
            require(gasCost <= treasuryBalance, "Insufficient treasury balance for gas");
            require(gasUsed <= gasLimit, "Gas limit exceeded");
            
            // Update daily gas tracking
            uint256 currentDay = block.timestamp / 1 days;
            if (lastResetDay[_election] < currentDay) {
                dailyGasSpent[_election] = 0;
                lastResetDay[_election] = currentDay;
            }
            dailyGasSpent[_election] += gasUsed;
            
            // Deduct gas cost from treasury
            treasuryBalance -= gasCost;
            
            emit VotePaidFor(_election, _voterId, gasUsed, tx.gasprice);
            
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Vote failed: ", reason)));
        } catch {
            revert("Vote failed: Unknown error");
        }
    }

    /**
     * @dev Batch pay for multiple votes (more gas efficient)
     * @param _election Address of the election contract
     * @param _voterIds Array of voter IDs
     * @param _voterKeyHashes Array of voter key hashes
     * @param _choices Array of vote choices arrays
     * @param _ipfsCids Array of IPFS CIDs
     */
    function batchPayForVotes(
        address _election,
        string[] calldata _voterIds,
        bytes32[] calldata _voterKeyHashes,
        bytes32[][] calldata _choices,
        string[] calldata _ipfsCids
    ) external nonReentrant whenNotPaused hasBalance onlyOwner {
        require(authorizedElections[_election], "Election not authorized");
        require(_voterIds.length == _voterKeyHashes.length, "Array length mismatch");
        require(_voterIds.length == _choices.length, "Array length mismatch");
        require(_voterIds.length == _ipfsCids.length, "Array length mismatch");
        require(_voterIds.length <= 50, "Batch size too large");
        
        _checkDailyGasLimit(_election);
        
        uint256 gasStart = gasleft();
        uint256 successfulVotes = 0;
        
        for (uint256 i = 0; i < _voterIds.length; i++) {
            try IElection(_election).castVoteWithPaymaster(
                _voterIds[i], 
                _voterKeyHashes[i], 
                _choices[i], 
                _ipfsCids[i]
            ) {
                successfulVotes++;
                emit VotePaidFor(_election, _voterIds[i], 0, tx.gasprice); // Gas calculation done at the end
            } catch {
                // Continue with other votes even if one fails
                continue;
            }
        }
        
        if (successfulVotes > 0) {
            uint256 totalGasUsed = gasStart - gasleft();
            uint256 totalGasCost = totalGasUsed * tx.gasprice;
            
            require(totalGasCost <= treasuryBalance, "Insufficient treasury balance");
            
            // Update daily gas tracking
            uint256 currentDay = block.timestamp / 1 days;
            if (lastResetDay[_election] < currentDay) {
                dailyGasSpent[_election] = 0;
                lastResetDay[_election] = currentDay;
            }
            dailyGasSpent[_election] += totalGasUsed;
            
            treasuryBalance -= totalGasCost;
        }
        
        require(successfulVotes > 0, "No votes were successful");
    }

    // ============ View Functions ============
    
    /**
     * @dev Check if an election is authorized
     * @param _election Address of the election contract
     * @return bool Whether the election is authorized
     */
    function isElectionAuthorized(address _election) external view returns (bool) {
        return authorizedElections[_election];
    }

    /**
     * @dev Get gas limit for an election
     * @param _election Address of the election contract
     * @return uint256 Gas limit
     */
    function getGasLimit(address _election) external view returns (uint256) {
        return gasLimits[_election];
    }

    /**
     * @dev Get remaining daily gas limit for an election
     * @param _election Address of the election contract
     * @return uint256 Remaining gas limit
     */
    function getRemainingDailyGas(address _election) external view returns (uint256) {
        uint256 currentDay = block.timestamp / 1 days;
        if (lastResetDay[_election] < currentDay) {
            return DAILY_GAS_LIMIT;
        }
        return DAILY_GAS_LIMIT - dailyGasSpent[_election];
    }

    /**
     * @dev Get treasury balance
     * @return uint256 Current treasury balance
     */
    function getTreasuryBalance() external view returns (uint256) {
        return treasuryBalance;
    }

    /**
     * @dev Estimate gas cost for a vote
     * @param _election Address of the election contract
     * @return uint256 Estimated gas cost in wei
     */
    function estimateVoteGasCost(address _election) external view returns (uint256) {
        uint256 gasLimit = gasLimits[_election];
        return gasLimit * tx.gasprice;
    }

    // ============ Internal Functions ============
    
    /**
     * @dev Check if daily gas limit is exceeded
     * @param _election Address of the election contract
     */
    function _checkDailyGasLimit(address _election) internal {
        uint256 currentDay = block.timestamp / 1 days;
        if (lastResetDay[_election] < currentDay) {
            dailyGasSpent[_election] = 0;
            lastResetDay[_election] = currentDay;
        }
        require(dailyGasSpent[_election] < DAILY_GAS_LIMIT, "Daily gas limit exceeded");
    }

    // ============ Emergency Functions ============
    
    /**
     * @dev Pause the paymaster in case of emergency
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the paymaster
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ Fallback Functions ============
    
    /**
     * @dev Receive function to accept ETH deposits
     */
    receive() external payable {
        treasuryBalance += msg.value;
        emit TreasuryDeposit(msg.sender, msg.value);
    }

    /**
     * @dev Fallback function
     */
    fallback() external payable {
        revert("Function not found");
    }
}