// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {ProposalTest} from "contracts/test/helpers/ProposalTest.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";

contract CompoundGovernorSetProposalGuardianTest is ProposalTest {
    function _buildSetProposalGuardianProposal(CompoundGovernor.ProposalGuardian memory _proposalGuardian)
        private
        view
        returns (Proposal memory _proposal)
    {
        address[] memory _targets = new address[](1);
        _targets[0] = address(governor);

        uint256[] memory _values = new uint256[](1);
        _values[0] = 0;

        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = abi.encodeWithSelector(CompoundGovernor.setProposalGuardian.selector, _proposalGuardian);

        _proposal = Proposal(_targets, _values, _calldatas, "Set New proposalGuardian");
    }

    function testFuzz_SetsProposalGuardianAsTimelock(CompoundGovernor.ProposalGuardian memory _proposalGuardian)
        public
    {
        Proposal memory _proposal = _buildSetProposalGuardianProposal(_proposalGuardian);
        _submitPassQueueAndExecuteProposal(delegatee, _proposal);
        (address _account, uint96 _expiration) = governor.proposalGuardian();
        assertEq(_account, _proposalGuardian.account);
        assertEq(_expiration, _proposalGuardian.expiration);
    }

    function testFuzz_EmitsEventWhenAProposalGuardianIsSetByTheTimelock(
        CompoundGovernor.ProposalGuardian memory _proposalGuardian,
        address _caller
    ) public {
        vm.assume(_caller != PROXY_ADMIN_ADDRESS);
        (address _currentAccount, uint96 _currentExpiration) = governor.proposalGuardian();
        Proposal memory _proposal = _buildSetProposalGuardianProposal(_proposalGuardian);
        _submitPassAndQueueProposal(delegatee, _proposal);

        vm.expectEmit();
        emit CompoundGovernor.ProposalGuardianSet(
            _currentAccount, _currentExpiration, _proposalGuardian.account, _proposalGuardian.expiration
        );

        vm.prank(_caller);
        governor.execute(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function testFuzz_RevertIf_CallerIsNotTimelock(
        CompoundGovernor.ProposalGuardian memory _proposalGuardian,
        address _caller
    ) public {
        vm.assume(_caller != TIMELOCK_ADDRESS && _caller != PROXY_ADMIN_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorOnlyExecutor.selector, _caller));
        vm.prank(_caller);
        governor.setProposalGuardian(_proposalGuardian);
    }
}
