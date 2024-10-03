// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {GovernorTimelockCompoundUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockCompoundUpgradeable.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {GovernorSettingsUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorPreventLateQuorumUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorPreventLateQuorumUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @title CompoundGovernor
/// @author [ScopeLift](https://scopelift.co)
/// @notice A governance contract for the Compound DAO.
/// @custom:security-contact TODO: Add security contact
contract CompoundGovernor is
    Initializable,
    GovernorVotesUpgradeable,
    GovernorTimelockCompoundUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorPreventLateQuorumUpgradeable,
    OwnableUpgradeable
{
    /// @notice The number of votes supporting a proposal required for quorum for a vote to succeed
    /// TODO: This will be replaced as a settable quorum in a future PR.
    uint256 public constant quorumVotes = 400_000e18; // 400,000 = 4% of Comp

    /// @notice Disables the initialize function.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize Governor.
    /// @param _name The name of the Governor.
    /// @param _initialVotingDelay The initial voting delay.
    /// @param _initialVotingPeriod The initial voting period.
    /// @param _initialProposalThreshold The initial proposal threshold.
    /// @param _compAddress The address of the Comp token.
    /// @param _timelockAddress The address of the Timelock.
    /// @param _initialVoteExtension The initial vote extension.
    /// @param _initialOwner The initial owner of the Governor.
    function initialize(
        string memory _name,
        uint48 _initialVotingDelay,
        uint32 _initialVotingPeriod,
        uint256 _initialProposalThreshold,
        IVotes _compAddress,
        ICompoundTimelock _timelockAddress,
        uint48 _initialVoteExtension,
        address _initialOwner
    ) public initializer {
        __Governor_init(_name);
        __GovernorSettings_init(_initialVotingDelay, _initialVotingPeriod, _initialProposalThreshold);
        __GovernorVotes_init(_compAddress);
        __GovernorTimelockCompound_init(_timelockAddress);
        __GovernorPreventLateQuorum_init(_initialVoteExtension);
        __Ownable_init(_initialOwner);
    }

    /// @inheritdoc GovernorTimelockCompoundUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function _cancel(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal virtual override(GovernorUpgradeable, GovernorTimelockCompoundUpgradeable) returns (uint256) {
        return GovernorTimelockCompoundUpgradeable._cancel(_targets, _values, _calldatas, _descriptionHash);
    }

    /// @inheritdoc GovernorPreventLateQuorumUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function _castVote(
        uint256 _proposalId,
        address _account,
        uint8 _support,
        string memory _reason,
        bytes memory _params
    ) internal virtual override(GovernorUpgradeable, GovernorPreventLateQuorumUpgradeable) returns (uint256) {
        return GovernorPreventLateQuorumUpgradeable._castVote(_proposalId, _account, _support, _reason, _params);
    }

    /// @inheritdoc GovernorTimelockCompoundUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function _executeOperations(
        uint256 _proposalId,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal virtual override(GovernorUpgradeable, GovernorTimelockCompoundUpgradeable) {
        return GovernorTimelockCompoundUpgradeable._executeOperations(
            _proposalId, _targets, _values, _calldatas, _descriptionHash
        );
    }

    /// @inheritdoc GovernorTimelockCompoundUpgradeable
    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockCompoundUpgradeable)
        returns (address)
    {
        return GovernorTimelockCompoundUpgradeable._executor();
    }

    /// @inheritdoc GovernorTimelockCompoundUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function _queueOperations(
        uint256 _proposalId,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal virtual override(GovernorUpgradeable, GovernorTimelockCompoundUpgradeable) returns (uint48) {
        return GovernorTimelockCompoundUpgradeable._queueOperations(
            _proposalId, _targets, _values, _calldatas, _descriptionHash
        );
    }

    /// @inheritdoc GovernorPreventLateQuorumUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function proposalDeadline(uint256 _proposalId)
        public
        view
        virtual
        override(GovernorPreventLateQuorumUpgradeable, GovernorUpgradeable)
        returns (uint256)
    {
        return GovernorPreventLateQuorumUpgradeable.proposalDeadline(_proposalId);
    }

    /// @inheritdoc GovernorTimelockCompoundUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function proposalNeedsQueuing(uint256 _proposalId)
        public
        view
        virtual
        override(GovernorTimelockCompoundUpgradeable, GovernorUpgradeable)
        returns (bool)
    {
        return GovernorTimelockCompoundUpgradeable.proposalNeedsQueuing(_proposalId);
    }

    /// @inheritdoc GovernorSettingsUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function proposalThreshold()
        public
        view
        virtual
        override(GovernorSettingsUpgradeable, GovernorUpgradeable)
        returns (uint256)
    {
        return GovernorSettingsUpgradeable.proposalThreshold();
    }

    /// @inheritdoc GovernorTimelockCompoundUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function state(uint256 _proposalId)
        public
        view
        virtual
        override(GovernorUpgradeable, GovernorTimelockCompoundUpgradeable)
        returns (ProposalState)
    {
        return GovernorTimelockCompoundUpgradeable.state(_proposalId);
    }

    /// @notice Calculates the quorum size, excludes token delegated to the exclude address.
    /// @dev We override this function to use the circulating supply to calculate the quorum.
    /// @return The quorum size.
    function quorum(uint256) public pure override(GovernorUpgradeable) returns (uint256) {
        return quorumVotes;
    }
}
