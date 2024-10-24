// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";
import {CompoundGovernorConstants} from "script/CompoundGovernorConstants.sol";
import {DeployCompoundGovernor} from "script/DeployCompoundGovernor.s.sol";
import {GovernorBravoDelegate} from "contracts/GovernorBravoDelegate.sol";
import {IComp} from "contracts/interfaces/IComp.sol";
import {ProposeUpgradeBravoToCompoundGovernor} from "script/ProposeUpgradeBravoToCompoundGovernor.s.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {ProposalTest} from "contracts/test/helpers/ProposalTest.sol";

// The deployed CompooundGovernor address for testing upgradability
// TODO: for now, just a placeholder
address constant DEPLOYED_COMPOUND_GOVERNOR = 0x1111111111111111111111111111111111111111;

abstract contract BravoToCompoundGovernorUpgradeTest is ProposalTest {
    // IComp token = IComp(COMP_TOKEN_ADDRESS);
    // ICompoundTimelock timelock = ICompoundTimelock(TIMELOCK_ADDRESS);
    // CompoundGovernor governor;
    // address owner;
    // address whitelistGuardian;
    // CompoundGovernor.ProposalGuardian proposalGuardian;
    // uint96 constant PROPOSAL_GUARDIAN_EXPIRY = 1_739_768_400;

    // GovernorBravo to receive upgrade proposal
    address constant GOVERNOR_BRAVO_DELEGATE_ADDRESS = 0xc0Da02939E1441F497fd74F78cE7Decb17B66529;
    GovernorBravoDelegate public constant GOVERNOR_BRAVO = GovernorBravoDelegate(GOVERNOR_BRAVO_DELEGATE_ADDRESS);

    // function _doCompoundGovernorDeploy(
    //     address _whitelistGuardian,
    //     CompoundGovernor.ProposalGuardian memory _proposalGuardian
    // ) internal returns (CompoundGovernor _governor) {
    //     // set the owner of the governor (use the anvil default account #0, if no environment variable is set)
    //     owner = vm.envOr("DEPLOYER_ADDRESS", 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    //     // Deploy the CompoundGovernor contract
    //     DeployCompoundGovernor _deployer = new DeployCompoundGovernor();
    //     _deployer.setUp();
    //     _governor = _deployer.run(owner, _whitelistGuardian, _proposalGuardian);
    // }

    function _getBravoProposalStartBlock(uint256 _bravoProposalId) internal view returns (uint256) {
        (,,, uint256 _startBlock,,,,,,) = GOVERNOR_BRAVO.proposals(_bravoProposalId);
        return _startBlock;
    }

    function _getBravoProposalEndBlock(uint256 _bravoProposalId) internal view returns (uint256) {
        (,,,, uint256 _endBlock,,,,,) = GOVERNOR_BRAVO.proposals(_bravoProposalId);
        return _endBlock;
    }

    function _jumpToActiveBravoProposal(uint256 _bravoProposalId) internal {
        vm.roll(_getBravoProposalStartBlock(_bravoProposalId) + 1);
    }

    function _jumpToBravoVoteComplete(uint256 _bravoProposalId) internal {
        vm.roll(_getBravoProposalEndBlock(_bravoProposalId) + 1);
    }

    function _delegatesVoteOnBravoProposal(uint256 _bravoProposalId, GovernorCountingSimple.VoteType _support)
        internal
    {
        for (uint256 _index = 0; _index < _majorDelegates.length; _index++) {
            vm.prank(_majorDelegates[_index]);
            GOVERNOR_BRAVO.castVote(_bravoProposalId, uint8(_support));
        }
    }

    function _getBravoProposalEta(uint256 _bravoProposalId) internal view returns (uint256) {
        (,, uint256 _eta,,,,,,,) = GOVERNOR_BRAVO.proposals(_bravoProposalId);
        return _eta;
    }

    function _jumpPastBravoProposalEta(uint256 _bravoProposalId) internal {
        vm.roll(vm.getBlockNumber() + 1); // move up one block so we're not in the same block as when
        // queued
        vm.warp(_getBravoProposalEta(_bravoProposalId) + 1); // jump past the eta timestamp
    }

    function _passBravoProposal(uint256 _bravoProposalId) internal {
        _jumpToActiveBravoProposal(_bravoProposalId);
        _delegatesVoteOnBravoProposal(_bravoProposalId, GovernorCountingSimple.VoteType.For);
        _jumpToBravoVoteComplete(_bravoProposalId);
    }

    function _failBravoProposal(uint256 _bravoProposalId) internal {
        _jumpToActiveBravoProposal(_bravoProposalId);
        _delegatesVoteOnBravoProposal(_bravoProposalId, GovernorCountingSimple.VoteType.Against);
        _jumpToBravoVoteComplete(_bravoProposalId);
    }

    function _passAndQueueBravoProposal(uint256 _bravoProposalId) internal {
        _passBravoProposal(_bravoProposalId);
        GOVERNOR_BRAVO.queue(_bravoProposalId);
    }

    function _passQueueAndExecuteBravoProposal(uint256 _bravoProposalId) internal {
        _passAndQueueBravoProposal(_bravoProposalId);
        _jumpPastBravoProposalEta(_bravoProposalId);
        GOVERNOR_BRAVO.execute(_bravoProposalId);
    }

    function _upgradeFromBravoToCompoundGovernorViaProposalVote() internal {
        // Create the proposal to upgrade the Bravo governor to the CompoundGovernor
        ProposeUpgradeBravoToCompoundGovernor _proposeUpgrade = new ProposeUpgradeBravoToCompoundGovernor();
        uint256 _upgradeProposalId = _proposeUpgrade.run(governor);

        // Pass, queue, and execute the proposal
        _passQueueAndExecuteBravoProposal(_upgradeProposalId);
    }

    function _failProposalVoteForUpgradeFromBravoToCompoundGovernor() internal {
        // Create the proposal to upgrade the Bravo governor to the CompoundGovernor
        ProposeUpgradeBravoToCompoundGovernor _proposeUpgrade = new ProposeUpgradeBravoToCompoundGovernor();
        uint256 _upgradeProposalId = _proposeUpgrade.run(governor);

        // Pass, queue, and execute the proposal
        _failBravoProposal(_upgradeProposalId);
    }

    function _updateTimelockAdminToOldGovernor() internal {
        address _timelockAddress = governor.timelock();
        ICompoundTimelock _timelock = ICompoundTimelock(payable(_timelockAddress));
        vm.prank(_timelockAddress);
        _timelock.setPendingAdmin(GOVERNOR_BRAVO_DELEGATE_ADDRESS);
        vm.prank(address(GOVERNOR_BRAVO_DELEGATE_ADDRESS));
        _timelock.acceptAdmin();
    }

    function setUp() public virtual override {
        if (_useDeployedCompoundGovernor()) {
            // After the CompoundGovernor is deployed, the actual deployed contract can be tested.
            // create a local execution fork for testing
            vm.createSelectFork(vm.envOr("RPC_URL", string("Please set RPC_URL in your .env file")), FORK_BLOCK);

            // Set the governor to be the deployed CompoundGovernor
            governor = CompoundGovernor(payable(DEPLOYED_COMPOUND_GOVERNOR));
            owner = governor.owner();
            whitelistGuardian = governor.whitelistGuardian();
            (proposalGuardian.account, proposalGuardian.expiration) = governor.proposalGuardian();
        } else {
            // Before a CompoundGovernor is deployed, the test setup will deploy the governor.
            super.setUp();

            // restore the timelock admin to the old governor for upgrade testing
            _updateTimelockAdminToOldGovernor();
        }
        vm.label(GOVERNOR_BRAVO_DELEGATE_ADDRESS, "GovernorBravoDelegate");
        vm.label(owner, "Owner");
        vm.label(address(governor), "CompoundGovernor");
        vm.label(address(timelock), "Timelock");
        vm.label(COMP_TOKEN_ADDRESS, "CompToken");
    }

    function _useDeployedCompoundGovernor() internal virtual returns (bool);

    function test_UpgradeToCompoundGovernor() public {
        _upgradeFromBravoToCompoundGovernorViaProposalVote();
        assertEq(timelock.admin(), address(governor));
    }

    function test_FailUpgradeToCompoundGovernor() public {
        _failProposalVoteForUpgradeFromBravoToCompoundGovernor();
        assertEq(timelock.admin(), GOVERNOR_BRAVO_DELEGATE_ADDRESS);
    }
}
