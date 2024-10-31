// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {ProposalTest} from "contracts/test/helpers/ProposalTest.sol";
import {IGovernor} from "contracts/extensions/IGovernor.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";

contract CompoundGovernorSetWhitelistGuardianTest is ProposalTest {
    function _buildSetWhitelistGuardianProposal(address _whitelistGuardian)
        private
        view
        returns (Proposal memory _proposal)
    {
        address[] memory _targets = new address[](1);
        _targets[0] = address(governor);

        uint256[] memory _values = new uint256[](1);
        _values[0] = 0;

        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = abi.encodeWithSelector(CompoundGovernor.setWhitelistGuardian.selector, _whitelistGuardian);

        _proposal = Proposal(_targets, _values, _calldatas, "Set New whitelistGuardian");
    }

    function testFuzz_SetsWhitelistGuardianAsTimelock(address _whitelistGuardian) public {
        Proposal memory _proposal = _buildSetWhitelistGuardianProposal(_whitelistGuardian);
        _submitPassQueueAndExecuteProposal(delegatee, _proposal);
        assertEq(governor.whitelistGuardian(), _whitelistGuardian);
    }

    function testFuzz_EmitsEventWhenAWhitelistGuardianIsSet(address _whitelistGuardian, address _caller) public {
        vm.assume(_caller != PROXY_ADMIN_ADDRESS);
        Proposal memory _proposal = _buildSetWhitelistGuardianProposal(_whitelistGuardian);
        _submitPassAndQueueProposal(delegatee, _proposal);

        vm.expectEmit();
        emit CompoundGovernor.WhitelistGuardianSet(governor.whitelistGuardian(), _whitelistGuardian);

        vm.prank(_caller);
        governor.execute(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function testFuzz_RevertIf_CallerIsNotTimelock(address _whitelistGuardian, address _caller) public {
        vm.assume(_caller != TIMELOCK_ADDRESS && _caller != PROXY_ADMIN_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorOnlyExecutor.selector, _caller));
        vm.prank(_caller);
        governor.setWhitelistGuardian(_whitelistGuardian);
    }
}
