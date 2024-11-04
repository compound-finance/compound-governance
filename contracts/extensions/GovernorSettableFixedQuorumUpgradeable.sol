// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {GovernorUpgradeable} from "contracts/extensions/GovernorUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/// @title GovernorSettableFixedQuorumUpdateable
/// @author [ScopeLift](https://scopelift.co)
/// @notice An abstract extension to the Governor which implements a fixed quorum which can be updated by governance.
/// @custom:security-contact security@compound.finance
abstract contract GovernorSettableFixedQuorumUpgradeable is Initializable, GovernorUpgradeable {
    using Checkpoints for Checkpoints.Trace208;

    /// @custom:storage-location erc7201:openzeppelin.storage.GovernorSettableFixedQuorum
    struct GovernorSettableFixedQuorumStorage {
        Checkpoints.Trace208 _quorumCheckpoints;
    }

    // keccak256(abi.encode(uint256(keccak256("storage.GovernorSettableFixedQuorum")) - 1)) &
    // ~bytes32(uint256(0xff))
    bytes32 private constant GovernorSettableFixedQuorumStorageLocation =
        0xfc13b0622f15c0c6558fbb10a1f5d36853f903c871b669bae7001d348b50ca00;

    function _getGovernorSettableFixedQuorumStorage()
        private
        pure
        returns (GovernorSettableFixedQuorumStorage storage $)
    {
        assembly {
            $.slot := GovernorSettableFixedQuorumStorageLocation
        }
    }

    /// @notice Emitted when the quorum value has changed.
    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);

    function __GovernorSettableFixedQuorum_init(uint256 _initialQuorum) internal onlyInitializing {
        __GovernorSettableFixedQuorum_init_unchained(_initialQuorum);
    }

    function __GovernorSettableFixedQuorum_init_unchained(uint256 _initialQuorum) internal onlyInitializing {
        _setQuorum(_initialQuorum);
    }

    /// @notice A function to set quorum for the current timepoint. Proposals created after this timepoint will be
    /// subject to the new quorum.
    /// @param _amount The new quorum threshold.
    function setQuorum(uint256 _amount) external virtual onlyGovernance {
        _setQuorum(_amount);
    }

    /// @notice A function to get the quorum threshold for a given timepoint.
    /// @param _voteStart The vote start timepoint for a given proposal.
    function quorum(uint256 _voteStart) public view virtual override returns (uint256) {
        GovernorSettableFixedQuorumStorage storage $ = _getGovernorSettableFixedQuorumStorage();
        return $._quorumCheckpoints.upperLookupRecent(SafeCast.toUint32(_voteStart));
    }

    /// @notice A function to set quorum for the current timepoint.
    /// @param _amount The quorum amount to checkpoint.
    function _setQuorum(uint256 _amount) internal virtual {
        uint48 _timepoint = clock();
        GovernorSettableFixedQuorumStorage storage $ = _getGovernorSettableFixedQuorumStorage();
        emit QuorumUpdated(quorum(_timepoint), _amount);
        $._quorumCheckpoints.push(_timepoint, SafeCast.toUint208(_amount));
    }
}
