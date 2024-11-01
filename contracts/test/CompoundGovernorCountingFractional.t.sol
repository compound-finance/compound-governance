// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {CompoundGovernorTest} from "contracts/test/helpers/CompoundGovernorTest.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorCountingFractionalUpgradeable} from "contracts/CompoundGovernor.sol";

abstract contract CountingMode is CompoundGovernorTest {
    function testFuzz_ReturnsCorrectCountingMode() public view {
        assertEq(governor.COUNTING_MODE(), "support=bravo,fractional&quorum=for,abstain&params=fractional");
    }
}

abstract contract HasVoted is CompoundGovernorTest {
    function testFuzz_ReturnsCorrectVotingStatus(
        bool _hasVotedBefore,
        uint256 _voteSeed,
        uint256 _proposerIndex,
        uint256 _voterIndex
    ) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _voterIndex = bound(_voterIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_proposerIndex];
        address _voter = _majorDelegates[_voterIndex];

        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitProposal(_proposer, _proposal);

        vm.prank(_voter);
        if (_hasVotedBefore) {
            governor.castVote(_proposalId, uint8(_voteSeed % 3));
        }

        assertEq(governor.hasVoted(_proposalId, _voter), _hasVotedBefore ? true : false);
    }
}

abstract contract UsedVotes is CompoundGovernorTest {
    function testFuzz_ReturnsCorrectUsedVotes(
        uint256 _proposerIndex,
        uint256 _voterIndex,
        uint256 _forVotes,
        uint256 _againstVotes,
        uint256 _abstainVotes
    ) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _voterIndex = bound(_voterIndex, 0, _majorDelegates.length - 1);

        address _proposer = _majorDelegates[_proposerIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitProposal(_proposer, _proposal);

        address _delegate = _majorDelegates[_voterIndex];
        uint256 _votes = governor.getVotes(_delegate, vm.getBlockNumber() - 1);
        _forVotes = bound(_forVotes, 0, _votes);
        _againstVotes = bound(_againstVotes, 0, _votes - _forVotes);
        _abstainVotes = bound(_abstainVotes, 0, _votes - _forVotes - _againstVotes);

        vm.prank(_delegate);
        bytes memory _params = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
        governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _params);

        assertEq(governor.usedVotes(_proposalId, _delegate), _forVotes + _againstVotes + _abstainVotes);
    }
}

abstract contract CastVoteWithReasonAndParams is CompoundGovernorTest {
    function testFuzz_CastVotesViaFlexibleVoting(
        uint256 _proposerIndex,
        uint256 _voterIndex,
        uint256 _forVotes,
        uint256 _againstVotes,
        uint256 _abstainVotes
    ) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _voterIndex = bound(_voterIndex, 0, _majorDelegates.length - 1);

        address _proposer = _majorDelegates[_proposerIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitProposal(_proposer, _proposal);

        address _delegate = _majorDelegates[_voterIndex];
        uint256 _votes = governor.getVotes(_delegate, vm.getBlockNumber() - 1);
        _forVotes = bound(_forVotes, 0, _votes);
        _againstVotes = bound(_againstVotes, 0, _votes - _forVotes);
        _abstainVotes = bound(_abstainVotes, 0, _votes - _forVotes - _againstVotes);

        vm.prank(_delegate);
        bytes memory _params = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
        governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _params);

        (uint256 _againstVotesCast, uint256 _forVotesCast, uint256 _abstainVotesCast) =
            governor.proposalVotes(_proposalId);

        assertEq(_againstVotesCast, _againstVotes);
        assertEq(_forVotesCast, _forVotes);
        assertEq(_abstainVotesCast, _abstainVotes);
    }

    function testFuzz_CastVotesTwiceViaFlexibleVoting(
        uint256 _proposerIndex,
        uint256 _voterIndex,
        uint256 _firstVote,
        uint256 _secondVote,
        uint256 _forVotes,
        uint256 _againstVotes,
        uint256 _abstainVotes
    ) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _voterIndex = bound(_voterIndex, 0, _majorDelegates.length - 1);
        uint256 _proposalId;

        {
            address _proposer = _majorDelegates[_proposerIndex];
            Proposal memory _proposal = _buildAnEmptyProposal();
            _proposalId = _getProposalId(_proposal);
            _submitProposal(_proposer, _proposal);
        }

        address _delegate = _majorDelegates[_voterIndex];
        uint256 _votes = governor.getVotes(_delegate, vm.getBlockNumber() - 1);
        _firstVote = bound(_firstVote, 0, _votes - 1);
        _forVotes = bound(_forVotes, 0, _firstVote);
        _againstVotes = bound(_againstVotes, 0, _firstVote - _forVotes);
        _abstainVotes = bound(_abstainVotes, 0, _firstVote - _forVotes - _againstVotes);

        {
            vm.prank(_delegate);
            bytes memory _params = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
            governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _params);
        }

        // Second Vote
        _secondVote = bound(_secondVote, 0, _votes - _firstVote);
        uint256 _forFirstVote = _forVotes;
        _forVotes = bound(uint256(keccak256(abi.encode(_forVotes))), 0, _secondVote);
        uint256 _againstFirstVote = _againstVotes;
        _againstVotes = bound(uint256(keccak256(abi.encode(_againstVotes))), 0, _secondVote - _forVotes);
        uint256 _abstainFirstVote = _abstainVotes;
        _abstainVotes = bound(uint256(keccak256(abi.encode(_abstainVotes))), 0, _secondVote - _forVotes - _againstVotes);

        {
            vm.prank(_delegate);
            bytes memory _params = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
            governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _params);
        }

        (uint256 _againstVotesCast2, uint256 _forVotesCast2, uint256 _abstainVotesCast2) =
            governor.proposalVotes(_proposalId);

        assertEq(_againstVotesCast2, _againstFirstVote + _againstVotes);
        assertEq(_forVotesCast2, _forFirstVote + _forVotes);
        assertEq(_abstainVotesCast2, _abstainFirstVote + _abstainVotes);
    }

    function testFuzz_CastFractionalVotesThenNominalVotesViaFlexibleVoting(
        uint256 _proposerIndex,
        uint256 _voterIndex,
        uint256 _forVotes,
        uint256 _againstVotes,
        uint256 _abstainVotes,
        uint256 _voteSeed
    ) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _voterIndex = bound(_voterIndex, 0, _majorDelegates.length - 1);

        address _proposer = _majorDelegates[_proposerIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitProposal(_proposer, _proposal);

        address _delegate = _majorDelegates[_voterIndex];
        uint256 _votes = governor.getVotes(_delegate, vm.getBlockNumber() - 1);
        _forVotes = bound(_forVotes, 0, _votes - 1);
        _againstVotes = bound(_againstVotes, 0, _votes - 1 - _forVotes);
        _abstainVotes = bound(_abstainVotes, 0, _votes - 1 - _forVotes - _againstVotes);

        {
            vm.prank(_delegate);
            bytes memory _params = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
            governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _params);
        }

        // Nominal Votes
        uint8 _support = uint8(_voteSeed % 3);
        vm.prank(_delegate);
        governor.castVoteWithReasonAndParams(_proposalId, _support, "MyReason", "");

        (uint256 _againstVotesCast, uint256 _forVotesCast, uint256 _abstainVotesCast) =
            governor.proposalVotes(_proposalId);
        assertEq(_againstVotesCast, _support == 0 ? _votes - _forVotes - _abstainVotes : _againstVotes);
        assertEq(_forVotesCast, _support == 1 ? _votes - _againstVotes - _abstainVotes : _forVotes);
        assertEq(_abstainVotesCast, _support == 2 ? _votes - _againstVotes - _forVotes : _abstainVotes);
    }

    function testFuzz_ProposalSucceedsAfterFractionalVotes(uint256 _proposerIndex, uint256 _voterIndex) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _voterIndex = bound(_voterIndex, 0, _majorDelegates.length - 1);

        address _proposer = _majorDelegates[_proposerIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitProposal(_proposer, _proposal);

        uint256 _totalForVotes;
        for (uint256 i; i < _majorDelegates.length; i++) {
            address _delegate = _majorDelegates[i];
            uint256 _votes = governor.getVotes(_delegate, vm.getBlockNumber() - 1);
            uint256 _forVotes = _votes;
            uint256 _againstVotes = 0;
            uint256 _abstainVotes = 0;

            vm.prank(_delegate);
            bytes memory _params = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
            governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _params);
            _totalForVotes += _forVotes;
        }

        (uint256 _againstVotesCast, uint256 _forVotesCast, uint256 _abstainVotesCast) =
            governor.proposalVotes(_proposalId);
        assertEq(_forVotesCast, _totalForVotes);
        assertEq(_againstVotesCast, 0);
        assertEq(_abstainVotesCast, 0);

        vm.roll(vm.getBlockNumber() + governor.votingPeriod() + 1);
        assertEq(uint8(governor.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));
    }

    function testFuzz_ProposalFailsAfterFractionalVotes(uint256 _proposerIndex, uint256 _voterIndex) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _voterIndex = bound(_voterIndex, 0, _majorDelegates.length - 1);

        address _proposer = _majorDelegates[_proposerIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitProposal(_proposer, _proposal);

        uint256 _totalAgainstVotes;
        for (uint256 i; i < _majorDelegates.length; i++) {
            address _delegate = _majorDelegates[i];
            uint256 _votes = governor.getVotes(_delegate, vm.getBlockNumber() - 1);
            uint256 _forVotes = 0;
            uint256 _againstVotes = _votes;
            uint256 _abstainVotes = 0;

            vm.prank(_delegate);
            bytes memory _params = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
            governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _params);
            _totalAgainstVotes += _againstVotes;
        }

        (uint256 _againstVotesCast, uint256 _forVotesCast, uint256 _abstainVotesCast) =
            governor.proposalVotes(_proposalId);
        assertEq(_forVotesCast, 0);
        assertEq(_againstVotesCast, _totalAgainstVotes);
        assertEq(_abstainVotesCast, 0);

        vm.roll(vm.getBlockNumber() + governor.votingPeriod() + 1);
        assertEq(uint8(governor.state(_proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function testFuzz_RevertIf_VoteWeightGreaterThanTotalWeightViaFlexibleVoting(
        uint256 _proposerIndex,
        uint256 _voterIndex,
        uint256 _forVotes,
        uint256 _againstVotes,
        uint256 _abstainVotes,
        uint256 _sumOfVotes
    ) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _voterIndex = bound(_voterIndex, 0, _majorDelegates.length - 1);

        address _proposer = _majorDelegates[_proposerIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitProposal(_proposer, _proposal);

        address _delegate = _majorDelegates[_voterIndex];
        uint256 _votes = governor.getVotes(_delegate, vm.getBlockNumber() - 1);

        _sumOfVotes = bound(_sumOfVotes, _votes + 1, _votes * 2);
        _forVotes = bound(_forVotes, 0, _sumOfVotes);
        _againstVotes = bound(_againstVotes, 0, _sumOfVotes - _forVotes);
        _abstainVotes = _sumOfVotes - _forVotes - _againstVotes;

        bytes memory _params = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
        vm.expectRevert(
            abi.encodeWithSelector(
                GovernorCountingFractionalUpgradeable.GovernorExceedRemainingWeight.selector,
                _delegate,
                _sumOfVotes,
                _votes
            )
        );
        vm.prank(_delegate);
        governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _params);
    }

    function testFuzz_RevertIf_VotingWeightGreaterThanTwoVotesViaFlexibleVoting(
        uint256 _proposerIndex,
        uint256 _voterIndex,
        uint256 _firstVote,
        uint256 _secondVote,
        uint256 _forVotes,
        uint256 _againstVotes,
        uint256 _abstainVotes
    ) public {
        _proposerIndex = bound(_proposerIndex, 0, _majorDelegates.length - 1);
        _voterIndex = bound(_voterIndex, 0, _majorDelegates.length - 1);
        uint256 _proposalId;

        {
            address _proposer = _majorDelegates[_proposerIndex];
            Proposal memory _proposal = _buildAnEmptyProposal();
            _proposalId = _getProposalId(_proposal);
            _submitProposal(_proposer, _proposal);
        }

        address _delegate = _majorDelegates[_voterIndex];
        uint256 _votes = governor.getVotes(_delegate, vm.getBlockNumber() - 1);
        _firstVote = bound(_firstVote, 0, _votes - 1);
        _forVotes = bound(_forVotes, 0, _firstVote);
        _againstVotes = bound(_againstVotes, 0, _firstVote - _forVotes);
        _abstainVotes = bound(_abstainVotes, 0, _firstVote - _forVotes - _againstVotes);

        {
            vm.prank(_delegate);
            bytes memory _params = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
            governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _params);
        }

        // Second Vote
        uint256 _firstVoteTotal = _forVotes + _againstVotes + _abstainVotes;
        _secondVote = bound(_secondVote, _votes - _firstVoteTotal + 1, _votes * 2);
        _forVotes = bound(uint256(keccak256(abi.encode(_forVotes))), 0, _secondVote);
        _againstVotes = bound(uint256(keccak256(abi.encode(_againstVotes))), 0, _secondVote - _forVotes);
        _abstainVotes = _secondVote - _forVotes - _againstVotes;

        bytes memory _newParams = abi.encodePacked(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes));
        vm.prank(_delegate);
        vm.expectRevert(
            abi.encodeWithSelector(
                GovernorCountingFractionalUpgradeable.GovernorExceedRemainingWeight.selector,
                _delegate,
                _secondVote,
                _votes - _firstVoteTotal
            )
        );
        governor.castVoteWithReasonAndParams(_proposalId, VOTE_TYPE_FRACTIONAL, "MyReason", _newParams);
    }
}

contract CompoundGovernorCountingFractionalTest is
    CompoundGovernorTest,
    CountingMode,
    HasVoted,
    CastVoteWithReasonAndParams
{}
