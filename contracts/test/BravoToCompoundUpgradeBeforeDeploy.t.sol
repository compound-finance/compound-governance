// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {BravoToCompoundGovernorUpgradeTest} from "contracts/test/helpers/BravoToCompoundGovernorUpgradeTest.sol";

contract BravoToCompoundUpgradeBeforeDeployTest is BravoToCompoundGovernorUpgradeTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function _useDeployedCompoundGovernor() internal pure override returns (bool) {
        // returning false indicates the deployment of a new CompoundGovernor is desired by this test.
        return false;
    }
}
