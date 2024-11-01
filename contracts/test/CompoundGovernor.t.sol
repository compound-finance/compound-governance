// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {CompoundGovernorTest} from "contracts/test/helpers/CompoundGovernorTest.sol";
import {IGovernor} from "contracts/extensions/IGovernor.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";
import {GovernorCountingFractionalUpgradeable} from "contracts/CompoundGovernor.sol";

contract Initialize is CompoundGovernorTest {
    function test_Initialize() public view {
        assertEq(governor.quorum(governor.clock()), INITIAL_QUORUM);
        assertEq(governor.votingPeriod(), INITIAL_VOTING_PERIOD);
        assertEq(governor.votingDelay(), INITIAL_VOTING_DELAY);
        assertEq(governor.proposalThreshold(), INITIAL_PROPOSAL_THRESHOLD);
        assertEq(governor.lateQuorumVoteExtension(), INITIAL_VOTE_EXTENSION);
        assertEq(address(governor.timelock()), TIMELOCK_ADDRESS);
        assertEq(address(governor.token()), COMP_TOKEN_ADDRESS);
        assertEq(governor.whitelistGuardian(), whitelistGuardian);
        (address _proposalGuardian, uint96 _expiration) = governor.proposalGuardian();
        assertEq(_proposalGuardian, proposalGuardian.account);
        assertEq(_expiration, proposalGuardian.expiration);
    }
}

contract SetQuorum is CompoundGovernorTest {
    function _buildSetQuorumProposal(uint256 _amount) private view returns (Proposal memory _proposal) {
        address[] memory _targets = new address[](1);
        _targets[0] = address(governor);

        uint256[] memory _values = new uint256[](1);
        _values[0] = 0;

        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = _buildProposalData("setQuorum(uint256)", abi.encode(_amount));

        _proposal = Proposal(_targets, _values, _calldatas, "Set New Quorum");
    }

    function testFuzz_SetsQuorum(uint256 _newQuorum) public {
        _newQuorum = bound(_newQuorum, 1, INITIAL_QUORUM * 10);
        Proposal memory _proposal = _buildSetQuorumProposal(_newQuorum);
        _submitPassQueueAndExecuteProposal(_getRandomProposer(), _proposal);
        assertEq(governor.quorum(block.timestamp), _newQuorum);
    }

    function testFuzz_DoesNotUpdateWhenProposalFails(uint256 _newQuorum) public {
        vm.assume(_newQuorum != INITIAL_QUORUM);
        _newQuorum = bound(_newQuorum, 1, INITIAL_QUORUM * 10);
        Proposal memory _proposal = _buildSetQuorumProposal(_newQuorum);
        _submitAndFailProposal(_getRandomProposer(), _proposal);
        assertEq(governor.quorum(block.timestamp), INITIAL_QUORUM);
    }

    function testFuzz_RevertIf_CalledByNonTimelock(address _caller, uint256 _newQuorum) public {
        vm.assume(_caller != address(timelock));
        vm.assume(_caller != PROXY_ADMIN_ADDRESS);
        vm.prank(_caller);
        _newQuorum = bound(_newQuorum, 1, INITIAL_QUORUM * 10);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorOnlyExecutor.selector, _caller));
        governor.setQuorum(_newQuorum);
    }
}

contract Cancel is CompoundGovernorTest {
    function _setWhitelistedProposer(address _proposer) private {
        vm.prank(whitelistGuardian);
        governor.setWhitelistAccountExpiration(_proposer, block.timestamp + 2_000_000);
    }

    function _removeDelegateeVotingWeight(address _proposer) private {
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.getPriorVotes.selector, _proposer, block.number - 1),
            abi.encode(0) // Return 0 as the new voting weight
        );
    }

    function testFuzz_ProposerCanCancelItsOwnProposal(uint256 _randomIndex) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitPassAndQueueProposal(_proposer, _proposal);

        vm.prank(_proposer);
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
        vm.assertEq(uint256(governor.state(_proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testFuzz_ProposalGuardianCanCancelAnyProposal(uint256 _randomIndex) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitPassAndQueueProposal(_proposer, _proposal);

        vm.prank(proposalGuardian.account);
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
        vm.assertEq(uint256(governor.state(_proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testFuzz_AnyoneCanCancelAProposalBelowThreshold(address _caller, uint256 _randomIndex) public {
        vm.assume(_caller != PROXY_ADMIN_ADDRESS);
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _submitPassAndQueueProposal(_proposer, _proposal);
        _removeDelegateeVotingWeight(_proposer);

        vm.prank(_caller);
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
        vm.assertEq(uint256(governor.state(_proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testFuzz_WhitelistGuardianCanCancelWhitelistedProposalBelowThreshold(uint256 _randomIndex) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        Proposal memory _proposal = _buildAnEmptyProposal();
        uint256 _proposalId = _getProposalId(_proposal);
        _setWhitelistedProposer(_proposer);
        _submitPassAndQueueProposal(_proposer, _proposal);
        _removeDelegateeVotingWeight(_proposer);

        vm.prank(whitelistGuardian);
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
        vm.assertEq(uint256(governor.state(_proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testFuzz_RevertIf_NonProposerOrGuardianCancelsProposalAboveThreshold(address _caller, uint256 _randomIndex)
        public
    {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        vm.assume(_caller != proposalGuardian.account && _caller != _proposer && _caller != PROXY_ADMIN_ADDRESS);
        Proposal memory _proposal = _buildAnEmptyProposal();
        _submitPassAndQueueProposal(_proposer, _proposal);

        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                CompoundGovernor.Unauthorized.selector, bytes32("Proposer above proposalThreshold"), _caller
            )
        );
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function testFuzz_RevertIf_NonWhitelistGuardianCancelsWhitelistedProposalBelowThreshold(
        address _caller,
        uint256 _randomIndex
    ) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        vm.assume(
            _caller != whitelistGuardian && _caller != _proposer && _caller != proposalGuardian.account
                && _caller != PROXY_ADMIN_ADDRESS
        );

        Proposal memory _proposal = _buildAnEmptyProposal();
        _setWhitelistedProposer(_proposer);
        _submitPassAndQueueProposal(_proposer, _proposal);
        _removeDelegateeVotingWeight(_proposer);

        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSelector(CompoundGovernor.Unauthorized.selector, bytes32("Not whitelistGuardian"), _caller)
        );
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function testFuzz_RevertIf_NonProposerOrGuardianCancelsWhitelistedProposalAboveThreshold(
        address _caller,
        uint256 _randomIndex
    ) public {
        _randomIndex = bound(_randomIndex, 0, _majorDelegates.length - 1);
        address _proposer = _majorDelegates[_randomIndex];
        vm.assume(_caller != _proposer && _caller != proposalGuardian.account && _caller != PROXY_ADMIN_ADDRESS);
        Proposal memory _proposal = _buildAnEmptyProposal();
        vm.prank(whitelistGuardian);
        governor.setWhitelistAccountExpiration(_proposer, block.timestamp + 2_000_000);
        vm.assertTrue(governor.isWhitelisted(_proposer));

        _submitPassAndQueueProposal(_proposer, _proposal);

        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                CompoundGovernor.Unauthorized.selector, bytes32("Proposer above proposalThreshold"), _caller
            )
        );
        governor.cancel(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }
}

contract IsWhitelisted is CompoundGovernorTest {
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

contract SetProposalGuardian is CompoundGovernorTest {
    function _buildSetProposalGuardianProposal(CompoundGovernor.ProposalGuardian memory _proposalGuardian)
        private
        view
        returns (Proposal memory _proposal)
    {
        address[] memory _targets = new address[](1);
        _targets[0] = address(governor);

        uint256[] memory _values = new uint256[](1);
        _values[0] = 0;

        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = abi.encodeWithSelector(CompoundGovernor.setProposalGuardian.selector, _proposalGuardian);

        _proposal = Proposal(_targets, _values, _calldatas, "Set New proposalGuardian");
    }

    function testFuzz_SetsProposalGuardianAsTimelock(CompoundGovernor.ProposalGuardian memory _proposalGuardian)
        public
    {
        Proposal memory _proposal = _buildSetProposalGuardianProposal(_proposalGuardian);
        _submitPassQueueAndExecuteProposal(_getRandomProposer(), _proposal);
        (address _account, uint96 _expiration) = governor.proposalGuardian();
        assertEq(_account, _proposalGuardian.account);
        assertEq(_expiration, _proposalGuardian.expiration);
    }

    function testFuzz_EmitsEventWhenAProposalGuardianIsSetByTheTimelock(
        CompoundGovernor.ProposalGuardian memory _proposalGuardian,
        address _caller
    ) public {
        vm.assume(_caller != PROXY_ADMIN_ADDRESS);
        (address _currentAccount, uint96 _currentExpiration) = governor.proposalGuardian();
        Proposal memory _proposal = _buildSetProposalGuardianProposal(_proposalGuardian);
        _submitPassAndQueueProposal(_getRandomProposer(), _proposal);

        vm.expectEmit();
        emit CompoundGovernor.ProposalGuardianSet(
            _currentAccount, _currentExpiration, _proposalGuardian.account, _proposalGuardian.expiration
        );

        vm.prank(_caller);
        governor.execute(
            _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
        );
    }

    function testFuzz_RevertIf_CallerIsNotTimelock(
        CompoundGovernor.ProposalGuardian memory _proposalGuardian,
        address _caller
    ) public {
        vm.assume(_caller != TIMELOCK_ADDRESS && _caller != PROXY_ADMIN_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorOnlyExecutor.selector, _caller));
        vm.prank(_caller);
        governor.setProposalGuardian(_proposalGuardian);
    }
}

contract SetWhitelistAccountExpiration is CompoundGovernorTest {
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

contract CompoundGovernorSetWhitelistGuardianTest is CompoundGovernorTest {
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
        _submitPassQueueAndExecuteProposal(_getRandomProposer(), _proposal);
        assertEq(governor.whitelistGuardian(), _whitelistGuardian);
    }

    function testFuzz_EmitsEventWhenAWhitelistGuardianIsSet(address _whitelistGuardian, address _caller) public {
        vm.assume(_caller != PROXY_ADMIN_ADDRESS);
        Proposal memory _proposal = _buildSetWhitelistGuardianProposal(_whitelistGuardian);
        _submitPassAndQueueProposal(_getRandomProposer(), _proposal);

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

contract CountingMode is CompoundGovernorTest {
    function testFuzz_ReturnsCorrectCountingMode() public view {
        assertEq(governor.COUNTING_MODE(), "support=bravo,fractional&quorum=for,abstain&params=fractional");
    }
}

contract HasVoted is CompoundGovernorTest {
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

contract UsedVotes is CompoundGovernorTest {
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

contract CastVoteWithReasonAndParams is CompoundGovernorTest {
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
