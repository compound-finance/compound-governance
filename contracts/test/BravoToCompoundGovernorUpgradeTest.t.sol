// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {CompoundGovernorTest} from "contracts/test/helpers/CompoundGovernorTest.sol";

abstract contract BravoToCompoundGovernorUpgradeTest is CompoundGovernorTest {
    function test_SuccessfulUpgradeToCompoundGovernor() public {
        _upgradeFromBravoToCompoundGovernorViaProposalVote();
        assertEq(timelock.admin(), address(governor));
    }

    function test_FailUpgradeToCompoundGovernor() public {
        _failProposalVoteForUpgradeFromBravoToCompoundGovernor();
        assertEq(timelock.admin(), GOVERNOR_BRAVO_DELEGATE_ADDRESS);
    }

    function testFuzz_NewGovernorProposalCanBePassedAfterSuccessfulUpgrade(
        uint256 _proposerIndex,
        uint48 _newVotingDelay
    ) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _upgradeFromBravoToCompoundGovernorViaProposalVote();
        assertEq(timelock.admin(), address(governor));
        Proposal memory _proposal = _buildNewGovernorSetVotingDelayProposal(_newVotingDelay);
        _submitPassQueueAndExecuteProposal(_majorDelegates[_proposerIndex], _proposal);
        assertEq(governor.votingDelay(), _newVotingDelay);
    }

    function testFuzz_RevertIf_OldGovernorAttemptsQueueingAfterSuccessfulUpgrade(
        uint256 _proposerIndex,
        uint256 _newVotingDelay
    ) public {
        uint256 _originalVotingDelay = GOVERNOR_BRAVO.votingDelay();
        vm.assume(_newVotingDelay != _originalVotingDelay);
        _upgradeFromBravoToCompoundGovernorViaProposalVote();
        assertEq(timelock.admin(), address(governor));
        uint256 _proposalId = _buildAndSubmitOldGovernorSetVotingDelayProposal(_proposerIndex, _newVotingDelay);
        _passBravoProposal(_proposalId);
        vm.expectRevert("Timelock::queueTransaction: Call must come from admin.");
        GOVERNOR_BRAVO.queue(_proposalId);
        assertEq(GOVERNOR_BRAVO.votingDelay(), _originalVotingDelay);
    }

    function testFuzz_OldGovernorProposalCanBePassedAfterFailedUpgrade(uint256 _proposerIndex, uint256 _newVotingDelay)
        public
    {
        uint256 _originalVotingDelay = GOVERNOR_BRAVO.votingDelay();
        vm.assume(_newVotingDelay != _originalVotingDelay);
        _failProposalVoteForUpgradeFromBravoToCompoundGovernor();
        assertEq(timelock.admin(), GOVERNOR_BRAVO_DELEGATE_ADDRESS);
        uint256 _proposalId = _buildAndSubmitOldGovernorSetVotingDelayProposal(_proposerIndex, _newVotingDelay);
        _passQueueAndExecuteBravoProposal(_proposalId);
        assertEq(GOVERNOR_BRAVO.votingDelay(), _newVotingDelay);
    }
}

contract PreUpgradeTest is BravoToCompoundGovernorUpgradeTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function _useDeployedCompoundGovernor() internal pure override returns (bool) {
        // returning false indicates that a new CompoundGovernor should be deployed before the inherited tests are run.
        return false;
    }

    function _shouldPassAndExecuteUpgradeProposal() internal pure override returns (bool) {
        // returning false indicates the upgrade proposal should not be passed and executed before the inherited tests
        // are run.
        return false;
    }
}
