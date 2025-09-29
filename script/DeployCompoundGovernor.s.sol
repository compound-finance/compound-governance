// SPDX-License-Identifier: BSD-3-Clause
// slither-disable-start reentrancy-benign

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IComp} from "contracts/interfaces/IComp.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {CompoundGovernor} from "contracts/CompoundGovernor.sol";
import {CompoundGovernorConstants} from "script/CompoundGovernorConstants.sol";

// Deploy script for the underlying implementation that will be used by both Governor proxies
contract DeployCompoundGovernor is Script, CompoundGovernorConstants {
    uint256 deployerPrivateKey;

    function setUp() public virtual {
        // private key of the deployer (use the anvil default account #0 key, if no environment variable is set)
        deployerPrivateKey = vm.envOr(
            "DEPLOYER_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );
    }

    function run(address _whitelistGuardian, CompoundGovernor.ProposalGuardian memory _proposalGuardian)
        public
        returns (CompoundGovernor _governor)
    {
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Governor implementation contract
        CompoundGovernor _implementation = new CompoundGovernor();

        bytes memory _initData = abi.encodeCall(
            CompoundGovernor.initialize,
            (
                INITIAL_VOTING_DELAY,
                INITIAL_VOTING_PERIOD,
                INITIAL_PROPOSAL_THRESHOLD,
                IComp(COMP_TOKEN_ADDRESS),
                INITIAL_QUORUM,
                ICompoundTimelock(TIMELOCK_ADDRESS),
                INITIAL_VOTE_EXTENSION,
                _whitelistGuardian,
                _proposalGuardian
            )
        );
        TransparentUpgradeableProxy _proxy =
            new TransparentUpgradeableProxy(address(_implementation), TIMELOCK_ADDRESS, _initData);
        _governor = CompoundGovernor(payable(address(_proxy)));

        vm.stopBroadcast();
    }
}
