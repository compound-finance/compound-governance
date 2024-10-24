// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockCompound.sol";

import {CompoundGovernor} from "contracts/CompoundGovernor.sol";
import {CompoundGovernorConstants} from "script/CompoundGovernorConstants.sol";
import {GovernorBravoDelegate} from "contracts/GovernorBravoDelegate.sol";

/// @notice Script to submit the proposal to upgrade from GovernorBravo to  CompoundGovernor.
contract ProposeUpgradeBravoToCompoundGovernor is Script, CompoundGovernorConstants {
    // GovernorBravo to receive upgrade proposal
    address constant GOVERNOR_BRAVO_DELEGATE_ADDRESS = 0xc0Da02939E1441F497fd74F78cE7Decb17B66529;

    GovernorBravoDelegate public constant GOVERNOR_BRAVO = GovernorBravoDelegate(GOVERNOR_BRAVO_DELEGATE_ADDRESS);

    function propose(CompoundGovernor _newGovernor) internal returns (uint256 _proposalId) {
        address[] memory _targets = new address[](2);
        uint256[] memory _values = new uint256[](2);
        string[] memory _signatures = new string[](2);
        bytes[] memory _calldatas = new bytes[](2);

        _targets[0] = _newGovernor.timelock();
        _values[0] = 0;
        _signatures[0] = "setPendingAdmin(address)";
        _calldatas[0] = abi.encode(address(_newGovernor));

        _targets[1] = address(_newGovernor);
        _values[1] = 0;
        _signatures[1] = "__acceptAdmin()";
        _calldatas[1] = "";

        return GOVERNOR_BRAVO.propose(
            _targets, _values, _signatures, _calldatas, "Upgrade GovernorBravo to CompoundGovernor"
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
