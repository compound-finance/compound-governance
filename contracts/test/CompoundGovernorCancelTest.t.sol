// SPDX-License-Identifier: BSD-3-Clause

pragma solidity 0.8.26;

import {CompoundGovernorTest} from "contracts/test/helpers/CompoundGovernorTest.sol";
import {IGovernor} from "contracts/extensions/IGovernor.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";

contract CompoundGovernorCancelTest is CompoundGovernorTest {
    function _setWhitelistedProposer(address _proposer) private {
        vm.prank(whitelistGuardian);
        governor.setWhitelistAccountExpiration(_proposer, block.timestamp + 2_000_000);
    }

    function _removeDelegateeVotingWeight(address _proposer) private {
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.getPriorVotes.selector, _proposer, block.number - 1),
            abi.encode(0) // Return 0 as the new voting weight
        );
    }

    function testFuzz_ProposerCanCancelItsOwnProposal(uint256 _randomIndex) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitPassAndQueueProposal(_proposer, _proposal);

        vm.prank(_proposer);
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
        vm.assertEq(uint256(governor.state(_proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testFuzz_ProposalGuardianCanCancelAnyProposal(uint256 _randomIndex) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitPassAndQueueProposal(_proposer, _proposal);

        vm.prank(proposalGuardian.account);
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
        vm.assertEq(uint256(governor.state(_proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testFuzz_AnyoneCanCancelAProposalBelowThreshold(address _caller, uint256 _randomIndex) public {
        vm.assume(_caller != PROXY_ADMIN_ADDRESS);
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitPassAndQueueProposal(_proposer, _proposal);
        _removeDelegateeVotingWeight(_proposer);

        vm.prank(_caller);
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
        vm.assertEq(uint256(governor.state(_proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testFuzz_WhitelistGuardianCanCancelWhitelistedProposalBelowThreshold(uint256 _randomIndex) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _setWhitelistedProposer(_proposer);
        _submitPassAndQueueProposal(_proposer, _proposal);
        _removeDelegateeVotingWeight(_proposer);

        vm.prank(whitelistGuardian);
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
        vm.assertEq(uint256(governor.state(_proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testFuzz_RevertIf_NonProposerOrGuardianCancelsProposalAboveThreshold(address _caller, uint256 _randomIndex)
        public
    {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        vm.assume(_caller != proposalGuardian.account && _caller != _proposer && _caller != PROXY_ADMIN_ADDRESS);
        Proposal memory _proposal = _buildAnEmptyProposal();
        _submitPassAndQueueProposal(_proposer, _proposal);

        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                CompoundGovernor.Unauthorized.selector, bytes32("Proposer above proposalThreshold"), _caller
            )
        );
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function testFuzz_RevertIf_NonWhitelistGuardianCancelsWhitelistedProposalBelowThreshold(
        address _caller,
        uint256 _randomIndex
    ) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        vm.assume(
            _caller != whitelistGuardian && _caller != _proposer && _caller != proposalGuardian.account
                && _caller != PROXY_ADMIN_ADDRESS
        );

        Proposal memory _proposal = _buildAnEmptyProposal();
        _setWhitelistedProposer(_proposer);
        _submitPassAndQueueProposal(_proposer, _proposal);
        _removeDelegateeVotingWeight(_proposer);

        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSelector(CompoundGovernor.Unauthorized.selector, bytes32("Not whitelistGuardian"), _caller)
        );
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function testFuzz_RevertIf_NonProposerOrGuardianCancelsWhitelistedProposalAboveThreshold(
        address _caller,
        uint256 _randomIndex
    ) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        vm.assume(_caller != _proposer && _caller != proposalGuardian.account && _caller != PROXY_ADMIN_ADDRESS);
        Proposal memory _proposal = _buildAnEmptyProposal();
        vm.prank(whitelistGuardian);
        governor.setWhitelistAccountExpiration(_proposer, block.timestamp + 2_000_000);
        vm.assertTrue(governor.isWhitelisted(_proposer));

        _submitPassAndQueueProposal(_proposer, _proposal);

        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                CompoundGovernor.Unauthorized.selector, bytes32("Proposer above proposalThreshold"), _caller
            )
        );
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }
}
