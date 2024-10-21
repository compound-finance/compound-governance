// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {CompoundGovernorConstants} from "script/CompoundGovernorConstants.sol";
import {DeployCompoundGovernor} from "script/DeployCompoundGovernor.s.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";
import {IComp} from "contracts/interfaces/IComp.sol";

contract CompoundGovernorTest is Test, CompoundGovernorConstants {
    CompoundGovernor governor;
    IComp token;
    ICompoundTimelock timelock;
    address owner;

    function setUp() public virtual {
        // set the owner of the governor (use the anvil default account #0, if no environment variable is set)
        owner = vm.envOr("DEPLOYER_ADDRESS", 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

        // set the RPC URL and the fork block number to create a local execution fork for testing
        vm.createSelectFork(vm.envOr("RPC_URL", string("Please set RPC_URL in your .env file")), FORK_BLOCK);

        // Deploy the CompoundGovernor contract
        DeployCompoundGovernor _deployer = new DeployCompoundGovernor();
        _deployer.setUp();
        governor = _deployer.run(owner);
        token = governor.token();
        timelock = ICompoundTimelock(payable(governor.timelock()));
    }

    function _updateTimelockAdminToNewGovernor(CompoundGovernor _newGovernor) internal {
        address _timelockAddress = governor.timelock();
        ICompoundTimelock _timelock = ICompoundTimelock(payable(_timelockAddress));
        vm.prank(_timelockAddress);
        _timelock.setPendingAdmin(address(_newGovernor));
        vm.prank(address(_newGovernor));
        _timelock.acceptAdmin();
    }
}
