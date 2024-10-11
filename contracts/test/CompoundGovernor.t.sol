// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {CompoundGovernorConstants} from "script/CompoundGovernorConstants.sol";
import {DeployCompoundGovernor} from "script/DeployCompoundGovernor.s.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";

contract CompoundGovernorTest is Test, CompoundGovernorConstants {
    CompoundGovernor governor;
    address owner;
    

    function setUp() public {
        // set the owner of the governor (use the anvil default account #0, if no environment variable is set)
        owner = vm.envOr("DEPLOYER_ADDRESS", 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

        // set the RPC URL and the fork block number to create a local execution fork for testing
        vm.createSelectFork(vm.envOr("RPC_URL", string("Please set RPC_URL in your .env file")), FORK_BLOCK);

        // Deploy the CompoundGovernor contract
        DeployCompoundGovernor _deployer = new DeployCompoundGovernor();
        _deployer.setUp();
        governor = _deployer.run(owner);
    }

    function testInitialize() public view {
        assertEq(governor.quorum(governor.clock()), INITIAL_QUORUM);
        assertEq(governor.votingPeriod(), INITIAL_VOTING_PERIOD);
        assertEq(governor.votingDelay(), INITIAL_VOTING_DELAY);
        assertEq(governor.proposalThreshold(), INITIAL_PROPOSAL_THRESHOLD);
        assertEq(governor.lateQuorumVoteExtension(), INITIAL_VOTE_EXTENSION);
        assertEq(address(governor.timelock()), TIMELOCK_ADDRESS);
        assertEq(address(governor.token()), COMP_TOKEN_ADDRESS);
        assertEq(governor.owner(), owner);
    }
}
