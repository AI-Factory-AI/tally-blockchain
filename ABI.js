const ELECTION_CORE_ABI= [
	{
		"inputs": [],
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"inputs": [],
		"name": "EnforcedPause",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ExpectedPause",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "owner",
				"type": "address"
			}
		],
		"name": "OwnableInvalidOwner",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "account",
				"type": "address"
			}
		],
		"name": "OwnableUnauthorizedAccount",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ReentrancyGuardReentrantCall",
		"type": "error"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "uint256",
				"name": "ballotId",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "string",
				"name": "title",
				"type": "string"
			},
			{
				"indexed": false,
				"internalType": "bool",
				"name": "isMultipleChoice",
				"type": "bool"
			},
			{
				"indexed": false,
				"internalType": "string",
				"name": "ipfsCid",
				"type": "string"
			}
		],
		"name": "BallotAdded",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "string",
				"name": "electionMetadataUri",
				"type": "string"
			},
			{
				"indexed": false,
				"internalType": "string",
				"name": "ballotMetadataUri",
				"type": "string"
			}
		],
		"name": "ElectionMetadataUpdated",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "enum IElection.ElectionStatus",
				"name": "oldStatus",
				"type": "uint8"
			},
			{
				"indexed": false,
				"internalType": "enum IElection.ElectionStatus",
				"name": "newStatus",
				"type": "uint8"
			}
		],
		"name": "ElectionStatusChanged",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "updater",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "string",
				"name": "field",
				"type": "string"
			}
		],
		"name": "ElectionUpdated",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "string",
				"name": "electionUrl",
				"type": "string"
			}
		],
		"name": "ElectionUrlGenerated",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "previousOwner",
				"type": "address"
			},
			{
				"indexed": true,
				"internalType": "address",
				"name": "newOwner",
				"type": "address"
			}
		],
		"name": "OwnershipTransferred",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "address",
				"name": "account",
				"type": "address"
			}
		],
		"name": "Paused",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "address",
				"name": "paymaster",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "bool",
				"name": "authorized",
				"type": "bool"
			}
		],
		"name": "PaymasterUpdated",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "address",
				"name": "account",
				"type": "address"
			}
		],
		"name": "Unpaused",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "string",
				"name": "voterId",
				"type": "string"
			},
			{
				"indexed": false,
				"internalType": "address",
				"name": "voterAddress",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "voteWeight",
				"type": "uint256"
			}
		],
		"name": "VoterAdded",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "count",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "string",
				"name": "ipfsCid",
				"type": "string"
			}
		],
		"name": "VotersBatchAdded",
		"type": "event"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_title",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "_description",
				"type": "string"
			},
			{
				"internalType": "bool",
				"name": "_isMultipleChoice",
				"type": "bool"
			},
			{
				"internalType": "string",
				"name": "_ipfsCid",
				"type": "string"
			}
		],
		"name": "addBallot",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_electionMetadataUri",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "_ballotMetadataUri",
				"type": "string"
			}
		],
		"name": "addElectionMetadata",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "_voterAddress",
				"type": "address"
			},
			{
				"internalType": "string",
				"name": "_voterId",
				"type": "string"
			},
			{
				"internalType": "uint256",
				"name": "_voteWeight",
				"type": "uint256"
			},
			{
				"internalType": "bytes32",
				"name": "_voterKeyHash",
				"type": "bytes32"
			}
		],
		"name": "addVoter",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address[]",
				"name": "_voterAddresses",
				"type": "address[]"
			},
			{
				"internalType": "string[]",
				"name": "_voterIds",
				"type": "string[]"
			},
			{
				"internalType": "uint256[]",
				"name": "_voteWeights",
				"type": "uint256[]"
			},
			{
				"internalType": "string",
				"name": "_ipfsCid",
				"type": "string"
			}
		],
		"name": "addVoters",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "ballotCount",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_voterId",
				"type": "string"
			},
			{
				"internalType": "bytes32[]",
				"name": "_choices",
				"type": "bytes32[]"
			},
			{
				"internalType": "string",
				"name": "_ipfsCid",
				"type": "string"
			}
		],
		"name": "castVote",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_voterId",
				"type": "string"
			},
			{
				"internalType": "bytes32",
				"name": "_voterKeyHash",
				"type": "bytes32"
			},
			{
				"internalType": "bytes32[]",
				"name": "_choices",
				"type": "bytes32[]"
			},
			{
				"internalType": "string",
				"name": "_ipfsCid",
				"type": "string"
			}
		],
		"name": "castVoteWithKey",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_voterId",
				"type": "string"
			},
			{
				"internalType": "bytes32",
				"name": "_voterKeyHash",
				"type": "bytes32"
			},
			{
				"internalType": "bytes32[]",
				"name": "_choices",
				"type": "bytes32[]"
			},
			{
				"internalType": "string",
				"name": "_ipfsCid",
				"type": "string"
			}
		],
		"name": "castVoteWithPaymaster",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "enum IElection.ElectionStatus",
				"name": "_newStatus",
				"type": "uint8"
			}
		],
		"name": "changeElectionStatus",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "deleteElection",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "electionUrl",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "_ballotId",
				"type": "uint256"
			}
		],
		"name": "getBallot",
		"outputs": [
			{
				"components": [
					{
						"internalType": "uint256",
						"name": "id",
						"type": "uint256"
					},
					{
						"internalType": "string",
						"name": "title",
						"type": "string"
					},
					{
						"internalType": "string",
						"name": "description",
						"type": "string"
					},
					{
						"internalType": "bool",
						"name": "isMultipleChoice",
						"type": "bool"
					},
					{
						"internalType": "string",
						"name": "ipfsCid",
						"type": "string"
					},
					{
						"internalType": "uint256",
						"name": "createdAt",
						"type": "uint256"
					}
				],
				"internalType": "struct IElection.Ballot",
				"name": "",
				"type": "tuple"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getElection",
		"outputs": [
			{
				"components": [
					{
						"components": [
							{
								"internalType": "string",
								"name": "title",
								"type": "string"
							},
							{
								"internalType": "string",
								"name": "description",
								"type": "string"
							},
							{
								"internalType": "address",
								"name": "creator",
								"type": "address"
							},
							{
								"internalType": "uint256",
								"name": "createdAt",
								"type": "uint256"
							},
							{
								"internalType": "enum IElection.ElectionStatus",
								"name": "status",
								"type": "uint8"
							}
						],
						"internalType": "struct IElection.ElectionBasicInfo",
						"name": "basicInfo",
						"type": "tuple"
					},
					{
						"components": [
							{
								"internalType": "uint256",
								"name": "startTime",
								"type": "uint256"
							},
							{
								"internalType": "uint256",
								"name": "endTime",
								"type": "uint256"
							},
							{
								"internalType": "string",
								"name": "timezone",
								"type": "string"
							}
						],
						"internalType": "struct IElection.ElectionTiming",
						"name": "timing",
						"type": "tuple"
					},
					{
						"components": [
							{
								"internalType": "bool",
								"name": "ballotReceipt",
								"type": "bool"
							},
							{
								"internalType": "bool",
								"name": "submitConfirmation",
								"type": "bool"
							},
							{
								"internalType": "uint256",
								"name": "maxVotersCount",
								"type": "uint256"
							},
							{
								"internalType": "bool",
								"name": "allowVoterRegistration",
								"type": "bool"
							}
						],
						"internalType": "struct IElection.VotingSettings",
						"name": "votingSettings",
						"type": "tuple"
					},
					{
						"components": [
							{
								"internalType": "string",
								"name": "loginInstructions",
								"type": "string"
							},
							{
								"internalType": "string",
								"name": "voteConfirmation",
								"type": "string"
							},
							{
								"internalType": "string",
								"name": "afterElectionMessage",
								"type": "string"
							}
						],
						"internalType": "struct IElection.ElectionMessages",
						"name": "messages",
						"type": "tuple"
					},
					{
						"components": [
							{
								"internalType": "bool",
								"name": "publicResults",
								"type": "bool"
							},
							{
								"internalType": "bool",
								"name": "realTimeResults",
								"type": "bool"
							},
							{
								"internalType": "uint256",
								"name": "resultsReleaseTime",
								"type": "uint256"
							},
							{
								"internalType": "bool",
								"name": "allowResultsDownload",
								"type": "bool"
							}
						],
						"internalType": "struct IElection.ResultsConfig",
						"name": "resultsConfig",
						"type": "tuple"
					}
				],
				"internalType": "struct IElection.ElectionConfig",
				"name": "",
				"type": "tuple"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getElectionBasicInfo",
		"outputs": [
			{
				"components": [
					{
						"internalType": "string",
						"name": "title",
						"type": "string"
					},
					{
						"internalType": "string",
						"name": "description",
						"type": "string"
					},
					{
						"internalType": "address",
						"name": "creator",
						"type": "address"
					},
					{
						"internalType": "uint256",
						"name": "createdAt",
						"type": "uint256"
					},
					{
						"internalType": "enum IElection.ElectionStatus",
						"name": "status",
						"type": "uint8"
					}
				],
				"internalType": "struct IElection.ElectionBasicInfo",
				"name": "",
				"type": "tuple"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_voterId",
				"type": "string"
			}
		],
		"name": "getVote",
		"outputs": [
			{
				"components": [
					{
						"internalType": "string",
						"name": "voterId",
						"type": "string"
					},
					{
						"internalType": "bytes32[]",
						"name": "choices",
						"type": "bytes32[]"
					},
					{
						"internalType": "uint256",
						"name": "timestamp",
						"type": "uint256"
					},
					{
						"internalType": "string",
						"name": "ipfsCid",
						"type": "string"
					}
				],
				"internalType": "struct IElection.Vote",
				"name": "",
				"type": "tuple"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_voterId",
				"type": "string"
			}
		],
		"name": "getVoter",
		"outputs": [
			{
				"components": [
					{
						"internalType": "string",
						"name": "voterId",
						"type": "string"
					},
					{
						"internalType": "address",
						"name": "voterAddress",
						"type": "address"
					},
					{
						"internalType": "uint256",
						"name": "voteWeight",
						"type": "uint256"
					},
					{
						"internalType": "bool",
						"name": "hasVoted",
						"type": "bool"
					},
					{
						"internalType": "uint256",
						"name": "registeredAt",
						"type": "uint256"
					}
				],
				"internalType": "struct IElection.Voter",
				"name": "",
				"type": "tuple"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_title",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "_description",
				"type": "string"
			},
			{
				"internalType": "uint256",
				"name": "_startTime",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "_endTime",
				"type": "uint256"
			},
			{
				"internalType": "string",
				"name": "_timezone",
				"type": "string"
			},
			{
				"internalType": "uint256",
				"name": "_maxVotersCount",
				"type": "uint256"
			},
			{
				"internalType": "string",
				"name": "_loginInstructions",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "_voteConfirmation",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "_afterElectionMessage",
				"type": "string"
			},
			{
				"internalType": "bool",
				"name": "_realTimeResults",
				"type": "bool"
			},
			{
				"internalType": "uint256",
				"name": "_resultsReleaseTime",
				"type": "uint256"
			}
		],
		"name": "initializeElectionConfig",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "owner",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "paused",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "renounceOwnership",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_electionUrl",
				"type": "string"
			}
		],
		"name": "setElectionUrl",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "_paymaster",
				"type": "address"
			},
			{
				"internalType": "bool",
				"name": "_authorized",
				"type": "bool"
			}
		],
		"name": "setPaymaster",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "newOwner",
				"type": "address"
			}
		],
		"name": "transferOwnership",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_title",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "_description",
				"type": "string"
			}
		],
		"name": "updateElectionBasicInfo",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "_voterId",
				"type": "string"
			},
			{
				"internalType": "bytes32",
				"name": "_voterKeyHash",
				"type": "bytes32"
			}
		],
		"name": "verifyVoterAccess",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "voteCount",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "voterCount",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	}
]
