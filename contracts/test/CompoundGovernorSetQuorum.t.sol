// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {ProposalTest} from "contracts/test/helpers/ProposalTest.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract CompoundGovernorSetQuorumTest is ProposalTest {
    function _buildSetQuorumProposal(uint256 _amount) private view returns (Proposal memory _proposal) {
        address[] memory _targets = new address[](1);
        _targets[0] = address(governor);

        uint256[] memory _values = new uint256[](1);
        _values[0] = 0;

        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = _buildProposalData("setQuorum(uint256)", abi.encode(_amount));

        _proposal = Proposal(_targets, _values, _calldatas, "Set New Quorum");
    }

    function testFuzz_SetQuorum(uint256 _newQuorum) public {
        _newQuorum = bound(_newQuorum, 1, INITIAL_QUORUM * 10);
        Proposal memory _proposal = _buildSetQuorumProposal(_newQuorum);
        _submitPassQueueAndExecuteProposal(delegatee, _proposal);
        assertEq(governor.quorum(block.timestamp), _newQuorum);
    }

    function testFuzz_FailSetQuorum(uint256 _newQuorum) public {
        vm.assume(_newQuorum != INITIAL_QUORUM);
        _newQuorum = bound(_newQuorum, 1, INITIAL_QUORUM * 10);
        Proposal memory _proposal = _buildSetQuorumProposal(_newQuorum);
        _submitAndFailProposal(delegatee, _proposal);
        assertEq(governor.quorum(block.timestamp), INITIAL_QUORUM);
    }

    function testFuzz_RevertIf_CalledByNonTimelock(address _caller, uint256 _newQuorum) public {
        vm.assume(_caller != address(timelock));
        vm.assume(_caller != PROXY_ADMIN_ADDRESS);
        vm.prank(_caller);
        _newQuorum = bound(_newQuorum, 1, INITIAL_QUORUM * 10);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorOnlyExecutor.selector, _caller));
        governor.setQuorum(_newQuorum);
    }
}
