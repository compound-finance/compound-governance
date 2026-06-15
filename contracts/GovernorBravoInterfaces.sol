// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

interface GovernorBravoEvents {
    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(
        uint id,
        address proposer,
        address[] targets,
        uint[] values,
        string[] signatures,
        bytes[] calldatas,
        uint startBlock,
        uint endBlock,
        string description
    );

    /**
     * @notice An event emitted when a vote has been cast on a proposal
     * @param voter The address which casted a vote
     * @param proposalId The proposal id which was voted on
     * @param support Support value for the vote. 0=against, 1=for, 2=abstain
     * @param votes Number of votes which were cast by the voter
     * @param reason The reason given for the vote by the voter
     */
    event VoteCast(
        address indexed voter,
        uint proposalId,
        uint8 support,
        uint votes,
        string reason
    );

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint id, uint eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint id);

    /// @notice An event emitted when the voting delay is set
    event VotingDelaySet(uint oldVotingDelay, uint newVotingDelay);

    /// @notice An event emitted when the voting period is set
    event VotingPeriodSet(uint oldVotingPeriod, uint newVotingPeriod);

    /// @notice Emitted when implementation is changed
    event NewImplementation(
        address oldImplementation,
        address newImplementation
    );

    /// @notice Emitted when proposal threshold is set
    event ProposalThresholdSet(
        uint oldProposalThreshold,
        uint newProposalThreshold
    );

    /// @notice Emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);

    /// @notice Emitted when whitelist account expiration is set
    event WhitelistAccountExpirationSet(address account, uint expiration);

    /// @notice Emitted when the whitelistGuardian is set
    event WhitelistGuardianSet(address oldGuardian, address newGuardian);

    /// @notice Emitted when the proposalGuardian is set
    event ProposalGuardianSet(
        address oldProposalGuardian,
        uint96 oldProposalGuardianExpiry,
        address newProposalGuardian,
        uint newProposalGuardianExpiry
    );
}

interface GovernorBravoInterface is GovernorBravoEvents {
    function MIN_PROPOSAL_THRESHOLD() external returns (uint256);

    function MAX_PROPOSAL_THRESHOLD() external returns (uint256);

    function MIN_VOTING_PERIOD() external returns (uint256);

    function MAX_VOTING_PERIOD() external returns (uint256);

    function MIN_VOTING_DELAY() external returns (uint256);

    function MAX_VOTING_DELAY() external returns (uint256);

    function votingDelay() external returns (uint256);

    function propose(
        address[] memory,
        uint256[] memory,
        string[] memory,
        bytes[] memory,
        string memory
    ) external returns (uint256);

    function castVote(uint256, uint8) external;

    function proposals(
        uint256
    )
        external
        view
        returns (
            uint256 id,
            address proposer,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            bool canceled,
            bool executed
        );

    function queue(uint256) external;

    function execute(uint256) external;
}

interface TimelockInterface {
    function delay() external view returns (uint);

    function GRACE_PERIOD() external view returns (uint);

    function acceptAdmin() external;

    function queuedTransactions(bytes32 hash) external view returns (bool);

    function queueTransaction(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) external;

    function executeTransaction(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) external payable returns (bytes memory);
}

interface CompInterface {
    function getPriorVotes(
        address account,
        uint blockNumber
    ) external view returns (uint96);
}

interface GovernorAlphaInterface {
    /// @notice The total number of proposals
    function proposalCount() external returns (uint);
}
