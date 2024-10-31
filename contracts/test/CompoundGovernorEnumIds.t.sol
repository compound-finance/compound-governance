// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {ProposalTest} from "contracts/test/helpers/ProposalTest.sol";
import {IGovernor} from "contracts/extensions/IGovernor.sol";
import {GovernorCountingSimpleUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";

contract CompoundGovernorEnumIdsTest is ProposalTest {
    function _buildBasicProposal(uint256 _newThreshold, string memory _description)
        private
        view
        returns (Proposal memory _proposal)
    {
        address[] memory _targets = new address[](1);
        _targets[0] = address(governor);

        uint256[] memory _values = new uint256[](1);
        _values[0] = 0;

        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = _buildProposalData("setProposalThreshold(uint256)", abi.encode(_newThreshold));
        _proposal = Proposal(_targets, _values, _calldatas, _description);
    }

    function testFuzz_ProposalCreatedEventEmittedWithEnumeratedProposalId(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        string memory _description = "Checking for enumearted proposal IDs on events";
        Proposal memory _firstProposal = _buildBasicProposal(_newValue, "First proposal to get and ID");
        uint256 _firstProposalId = _submitProposal(delegatee, _firstProposal);
        uint256 _originalProposalCount = governor.proposalCount();
        Proposal memory _proposal = _buildBasicProposal(_newValue, _description);
        vm.expectEmit(true, true, true, true);
        emit IGovernor.ProposalCreated(
            _firstProposalId + 1,
            delegatee,
            _proposal.targets,
            _proposal.values,
            new string[](_proposal.targets.length),
            _proposal.calldatas,
            block.number + INITIAL_VOTING_DELAY,
            block.number + INITIAL_VOTING_DELAY + INITIAL_VOTING_PERIOD,
            _description
        );
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        assertEq(_proposalId, _firstProposalId + 1);
        assertEq(governor.proposalCount(), _originalProposalCount + 1);
    }

    function testFuzz_ProposalIdsAreSequential(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal1 = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId1 = _submitProposal(delegatee, _proposal1);
        Proposal memory _proposal2 = _buildBasicProposal(_newValue + 1, "Second Proposal");
        uint256 _proposalId2 = _submitProposal(delegatee, _proposal2);
        assertEq(_proposalId2, _proposalId1 + 1);
    }

    function testFuzz_ProposalDeadlineCorrectWithEnumeratedId(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        uint256 _clockAtSubmit = governor.clock();
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        uint256 _deadline = governor.proposalDeadline(_proposalId);
        assertEq(_deadline, _clockAtSubmit + INITIAL_VOTING_DELAY + INITIAL_VOTING_PERIOD);
    }

    function testFuzz_ZeroReturnedIf_ProposalDeadlineCalledWithInvalidProposalId(uint256 _invalidProposalId, uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        vm.assume(_invalidProposalId != _proposalId);
        uint256 _deadline = governor.proposalDeadline(_invalidProposalId);
        assertEq(_deadline, 0);
    }

    function testFuzz_ProposalSnapshotCorrectWithEnumeratedId(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        uint256 _clockAtSubmit = governor.clock();
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        uint256 _snapShot = governor.proposalSnapshot(_proposalId);
        assertEq(_snapShot, _clockAtSubmit + INITIAL_VOTING_DELAY);
    }

    function testFuzz_ZeroReturnedIf_ProposalSnapshotCalledWithInvalidProposalId(uint256 _invalidProposalId, uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        vm.assume(_invalidProposalId != _proposalId);
        uint256 _snapShot = governor.proposalSnapshot(_invalidProposalId);
        assertEq(_snapShot, 0);
    }

    function testFuzz_ProposalEtaCorrectWithEnumeratedId(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        vm.prank(delegatee);
        governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));
        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        uint256 _timeOfQueue = block.timestamp;
        governor.queue(_proposalId);
        uint256 _eta = governor.proposalEta(_proposalId);
        assertEq(_eta, _timeOfQueue + timelock.delay());
    }

    function testFuzz_ZeroReturnedIf_ProposalEtaCalledWithInvalidProposalId(uint256 _invalidProposalId, uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        vm.assume(_invalidProposalId != _proposalId);
        vm.prank(delegatee);
        governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));
        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        governor.queue(_proposalId);
        uint256 _eta = governor.proposalEta(_invalidProposalId);
        assertEq(_eta, 0);
    }

    function testFuzz_ProposalProposerCorrectWithEnumeratedId(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        address _proposer = governor.proposalProposer(_proposalId);
        assertEq(_proposer, delegatee);
    }

    function testFuzz_ZeroReturnedIf_ProposalProposerCalledWithInvalidProposalId(uint256 _invalidProposalId, uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        vm.assume(_invalidProposalId != _proposalId);
        address _proposer = governor.proposalProposer(_invalidProposalId);
        assertEq(_proposer, address(0));
    }

    function testFuzz_ProposalQueuedCorrectlyWithEnumeratedId(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        vm.prank(delegatee);
        governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));
        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        governor.queue(_proposalId);
        assertEq(uint8(governor.state(_proposalId)), uint8(IGovernor.ProposalState.Queued));
    }

    function testFuzz_RevertIf_QueueCalledWithInvalidProposalId(uint256 _invalidProposalId, uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        vm.assume(_invalidProposalId != _proposalId);
        vm.prank(delegatee);
        governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));
        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorNonexistentProposal.selector, _invalidProposalId));
        governor.queue(_invalidProposalId);
    }

    function testFuzz_ProposalExecutedCorrectlyWithEnumeratedId(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD + 1, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        vm.prank(delegatee);
        governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));
        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        governor.queue(_proposalId);
        vm.warp(block.timestamp + timelock.delay() + 1);
        governor.execute(_proposalId);
        assertEq(uint8(governor.state(_proposalId)), uint8(IGovernor.ProposalState.Executed));
        assertEq(governor.proposalThreshold(), _newValue);
    }

    function testFuzz_RevertIf_ExecutedWithInvalidProposalId(uint256 _invalidProposalId, uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD + 1, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId = _submitProposal(delegatee, _proposal);
        vm.assume(_invalidProposalId != _proposalId);
        vm.prank(delegatee);
        governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));
        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        governor.queue(_proposalId);
        vm.warp(block.timestamp + timelock.delay() + 1);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorNonexistentProposal.selector, _invalidProposalId));
        governor.execute(_invalidProposalId);
    }

    function testFuzz_ProposalCanBeCanceledWithEnumeratedId(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        vm.startPrank(delegatee);
        uint256 _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);
        governor.cancel(_proposalId);
        vm.stopPrank();
        assertEq(uint8(governor.state(_proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    function testFuzz_RevertIf_CancelCalledWithInvalidProposalId(uint256 _invalidProposalId, uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        vm.startPrank(delegatee);
        uint256 _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);
        vm.assume(_invalidProposalId != _proposalId);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorNonexistentProposal.selector, _invalidProposalId));
        governor.cancel(_invalidProposalId);
        vm.stopPrank();
    }
}
