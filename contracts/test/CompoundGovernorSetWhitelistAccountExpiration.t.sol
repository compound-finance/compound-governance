// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {ProposalTest} from "contracts/test/helpers/ProposalTest.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";

contract CompoundGovernorSetWhitelistAccountExpirationTest is ProposalTest {
    function testFuzz_WhitelistAnAccountAsTimelock(address _account, uint256 _expiration) public {
        vm.prank(TIMELOCK_ADDRESS);
        governor.setWhitelistAccountExpiration(_account, _expiration);
        assertEq(governor.whitelistAccountExpirations(_account), _expiration);
    }

    function testFuzz_WhitelistAnAccountAsWhitelistGuardian(address _account, uint256 _expiration) public {
        vm.prank(whitelistGuardian);
        governor.setWhitelistAccountExpiration(_account, _expiration);
        assertEq(governor.whitelistAccountExpirations(_account), _expiration);
    }

    function testFuzz_EmitsEventWhenAnAccountIsWhitelisted(address _account, uint256 _expiration, uint256 _randomSeed)
        public
    {
        vm.prank(_timelockOrWhitelistGuardian(_randomSeed));
        vm.expectEmit();
        emit CompoundGovernor.WhitelistAccountExpirationSet(_account, _expiration);
        governor.setWhitelistAccountExpiration(_account, _expiration);
    }

    function testFuzz_RevertIf_CallerIsNotTimelockNorWhitelistGuardian(
        address _account,
        uint256 _expiration,
        address _caller
    ) public {
        vm.assume(
            _caller != TIMELOCK_ADDRESS && _caller != whitelistGuardian && _caller != address(governor)
                && _caller != PROXY_ADMIN_ADDRESS
        );
        vm.prank(_caller);

        vm.expectRevert(
            abi.encodeWithSelector(CompoundGovernor.Unauthorized.selector, bytes32("Not timelock or guardian"), _caller)
        );
        governor.setWhitelistAccountExpiration(_account, _expiration);
    }
}
