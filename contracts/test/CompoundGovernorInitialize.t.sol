// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {CompoundGovernorTest} from "contracts/test/helpers/CompoundGovernorTest.sol";

contract CompoundGovernorInitializeTest is CompoundGovernorTest {
    function testInitialize() public view {
        assertEq(governor.quorum(governor.clock()), INITIAL_QUORUM);
        assertEq(governor.votingPeriod(), INITIAL_VOTING_PERIOD);
        assertEq(governor.votingDelay(), INITIAL_VOTING_DELAY);
        assertEq(governor.proposalThreshold(), INITIAL_PROPOSAL_THRESHOLD);
        assertEq(governor.lateQuorumVoteExtension(), INITIAL_VOTE_EXTENSION);
        assertEq(address(governor.timelock()), TIMELOCK_ADDRESS);
        assertEq(address(governor.token()), COMP_TOKEN_ADDRESS);
        assertEq(governor.owner(), owner);
        assertEq(governor.whitelistGuardian(), whitelistGuardian);
        (address _proposalGuardian, uint96 _expiration) = governor.proposalGuardian();
        assertEq(_proposalGuardian, proposalGuardian.account);
        assertEq(_expiration, proposalGuardian.expiration);
    }
}
