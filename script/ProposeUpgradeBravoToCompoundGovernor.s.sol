// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockCompound.sol";

import {CompoundGovernor} from "contracts/CompoundGovernor.sol";
import {CompoundGovernorConstants} from "script/CompoundGovernorConstants.sol";
import {GovernorBravoDelegate} from "contracts/GovernorBravoDelegate.sol";

/// @notice Script to submit the proposal to upgrade from GovernorBravo to  CompoundGovernor.
contract ProposeUpgradeBravoToCompoundGovernor is Script, CompoundGovernorConstants {
    GovernorBravoDelegate public constant GOVERNOR_BRAVO = GovernorBravoDelegate(GOVERNOR_BRAVO_DELEGATE_ADDRESS);

    function propose(CompoundGovernor _newGovernor) internal returns (uint256 _proposalId) {
        address[] memory _targets = new address[](3);
        uint256[] memory _values = new uint256[](3);
        string[] memory _signatures = new string[](3);
        bytes[] memory _calldatas = new bytes[](3);

        _targets[0] = address(_newGovernor);
        _values[0] = 0;
        _signatures[0] = "setNextProposalId()";
        _calldatas[0] = "";

        _targets[1] = _newGovernor.timelock();
        _values[1] = 0;
        _signatures[1] = "setPendingAdmin(address)";
        _calldatas[1] = abi.encode(address(_newGovernor));

        _targets[2] = address(_newGovernor);
        _values[2] = 0;
        _signatures[2] = "__acceptAdmin()";
        _calldatas[2] = "";

        return GOVERNOR_BRAVO.propose(
            _targets,
            _values,
            _signatures,
            _calldatas,
            "This proposal will upgrade Compound's GovernorBravoDelegator and GovernorBravoDelegate contracts. We'll use the latest contracts from OpenZeppelin(OZ) library with some modifications to preserve many of the existing features of the Governors including:\n\nEnumerable Proposal IDs: Unlike out of the box OZ governors, where proposalIds are calculated from hashing the contents of a proposal, we will keep the incrementing proposalId pattern of Governor Bravo. To implement this, we will use the GovernorStorage extension with some modifications to incorporate enumerability of proposalIds.\n\nProposal Guardian, Whitelist Guardian, and whitelisted proposers: Current Governor Bravo's flow of cancelling a proposal will be preserved. The DAO will have control over the management of the roles mentioned above.\n\nThe upgrade comes with a number of advantages outlined in the original upgrade proposal 5 and also additional benefits such as:\n\nUpdatable Governor Settings: Proposal threshold, Voting Delay, and Voting Period will be adjustable through the governance process without min and max bounds.\n\nUpdatable Quorum: The DAO will also be able to set the quorum, which will be a non-fractional, updatable value using a simple, customized extension contract.\n\nExtended quorum when it is reached late: As a way to help protect against various Governance attacks, we will implement OZ's extension that automatically extends quorum if it is reached late in the voting cycle.\n\nNo Limits: There will be no limits on the number of operations a proposal can have.\n\nFlexible Voting: Flexible Voting is an extension to the OZ Governor developed by ScopeLift. It allows for the integration of novel voting schemes without changing or compromising the core security model of the DAO. Examples include voting with tokens while earning yield in DeFi, cross chain voting, shielded voting, and more. Flexible Voting is supported by Tally. It's been audited and is now an OZ governor extension.\n\nUpgradeability: We will use the upgradeable versions of the OZ contracts, and any future upgrades can be done through the upgradeable proxy functionality."
        );
    }

    /// @dev After the new Governor is deployed on mainnet, `_newGovernor` can become a const
    function run(CompoundGovernor _newGovernor) public returns (uint256 _proposalId) {
        // The expectation is the key loaded here corresponds to the address of the `proposer` above.
        // When running as a script, broadcast will fail if the key is not correct.
        // These default addresses are the anvils default account #0, if no environment variable is set, meant just for
        // testing.
        uint256 _proposerKey = vm.envOr(
            "PROPOSER_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );
        address _proposerAddress = vm.envOr("PROPOSER_ADDRESS", _majorDelegates[0]);
        vm.rememberKey(_proposerKey);

        vm.startBroadcast(_proposerAddress);
        _proposalId = propose(_newGovernor);
        vm.stopBroadcast();
        return _proposalId;
    }
}
