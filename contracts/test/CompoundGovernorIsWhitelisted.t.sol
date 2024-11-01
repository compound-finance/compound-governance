// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {CompoundGovernorTest} from "contracts/test/helpers/CompoundGovernorTest.sol";

contract CompoundGovernorIsWhitelistedTest is CompoundGovernorTest {
    function testFuzz_ReturnTrueIfAnAccountIsStillWithinExpiry(
        address _account,
        uint256 _expiration,
        uint256 _timeBeforeExpiry,
        uint256 _randomSeed
    ) public {
        _expiration = bound(_expiration, 1, type(uint256).max);
        _timeBeforeExpiry = bound(_timeBeforeExpiry, 0, _expiration - 1);

        vm.prank(_timelockOrWhitelistGuardian(_randomSeed));
        governor.setWhitelistAccountExpiration(_account, _expiration);

        vm.warp(_timeBeforeExpiry);
        vm.assertEq(governor.isWhitelisted(_account), true);
    }

    function testFuzz_ReturnFalseIfAnAccountIsExpired(
        address _account,
        uint256 _expiration,
        uint256 _timeAfterExpiry,
        uint256 _randomSeed
    ) public {
        _expiration = bound(_expiration, 1, type(uint256).max - 1);
        _timeAfterExpiry = bound(_timeAfterExpiry, _expiration, type(uint256).max);

        vm.prank(_timelockOrWhitelistGuardian(_randomSeed));
        governor.setWhitelistAccountExpiration(_account, _expiration);

        vm.warp(_timeAfterExpiry);
        vm.assertEq(governor.isWhitelisted(_account), false);
    }

    function testFuzz_ReturnFalseIfAnAccountIsNotWhitelisted(address _account) public view {
        vm.assertEq(governor.isWhitelisted(_account), false);
    }
}
