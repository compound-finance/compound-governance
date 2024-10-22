// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {GovernorCountingSimpleUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {CompoundGovernorTest} from "contracts/test/helpers/CompoundGovernorTest.sol";

contract ProposalTest is CompoundGovernorTest {
    struct Proposal {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    address constant COMPOUND_COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    uint256 public constant MINIMUM_DELAY = 2 days;

    address delegatee = makeAddr("delegatee");

    function setUp() public virtual override {
        super.setUp();
        vm.label(delegatee, "Delegatee");

        // make the new governor the admin of the timelock
        _updateTimelockAdminToNewGovernor(governor);

        // delegate to the delegate
        vm.prank(COMPOUND_COMPTROLLER);
        token.delegate(delegatee);

        // advance to next block so delegatee can vote
        vm.roll(vm.getBlockNumber() + 1);
    }

    function _buildProposalData(string memory _signature, bytes memory _calldata)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes4(keccak256(bytes(_signature))), _calldata);
    }

    function _assumeSafeReceiver(address _to) public pure {
        vm.assume(_to != address(0) && _to != COMPOUND_COMPTROLLER);
    }

    function _submitProposal(address _proposer, Proposal memory _proposal) public returns (uint256 _proposalId) {
        vm.prank(_proposer);
        _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_DELAY + 1);
    }

    function _passAndQueueProposal(Proposal memory _proposal, uint256 _proposalId) public {
        uint256 _timeLockDelay = timelock.delay();
        vm.prank(delegatee);
        governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        governor.queue(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );

        vm.warp(block.timestamp + _timeLockDelay + 1);
    }

    function _passQueueAndExecuteProposal(Proposal memory _proposal, uint256 _proposalId) public {
        uint256 _timeLockDelay = timelock.delay();
        vm.prank(delegatee);
        governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.For));

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
        governor.queue(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );

        vm.warp(block.timestamp + _timeLockDelay + 1);
        governor.execute(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function _failProposal(uint256 _proposalId) public {
        vm.prank(delegatee);
        governor.castVote(_proposalId, uint8(GovernorCountingSimpleUpgradeable.VoteType.Against));

        vm.roll(vm.getBlockNumber() + INITIAL_VOTING_PERIOD + 1);
    }

    function _submitPassAndQueueProposal(address _proposer, Proposal memory _proposal) public {
        uint256 _proposalId = _submitProposal(_proposer, _proposal);
        _passAndQueueProposal(_proposal, _proposalId);
    }

    function _submitPassQueueAndExecuteProposal(address _proposer, Proposal memory _proposal) public {
        uint256 _proposalId = _submitProposal(_proposer, _proposal);
        _passQueueAndExecuteProposal(_proposal, _proposalId);
    }

    function _submitAndFailProposal(address _proposer, Proposal memory _proposal) public {
        uint256 _proposalId = _submitProposal(_proposer, _proposal);
        _failProposal(_proposalId);
    }
}
