// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.26;

import {CompoundGovernorTest} from "contracts/test/helpers/CompoundGovernorTest.sol";
import {IGovernor} from "contracts/extensions/IGovernor.sol";
import {GovernorAlphaInterface} from "contracts/GovernorBravoInterfaces.sol";

/// @notice Most governance operations that take a proposal ID parameter (queue, execute, cancel)
/// are extensively tested in CompoundGovernor.t.sol. This test file focuses on the rest of the functionalities.
contract GovernorSequentialProposalIdUpgradeableTest is CompoundGovernorTest {
    GovernorAlphaInterface internal constant compoundGovernorBravo =
        GovernorAlphaInterface(0xc0Da02939E1441F497fd74F78cE7Decb17B66529);

    function _buildBasicProposal(uint256 _newThreshold, string memory _description)
        internal
        view
        returns (Proposal memory _proposal)
    {
        address[] memory _targets = new address[](1);
        _targets[0] = address(governor);

        uint256[] memory _values = new uint256[](1);
        _values[0] = 0;

        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = _buildProposalData("setProposalThreshold(uint256)", abi.encode(_newThreshold));
        _proposal = Proposal(_targets, _values, _calldatas, _description);
    }
}

contract ProposalCount is GovernorSequentialProposalIdUpgradeableTest {
    function test_ReturnsCorrectProposalCount() public {
        assertEq(governor.proposalCount(), compoundGovernorBravo.proposalCount() + 1);
    }

    function testFuzz_ProposalCreatedEventEmittedWithEnumeratedProposalId(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        address _proposer = _getRandomProposer();
        string memory _description = "Checking for enumearted proposal IDs on events";
        Proposal memory _firstProposal = _buildBasicProposal(_newValue, "First proposal to get and ID");
        uint256 _firstProposalId = _submitProposal(_proposer, _firstProposal);
        uint256 _originalProposalCount = governor.proposalCount();
        Proposal memory _proposal = _buildBasicProposal(_newValue, _description);
        vm.expectEmit();
        emit IGovernor.ProposalCreated(
            _firstProposalId + 1,
            _proposer,
            _proposal.targets,
            _proposal.values,
            new string[](_proposal.targets.length),
            _proposal.calldatas,
            block.number + INITIAL_VOTING_DELAY,
            block.number + INITIAL_VOTING_DELAY + INITIAL_VOTING_PERIOD,
            _description
        );
        uint256 _proposalId = _submitProposal(_proposer, _proposal);
        assertEq(_proposalId, _firstProposalId + 1);
        assertEq(governor.proposalCount(), _originalProposalCount + 1);
    }

    function testFuzz_ProposalIdsAreSequential(uint256 _newValue) public {
        _newValue = bound(_newValue, INITIAL_PROPOSAL_THRESHOLD, INITIAL_PROPOSAL_THRESHOLD + 10);
        Proposal memory _proposal1 = _buildBasicProposal(_newValue, "Set New Proposal Threshold");
        uint256 _proposalId1 = _submitProposal(_proposal1);
        Proposal memory _proposal2 = _buildBasicProposal(_newValue + 1, "Second Proposal");
        uint256 _proposalId2 = _submitProposal(_proposal2);
        assertEq(_proposalId2, _proposalId1 + 1);
    }
}

contract GetNextProposalId is GovernorSequentialProposalIdUpgradeableTest {
    function testFuzz_ReturnsCorrectNextProposalId(uint256) public {
        uint256 _nextProposalId = governor.getNextProposalId();
        assertEq(_nextProposalId, compoundGovernorBravo.proposalCount() + 1);
        assertTrue(_nextProposalId > 0);
    }
}

contract HashProposal is GovernorSequentialProposalIdUpgradeableTest {
    function testFuzz_ReturnsCorrectProposalId() public {
        address[] memory _targets = new address[](1);
        uint256[] memory _values = new uint256[](1);
        bytes[] memory _calldatas = new bytes[](1);
        bytes32 _descriptionHash = keccak256(bytes("An Empty Proposal"));

        uint256 _proposalId = governor.hashProposal(_targets, _values, _calldatas, _descriptionHash);
        assertEq(_proposalId, governor.getNextProposalId());
        assertTrue(_proposalId > 0);
    }
}

contract ProposalDetails is GovernorSequentialProposalIdUpgradeableTest {
    function testFuzz_ReturnsCorrectProposalDetails(
        address _expectedTarget,
        uint256 _expectedValue,
        bytes memory _expectedCalldatas,
        string memory _expectedDescription
    ) public {
        address[] memory _targets = new address[](1);
        _targets[0] = _expectedTarget;
        uint256[] memory _values = new uint256[](1);
        _values[0] = _expectedValue;
        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = _expectedCalldatas;

        Proposal memory _proposal = Proposal(_targets, _values, _calldatas, _expectedDescription);
        uint256 _proposalId = _submitProposal(_proposal);

        (
            address[] memory _returnedTargets,
            uint256[] memory _returnedValues,
            bytes[] memory _returnedCalldatas,
            bytes32 _returnedDescriptionHash
        ) = governor.proposalDetails(_proposalId);

        assertEq(_returnedTargets[0], _expectedTarget);
        assertEq(_returnedValues[0], _expectedValue);
        assertEq(_returnedCalldatas[0], _expectedCalldatas);
        assertEq(keccak256(bytes(_expectedDescription)), _returnedDescriptionHash);
    }
}
