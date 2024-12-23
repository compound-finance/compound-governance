// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IGovernor} from "contracts/extensions/IGovernor.sol";
import {GovernorUpgradeable} from "contracts/extensions/GovernorUpgradeable.sol";
import {GovernorSequentialProposalIdUpgradeable} from "contracts/extensions/GovernorSequentialProposalIdUpgradeable.sol";
import {GovernorVotesCompUpgradeable} from "contracts/extensions/GovernorVotesCompUpgradeable.sol";
import {GovernorSettableFixedQuorumUpgradeable} from "contracts/extensions/GovernorSettableFixedQuorumUpgradeable.sol";
import {GovernorCountingFractionalUpgradeable} from "contracts/extensions/GovernorCountingFractionalUpgradeable.sol";
import {GovernorTimelockCompoundUpgradeable} from "contracts/extensions/GovernorTimelockCompoundUpgradeable.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {GovernorSettingsUpgradeable} from "contracts/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorPreventLateQuorumUpgradeable} from "contracts/extensions/GovernorPreventLateQuorumUpgradeable.sol";
import {IComp} from "contracts/interfaces/IComp.sol";
import {GovernorAlphaInterface} from "contracts/GovernorBravoInterfaces.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @title CompoundGovernor
/// @author [ScopeLift](https://scopelift.co)
/// @notice A governance contract for the Compound DAO.
/// @custom:security-contact security@compound.finance
contract CompoundGovernor is
    Initializable,
    GovernorVotesCompUpgradeable,
    GovernorTimelockCompoundUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingFractionalUpgradeable,
    GovernorPreventLateQuorumUpgradeable,
    GovernorSettableFixedQuorumUpgradeable,
    GovernorSequentialProposalIdUpgradeable
{
    /// @notice Emitted when the expiration of a whitelisted account is set or updated.
    /// @param account The address of the account being whitelisted.
    /// @param expiration The timestamp until which the account is whitelisted.
    event WhitelistAccountExpirationSet(address account, uint256 expiration);

    /// @notice Emitted when the whitelistGuardian is set or changed.
    /// @param oldGuardian The address of the previous whitelistGuardian.
    /// @param newGuardian The address of the new whitelistGuardian.
    event WhitelistGuardianSet(address oldGuardian, address newGuardian);

    /// @notice Emitted when the proposal guardian is set or updated.
    /// @param oldProposalGuardian The address of the previous proposal guardian.
    /// @param oldProposalGuardianExpiry The expiration timestamp of the previous proposal guardian's role.
    /// @param newProposalGuardian The address of the new proposal guardian.
    /// @param newProposalGuardianExpiry The expiration timestamp of the new proposal guardian's role.
    event ProposalGuardianSet(
        address oldProposalGuardian,
        uint96 oldProposalGuardianExpiry,
        address newProposalGuardian,
        uint96 newProposalGuardianExpiry
    );

    /// @notice Error thrown when an unauthorized address attempts to perform a restricted action.
    /// @param reason A brief description of why the caller is unauthorized.
    /// @param caller The address that attempted the unauthorized action.
    error Unauthorized(bytes32 reason, address caller);

    /// @notice The address and expiration of the proposal guardian.
    struct ProposalGuardian {
        // Address of the `ProposalGuardian`
        address account;
        // Timestamp at which the guardian loses the ability to cancel proposals
        uint96 expiration;
    }

    GovernorAlphaInterface private constant compoundGovernorBravo =
        GovernorAlphaInterface(0xc0Da02939E1441F497fd74F78cE7Decb17B66529);

    /// @notice Address which manages whitelisted proposals and whitelist accounts.
    /// @dev This address has the ability to set account whitelist expirations and can be changed through the governance
    /// process.
    address public whitelistGuardian;

    /// @notice Account which has the ability to cancel proposals. This privilege expires at the given expiration
    /// timestamp.
    ProposalGuardian public proposalGuardian;

    /// @notice Stores the expiration of account whitelist status as a timestamp.
    mapping(address account => uint256 timestamp) public whitelistAccountExpirations;

    /// @notice Disables the initialize function.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize Governor.
    /// @param _initialVotingDelay The initial voting delay.
    /// @param _initialVotingPeriod The initial voting period.
    /// @param _initialProposalThreshold The initial proposal threshold.
    /// @param _compAddress The address of the Comp token.
    /// @param _quorumVotes The quorum votes.
    /// @param _timelockAddress The address of the Timelock.
    /// @param _initialVoteExtension The initial vote extension.
    /// @param _whitelistGuardian The address of the whitelist guardian.
    /// @param _proposalGuardian The proposal guardian.
    function initialize(
        uint48 _initialVotingDelay,
        uint32 _initialVotingPeriod,
        uint256 _initialProposalThreshold,
        IComp _compAddress,
        uint256 _quorumVotes,
        ICompoundTimelock _timelockAddress,
        uint48 _initialVoteExtension,
        address _whitelistGuardian,
        ProposalGuardian calldata _proposalGuardian
    ) public initializer {
        __Governor_init("Compound Governor");
        __GovernorSettings_init(_initialVotingDelay, _initialVotingPeriod, _initialProposalThreshold);
        __GovernorVotesComp_init(_compAddress);
        __GovernorTimelockCompound_init(_timelockAddress);
        __GovernorPreventLateQuorum_init(_initialVoteExtension);
        __GovernorSettableFixedQuorum_init(_quorumVotes);
        __GovernorSequentialProposalId_init();
        __GovernorCountingFractional_init();
        _setWhitelistGuardian(_whitelistGuardian);
        _setProposalGuardian(_proposalGuardian);
    }

    /// @notice Sets the next proposal ID. Designed to be callable once by the executor (timelock) on upgrade from
    /// Compound GovernorBravo.
    function setNextProposalId() external {
        if (_executor() != _msgSender()) {
            revert GovernorOnlyExecutor(_msgSender());
        }

        // In GovernorBravo, proposal IDs start at 1, so its proposalCount() function is the most recent
        // proposal ID created. This function sets the first proposal ID for the CompoundGovernor to 1 beyond that,
        // so the first proposal ID of compoundGovernor is one more that the last proposal ID of GovernorBravo.
        _setNextProposalId(compoundGovernorBravo.proposalCount() + 1);
    }

    /// @inheritdoc GovernorSequentialProposalIdUpgradeable
    /// @dev Since GovernorBravo indexed from 1, we decrement the proposal count by 1.
    function proposalCount() public view override returns (uint256) {
        return super.proposalCount() - 1;
    }

    /// @notice A modified `hashProposal` that supports sequential proposal IDs.
    function hashProposal(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) public virtual override(GovernorUpgradeable, GovernorSequentialProposalIdUpgradeable) returns (uint256) {
        return GovernorSequentialProposalIdUpgradeable.hashProposal(_targets, _values, _calldatas, _descriptionHash);
    }

    /// @notice Creates a new proposal. Skips proposal threshold check for whitelisted accounts.
    /// @param _targets An array of addresses that will be called if the proposal is executed.
    /// @param _values An array of ETH values to be sent to each address when the proposal is executed.
    /// @param _calldatas An array of calldata to be sent to each address when the proposal is executed.
    /// @param _description A human-readable description of the proposal.
    /// @return uint256 The ID of the newly created proposal.
    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) public override(GovernorUpgradeable) returns (uint256) {
        address _proposer = _msgSender();

        // check description restriction
        if (!_isValidDescriptionForProposer(_proposer, _description)) {
            revert GovernorRestrictedProposer(_proposer);
        }

        if (!isWhitelisted(_proposer)) {
            // check proposal threshold
            uint256 _votesThreshold = proposalThreshold();
            if (_votesThreshold > 0) {
                uint256 _proposerVotes = getVotes(_proposer, clock() - 1);
                if (_proposerVotes < _votesThreshold) {
                    revert GovernorInsufficientProposerVotes(_proposer, _proposerVotes, _votesThreshold);
                }
            }
        }

        return _propose(_targets, _values, _calldatas, _description, _proposer);
    }

    /// @notice Internal function used to create a new proposal.
    /// @dev This is an override that supports sequential proposal IDs. Called by the public `propose` function.
    /// @param _targets An array of addresses that will be called if the proposal is executed.
    /// @param _values An array of ETH values to be sent to each address when the proposal is executed.
    /// @param _calldatas An array of calldata to be sent to each address when the proposal is executed.
    /// @param _description A human-readable description of the proposal.
    /// @param _proposer The address of the account creating the proposal.
    /// @return uint256 The ID of the newly created proposal.
    function _propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description,
        address _proposer
    ) internal override(GovernorUpgradeable, GovernorSequentialProposalIdUpgradeable) returns (uint256) {
        return GovernorSequentialProposalIdUpgradeable._propose(_targets, _values, _calldatas, _description, _proposer);
    }

    /// @notice Cancels an active proposal.
    /// @notice This function can be called by the proposer, the proposal guardian, or anyone if the proposer's voting
    /// power has dropped below the proposal threshold. For whitelisted proposers, only special actors (proposer,
    /// proposal guardian, whitelist guardian) can cancel if the proposer is below the threshold.
    /// @param _targets An array of addresses that will be called if the proposal is executed.
    /// @param _values An array of ETH values to be sent to each address when the proposal is executed.
    /// @param _calldatas An array of calldata to be sent to each address when the proposal is executed.
    /// @param _descriptionHash The hash of the proposal's description string.
    /// @return uint256 The ID of the canceled proposal.
    function cancel(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) public override returns (uint256) {
        uint256 _proposalId = hashProposal(_targets, _values, _calldatas, _descriptionHash);
        address _proposer = proposalProposer(_proposalId);

        // Proposer and valid guardian can always cancel.
        if (
            msg.sender == _proposer
                || (msg.sender == proposalGuardian.account && block.timestamp <= proposalGuardian.expiration)
        ) {
            return _cancel(_targets, _values, _calldatas, _descriptionHash);
        }

        // For other cancellation attempts, check proposer's voting power.
        bool _isProposerAboveThreshold = token().getPriorVotes(_proposer, block.number - 1) >= proposalThreshold();
        if (_isProposerAboveThreshold) {
            revert Unauthorized("Proposer above proposalThreshold", msg.sender);
        }

        // Check whitelist status
        if (isWhitelisted(_proposer) && msg.sender != whitelistGuardian) {
            revert Unauthorized("Not whitelistGuardian", msg.sender);
        }

        return _cancel(_targets, _values, _calldatas, _descriptionHash);
    }

    /// @notice Cancels a proposal given its ID.
    /// @notice This function can be called by the proposer, the proposal guardian, or anyone if the proposer's voting
    /// power has dropped below the proposal threshold. For whitelisted proposers, only special actors (proposer,
    /// proposal guardian, whitelist guardian) can cancel if the proposer is below the threshold.
    /// @param _proposalId The ID of the proposal to cancel.
    /// @dev This function retrieves proposal details and calls the main cancel function with those details.
    function cancel(uint256 _proposalId) public override {
        (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas, bytes32 _descriptionHash) =
            proposalDetails(_proposalId);
        cancel(_targets, _values, _calldatas, _descriptionHash);
    }

    /// @notice Sets or updates the whitelist expiration for a specific account.
    /// A whitelisted account can create proposals without meeting the 'proposalThreshold'.
    /// A whitelisted account's proposals cannot be canceled by anyone except the `whitelistGuardian` and only when its
    /// voting weight is below the `proposalThreshold`.
    /// A whitelisted account and `proposalGuardian` can still cancel its proposals regardless of voting weight.
    /// @dev Only the executor (timelock) or the `whitelistGuardian` can call this function.
    /// @param _account The address of the account to be whitelisted.
    /// @param _expiration The timestamp until which the account will be whitelisted.
    function setWhitelistAccountExpiration(address _account, uint256 _expiration) external {
        if (msg.sender != _executor() && msg.sender != whitelistGuardian) {
            revert Unauthorized("Not timelock or guardian", msg.sender);
        }

        whitelistAccountExpirations[_account] = _expiration;
        emit WhitelistAccountExpirationSet(_account, _expiration);
    }

    /// @notice Checks if an account is currently whitelisted.
    /// @notice Only a `whitelistGuardian` can cancel a whitelisted account's proposal for falling below
    /// `proposalThreshold`.
    /// @notice The proposer and proposalGuardian can still cancel a whitelisted account's proposal regardless of voting
    /// weight.
    /// @param _account The address of the account to check.
    /// @return bool Returns true if the account is whitelisted (expiration is in the future), false otherwise.
    function isWhitelisted(address _account) public view returns (bool) {
        return (whitelistAccountExpirations[_account] > block.timestamp);
    }

    /// @notice Sets a new `whitelistGuardian`.
    /// @notice a `whitelistGuardian` can whitelist accounts and can cancel whitelisted accounts' proposals when they
    /// fall.
    /// below `proposalThreshold.
    /// @dev Only the executor (timelock) can call this function.
    /// @param _newWhitelistGuardian The address of the new `whitelistGuardian`.
    function setWhitelistGuardian(address _newWhitelistGuardian) external {
        _checkGovernance();
        _setWhitelistGuardian(_newWhitelistGuardian);
    }

    /// @notice Sets a new proposal guardian.
    /// @dev This function can only be called by the executor (timelock).
    /// @param _newProposalGuardian The new proposal guardian to be set, including their address and expiration.
    function setProposalGuardian(ProposalGuardian memory _newProposalGuardian) external {
        _checkGovernance();
        _setProposalGuardian(_newProposalGuardian);
    }

    /// @notice Admin function for setting the whitelistGuardian. WhitelistGuardian can cancel proposals from
    /// whitelisted addresses.
    /// @param _newWhitelistGuardian Account to set whitelistGuardian to (0x0 to remove whitelistGuardian).
    function _setWhitelistGuardian(address _newWhitelistGuardian) internal {
        emit WhitelistGuardianSet(whitelistGuardian, _newWhitelistGuardian);
        whitelistGuardian = _newWhitelistGuardian;
    }

    /// @notice Internal function to set a new proposal guardian.
    /// @dev This function updates the proposal guardian and emits an event.
    /// @param _newProposalGuardian The new proposal guardian to be set, including their address and expiration.
    function _setProposalGuardian(ProposalGuardian memory _newProposalGuardian) internal {
        emit ProposalGuardianSet(
            proposalGuardian.account,
            proposalGuardian.expiration,
            _newProposalGuardian.account,
            _newProposalGuardian.expiration
        );
        proposalGuardian = _newProposalGuardian;
    }

    /// @inheritdoc GovernorTimelockCompoundUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function _cancel(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockCompoundUpgradeable) returns (uint256) {
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
    ) internal override(GovernorUpgradeable, GovernorPreventLateQuorumUpgradeable) returns (uint256) {
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
    ) internal override(GovernorUpgradeable, GovernorTimelockCompoundUpgradeable) {
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
    ) internal override(GovernorUpgradeable, GovernorTimelockCompoundUpgradeable) returns (uint48) {
        return GovernorTimelockCompoundUpgradeable._queueOperations(
            _proposalId, _targets, _values, _calldatas, _descriptionHash
        );
    }

    /// @inheritdoc GovernorPreventLateQuorumUpgradeable
    /// @dev We override this function to resolve ambiguity between inherited contracts.
    function proposalDeadline(uint256 _proposalId)
        public
        view
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
        override(GovernorUpgradeable, GovernorTimelockCompoundUpgradeable)
        returns (ProposalState)
    {
        return GovernorTimelockCompoundUpgradeable.state(_proposalId);
    }

    /// @inheritdoc GovernorCountingFractionalUpgradeable
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE()
        public
        pure
        override(IGovernor, GovernorCountingFractionalUpgradeable)
        returns (string memory)
    {
        return "support=bravo,fractional&quorum=for&params=fractional";
    }

    /// @notice Internal function that returns true if the amount of 'for' votes already cast meets the quorum limit,
    /// false otherwise.
    /// @dev We override this function to implement quorum functionality that only includes votes in favor.
    function _quorumReached(uint256 proposalId)
        internal
        view
        override(GovernorUpgradeable, GovernorCountingFractionalUpgradeable)
        returns (bool)
    {
        (, uint256 _forVotes,) = GovernorCountingFractionalUpgradeable.proposalVotes(proposalId);
        return quorum(proposalSnapshot(proposalId)) <= _forVotes;
    }
}
