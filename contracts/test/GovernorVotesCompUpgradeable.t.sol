// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {GovernorVotesCompUpgradeable} from "contracts/extensions/GovernorVotesCompUpgradeable.sol";
import {CompoundGovernorConstants} from "script/CompoundGovernorConstants.sol";
import {IComp} from "contracts/interfaces/IComp.sol";

contract GovernorVotesCompUpgradeableTestHarness is GovernorVotesCompUpgradeable {
    function initialize(IComp _compToken) public initializer {
        __GovernorVotesComp_init(_compToken);
    }

    function COUNTING_MODE() external view override returns (string memory) {}
    function _countVote(uint256 _proposalId, address _account, uint8 _support, uint256 _weight, bytes memory _params)
        internal
        override
        returns (uint256)
    {}
    function _quorumReached(uint256 _proposalId) internal view override returns (bool) {}
    function _voteSucceeded(uint256 _proposalId) internal view override returns (bool) {}
    function hasVoted(uint256 _proposalId, address account) external view override returns (bool) {}
    function quorum(uint256 _timepoint) public view override returns (uint256) {}
    function votingDelay() public view override returns (uint256) {}
    function votingPeriod() public view override returns (uint256) {}
}

contract GovernorVotesCompUpgradeableTest is Test, CompoundGovernorConstants {
    GovernorVotesCompUpgradeableTestHarness governorVotes;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("Please set RPC_URL in your .env file")), FORK_BLOCK);
        governorVotes = new GovernorVotesCompUpgradeableTestHarness();
        governorVotes.initialize(IComp(COMP_TOKEN_ADDRESS));
    }

    function test_Initialize() public view {
        assertEq(address(governorVotes.token()), address(COMP_TOKEN_ADDRESS));
    }

    function test_ReturnsBlockNumberAsClock() public view {
        assertEq(governorVotes.clock(), block.number);
    }

    function test_ReturnsBlockNumberAsDefaultClockMode() public view {
        assertEq(governorVotes.CLOCK_MODE(), "mode=blocknumber&from=default");
    }

    function testFuzz_ReturnsCorrectVotes(uint256 _blockNumber) public view {
        _blockNumber = bound(_blockNumber, 21_000_000, FORK_BLOCK - 1);
        for (uint256 i; i < _majorDelegates.length; i++) {
            uint256 _votingWeight = IComp(COMP_TOKEN_ADDRESS).getPriorVotes(_majorDelegates[i], _blockNumber);
            assertTrue(_votingWeight > 0);
            assertEq(governorVotes.getVotes(_majorDelegates[i], _blockNumber), _votingWeight);
        }
    }
}
