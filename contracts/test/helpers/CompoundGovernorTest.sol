// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {CompoundGovernorConstants} from "script/CompoundGovernorConstants.sol";
import {DeployCompoundGovernor} from "script/DeployCompoundGovernor.s.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";
import {GovernorBravoDelegate} from "contracts/GovernorBravoDelegate.sol";
import {IComp} from "contracts/interfaces/IComp.sol";
import {GovernorCountingSimpleUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {ProposeUpgradeBravoToCompoundGovernor} from "script/ProposeUpgradeBravoToCompoundGovernor.s.sol";

contract CompoundGovernorTest is Test, CompoundGovernorConstants {
    struct Proposal {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    CompoundGovernor governor;
    IComp token;
    ICompoundTimelock timelock;
    address whitelistGuardian;
    CompoundGovernor.ProposalGuardian proposalGuardian;
    uint96 constant PROPOSAL_GUARDIAN_EXPIRY = 1_739_768_400;

    GovernorBravoDelegate public constant GOVERNOR_BRAVO = GovernorBravoDelegate(GOVERNOR_BRAVO_DELEGATE_ADDRESS);

    function setUp() public virtual {
        // set the RPC URL and the fork block number to create a local execution fork for testing
        vm.createSelectFork(vm.envOr("RPC_URL", string("Please set RPC_URL in your .env file")), FORK_BLOCK);

        if (_useDeployedCompoundGovernor()) {
            // Set the governor to be the deployed CompoundGovernor
            governor = CompoundGovernor(payable(DEPLOYED_UPGRADE_CANDIDATE));
            whitelistGuardian = governor.whitelistGuardian();
            (proposalGuardian.account, proposalGuardian.expiration) = governor.proposalGuardian();
        } else {
            whitelistGuardian = makeAddr("WHITELIST_GUARDIAN_ADDRESS");
            proposalGuardian = CompoundGovernor.ProposalGuardian(COMMUNITY_MULTISIG_ADDRESS, PROPOSAL_GUARDIAN_EXPIRY);

            // Deploy the CompoundGovernor contract
            DeployCompoundGovernor _deployer = new DeployCompoundGovernor();
            _deployer.setUp();
            governor = _deployer.run(whitelistGuardian, proposalGuardian);
        }
        timelock = ICompoundTimelock(payable(governor.timelock()));
        token = governor.token();

        // make the new governor the admin of the timelock
        if (_shouldPassAndExecuteUpgradeProposal()) {
            _updateTimelockAdminToNewGovernor(governor);
        }

        vm.label(GOVERNOR_BRAVO_DELEGATE_ADDRESS, "GovernorBravoDelegate");
        vm.label(address(governor), "CompoundGovernor");
        vm.label(address(timelock), "Timelock");
        vm.label(COMP_TOKEN_ADDRESS, "CompToken");
    }

    function _useDeployedCompoundGovernor() internal pure virtual returns (bool) {
        return false;
    }

    function _shouldPassAndExecuteUpgradeProposal() internal pure virtual returns (bool) {
        return true;
    }

    function _timelockOrWhitelistGuardian(uint256 _randomSeed) internal view returns (address) {
        return _randomSeed % 2 == 0 ? TIMELOCK_ADDRESS : whitelistGuardian;
    }

    /* Begin CompoundGovernor-related helper methods */

    function _getProposalId(Proposal memory _proposal) internal returns (uint256) {
        return governor.hashProposal(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function _buildProposalData(string memory _signature, bytes memory _calldata)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes4(keccak256(bytes(_signature))), _calldata);
    }

    function _buildAnEmptyProposal() internal pure returns (Proposal memory _proposal) {
        address[] memory _targets = new address[](1);
        uint256[] memory _values = new uint256[](1);
        bytes[] memory _calldatas = new bytes[](1);
        _proposal = Proposal(_targets, _values, _calldatas, "An Empty Proposal");
    }

    function _assumeSafeReceiver(address _to) public pure {
        vm.assume(_to != address(0));
    }

    function _submitProposal(Proposal memory _proposal) public returns (uint256 _proposalId) {
        vm.prank(_getRandomProposer());
        _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_DELAY + 1);
    }

    function _submitProposal(address _proposer, Proposal memory _proposal) public returns (uint256 _proposalId) {
        vm.prank(_proposer);
        _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_DELAY + 1);
    }

    function _getRandomProposer() internal returns (address) {
        return _majorDelegates[vm.randomUint(0, _majorDelegates.length - 1)];
    }

    function _passAndQueueProposal(Proposal memory _proposal, uint256 _proposalId) public {
        uint256 _timeLockDelay = timelock.delay();
        for (uint256 _index = 0; _index < _majorDelegates.length; _index++) {
            vm.prank(_majorDelegates[_index]);
            governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));
        }

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        governor.queue(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );

        vm.warp(block.timestamp + _timeLockDelay + 1);
    }

    function _passQueueAndExecuteProposal(uint256 _proposalId) public {
        uint256 _timeLockDelay = timelock.delay();
        for (uint256 _index = 0; _index < _majorDelegates.length; _index++) {
            vm.prank(_majorDelegates[_index]);
            governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));
        }

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        governor.queue(_proposalId);

        vm.warp(block.timestamp + _timeLockDelay + 1);
        governor.execute(_proposalId);
    }

    function _passQueueAndExecuteProposal(Proposal memory _proposal, uint256 _proposalId) public {
        uint256 _timeLockDelay = timelock.delay();
        for (uint256 _index = 0; _index < _majorDelegates.length; _index++) {
            vm.prank(_majorDelegates[_index]);
            governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));
        }

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        governor.queue(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );

        vm.warp(block.timestamp + _timeLockDelay + 1);
        governor.execute(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function _failProposal(uint256 _proposalId) public {
        for (uint256 _index = 0; _index < _majorDelegates.length; _index++) {
            vm.prank(_majorDelegates[_index]);
            governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.Against));
        }

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
    }

    function _submitPassAndQueueProposal(address _proposer, Proposal memory _proposal) public returns (uint256) {
        uint256 _proposalId = _submitProposal(_proposer, _proposal);
        _passAndQueueProposal(_proposal, _proposalId);
        return _proposalId;
    }

    function _submitPassQueueAndExecuteProposal(address _proposer, Proposal memory _proposal)
        public
        returns (uint256)
    {
        uint256 _proposalId = _submitProposal(_proposer, _proposal);
        _passQueueAndExecuteProposal(_proposal, _proposalId);
        return _proposalId;
    }

    function _submitAndFailProposal(address _proposer, Proposal memory _proposal) public returns (uint256) {
        uint256 _proposalId = _submitProposal(_proposer, _proposal);
        _failProposal(_proposalId);
        return _proposalId;
    }

    function _buildNewGovernorSetVotingDelayProposal(uint48 _amount)
        internal
        view
        returns (Proposal memory _proposal)
    {
        address[] memory _targets = new address[](1);
        _targets[0] = address(governor);

        uint256[] memory _values = new uint256[](1);
        _values[0] = 0;

        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = _buildProposalData("setVotingDelay(uint48)", abi.encode(_amount));

        _proposal = Proposal(_targets, _values, _calldatas, "Set New Voting Delay on New Compound Governor");
    }

    function _buildAndSubmitOldGovernorSetVotingDelayProposal(uint256 _proposerIndex, uint256 _amount)
        internal
        returns (uint256 _proposalId)
    {
        vm.assume(_amount >= GOVERNOR_BRAVO.MIN_VOTING_DELAY() && _amount <= GOVERNOR_BRAVO.MAX_VOTING_DELAY());
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        address[] memory _targets = new address[](1);
        uint256[] memory _values = new uint256[](1);
        string[] memory _signatures = new string[](1);
        bytes[] memory _calldatas = new bytes[](1);

        _targets[0] = GOVERNOR_BRAVO_DELEGATE_ADDRESS;
        _values[0] = 0;
        _signatures[0] = "_setVotingDelay(uint256)";
        _calldatas[0] = abi.encode(uint256(_amount));

        vm.prank(_majorDelegates[0]);
        return
            GOVERNOR_BRAVO.propose(_targets, _values, _signatures, _calldatas, "Set Voting Delay on Old Governor Bravo");
    }

    /* End CompoundGovernor-related helper methods */

    /* Begin Bravo-related helper methods */

    function _updateTimelockAdminToNewGovernor(CompoundGovernor _newGovernor) internal {
        ProposeUpgradeBravoToCompoundGovernor _proposeUpgrade = new ProposeUpgradeBravoToCompoundGovernor();

        // runs the script to propose the upgrade
        uint256 _upgradeProposalId = _proposeUpgrade.run(_newGovernor);

        // manage the votes to pass the upgrade proposal
        _passQueueAndExecuteBravoProposal(_upgradeProposalId);
    }

    function _getBravoProposalStartBlock(uint256 _bravoProposalId) internal view returns (uint256) {
        (,,, uint256 _startBlock,,,,,,) = GOVERNOR_BRAVO.proposals(_bravoProposalId);
        return _startBlock;
    }

    function _getBravoProposalEndBlock(uint256 _bravoProposalId) internal view returns (uint256) {
        (,,,, uint256 _endBlock,,,,,) = GOVERNOR_BRAVO.proposals(_bravoProposalId);
        return _endBlock;
    }

    function _jumpToActiveBravoProposal(uint256 _bravoProposalId) internal {
        vm.roll(_getBravoProposalStartBlock(_bravoProposalId) + 1);
    }

    function _jumpToBravoVoteComplete(uint256 _bravoProposalId) internal {
        vm.roll(_getBravoProposalEndBlock(_bravoProposalId) + 1);
    }

    function _delegatesVoteOnBravoProposal(
        uint256 _bravoProposalId,
        GovernorCountingSimpleUpgradeable.VoteType _support
    ) internal {
        for (uint256 _index = 0; _index < _majorDelegates.length; _index++) {
            vm.prank(_majorDelegates[_index]);
            GOVERNOR_BRAVO.castVote(_bravoProposalId, uint8(_support));
        }
    }

    function _getBravoProposalEta(uint256 _bravoProposalId) internal view returns (uint256) {
        (,, uint256 _eta,,,,,,,) = GOVERNOR_BRAVO.proposals(_bravoProposalId);
        return _eta;
    }

    function _jumpPastBravoProposalEta(uint256 _bravoProposalId) internal {
        vm.roll(vm.getBlockNumber() + 1); // move up one block so not in the same block as when queued
        vm.warp(_getBravoProposalEta(_bravoProposalId) + 1); // jump past the eta timestamp
    }

    function _passBravoProposal(uint256 _bravoProposalId) internal {
        _jumpToActiveBravoProposal(_bravoProposalId);
        _delegatesVoteOnBravoProposal(_bravoProposalId, GovernorCountingSimpleUpgradeable.VoteType.For);
        _jumpToBravoVoteComplete(_bravoProposalId);
    }

    function _failBravoProposal(uint256 _bravoProposalId) internal {
        _jumpToActiveBravoProposal(_bravoProposalId);
        _delegatesVoteOnBravoProposal(_bravoProposalId, GovernorCountingSimpleUpgradeable.VoteType.Against);
        _jumpToBravoVoteComplete(_bravoProposalId);
    }

    function _passAndQueueBravoProposal(uint256 _bravoProposalId) internal {
        _passBravoProposal(_bravoProposalId);
        GOVERNOR_BRAVO.queue(_bravoProposalId);
    }

    function _passQueueAndExecuteBravoProposal(uint256 _bravoProposalId) public {
        _passAndQueueBravoProposal(_bravoProposalId);
        _jumpPastBravoProposalEta(_bravoProposalId);
        GOVERNOR_BRAVO.execute(_bravoProposalId);
    }

    function _upgradeFromBravoToCompoundGovernorViaProposalVote() internal {
        // Create the proposal to upgrade the Bravo governor to the CompoundGovernor
        ProposeUpgradeBravoToCompoundGovernor _proposeUpgrade = new ProposeUpgradeBravoToCompoundGovernor();
        uint256 _upgradeProposalId = _proposeUpgrade.run(governor);

        // Pass, queue, and execute the proposal
        _passQueueAndExecuteBravoProposal(_upgradeProposalId);
    }

    function _failProposalVoteForUpgradeFromBravoToCompoundGovernor() internal {
        // Create the proposal to upgrade the Bravo governor to the CompoundGovernor
        ProposeUpgradeBravoToCompoundGovernor _proposeUpgrade = new ProposeUpgradeBravoToCompoundGovernor();
        uint256 _upgradeProposalId = _proposeUpgrade.run(governor);

        // Pass, queue, and execute the proposal
        _failBravoProposal(_upgradeProposalId);
    }

    /* End Bravo-related helper methods */
}
