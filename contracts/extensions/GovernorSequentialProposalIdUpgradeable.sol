// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {GovernorUpgradeable} from "contracts/extensions/GovernorUpgradeable.sol";

abstract contract GovernorSequentialProposalIdUpgradeable is GovernorUpgradeable {
    
    error ProposalIdAlreadySet();

    /// @dev Storage structure to store proposal details.
    struct ProposalDetails {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        bytes32 descriptionHash;
    }

    struct GovernorSequentialProposalIdStorage {
        /// @notice The next proposal ID to assign to a proposal.
        uint256 _nextProposalId;
        /// @notice A mapping for proposal IDs, indexed via the hash of the proposal.
        mapping(uint256 proposalHash => uint256 proposalId) _proposalIds;
        /// @notice A mapping for proposal details, indexed via sequential Proposal IDs.
        mapping(uint256 proposalId => ProposalDetails) _proposalDetails;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.GovernorSequentialProposalIdStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant GovernorSequentialProposalIdStorageLocation = 0xa6952339bc887ea688c6b8e8399bb953a5002ee79177d6322fca98dc89ae0b00;

    function _getGovernorSequentialProposalIdStorage() private pure returns (GovernorSequentialProposalIdStorage storage $) {
        assembly {
            $.slot := GovernorSequentialProposalIdStorageLocation
        }
    }

    function __GovernorSequentialProposalId_init() internal onlyInitializing {
        __GovernorSequentialProposalId_init_unchained();
    }

    function __GovernorSequentialProposalId_init_unchained() internal onlyInitializing {
        GovernorSequentialProposalIdStorage storage $ = _getGovernorSequentialProposalIdStorage();
        $._nextProposalId = type(uint).max;
    }

    function hashProposal(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) public virtual override returns (uint256) {
        uint256 _proposalHash = super.hashProposal(_targets, _values, _calldatas, _descriptionHash);
        GovernorSequentialProposalIdStorage storage $ = _getGovernorSequentialProposalIdStorage();
        uint256 _storedProposalId = $._proposalIds[_proposalHash];
        if (_storedProposalId == 0) {
            _storedProposalId = $._nextProposalId;
        }
        return _storedProposalId;
    }

    function getNextProposalId() public view returns (uint256) {
        GovernorSequentialProposalIdStorage storage $ = _getGovernorSequentialProposalIdStorage();
        return $._nextProposalId;
    }

    function _setNextProposalId(uint256 _proposalId) internal virtual {
        GovernorSequentialProposalIdStorage storage $ = _getGovernorSequentialProposalIdStorage();
        if ($._nextProposalId != type(uint256).max) {
            revert ProposalIdAlreadySet();
        }
        $._nextProposalId = _proposalId;
    }

     function _propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description,
        address _proposer
    ) internal virtual override returns (uint256) {
       GovernorSequentialProposalIdStorage storage $ = _getGovernorSequentialProposalIdStorage();
        uint256 _proposalId = super._propose(_targets, _values, _calldatas, _description,_proposer);
        bytes32 _descriptionHash = keccak256(bytes(_description));
        uint256 _proposalHash = super.hashProposal(_targets, _values, _calldatas, _descriptionHash);

        $._proposalIds[_proposalHash] = _proposalId;
        $._proposalDetails[_proposalId] = ProposalDetails({
            targets: _targets,
            values: _values,
            calldatas: _calldatas,
            descriptionHash: _descriptionHash
        });
        $._nextProposalId++;
        return _proposalId;
    }

    /// @notice Version of {IGovernor-queue} with only enumerated `proposalId` as an argument.
    /// @param _proposalId The enumerated proposal ID.
    /// @dev Uses the externally-used enumerated proposal ID to find the proposal details
    /// needed by the GovernorUpgradeable queue function.
    function queue(uint256 _proposalId) public virtual {
        (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas, bytes32 _descriptionHash) =
            proposalDetails(_proposalId);
        GovernorUpgradeable.queue(_targets, _values, _calldatas, _descriptionHash);
    }

    /// @notice Version of {IGovernor-execute} with only enumerated `proposalId` as an argument.
    /// @param _proposalId The enumerated proposal ID.
    /// @dev Uses the externally-used enumerated proposal ID to find the proposal details
    /// needed by the GovernorUpgradeable execute function.
    function execute(uint256 _proposalId) public payable virtual {
        (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas, bytes32 _descriptionHash) =
            proposalDetails(_proposalId);
        GovernorUpgradeable.execute(_targets, _values, _calldatas, _descriptionHash);
    }

    /// @notice Version of {IGovernor-cancel} with only enumerated `proposalId` as an argument.
    /// @param _proposalId The enumerated proposal ID.
    /// @dev Uses the externally-used enumerated proposal ID to find the proposal details
    /// needed by the GovernorUpgradeable cancel function.
    function cancel(uint256 _proposalId) public virtual {
        (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas, bytes32 _descriptionHash) =
            proposalDetails(_proposalId);
        GovernorUpgradeable.cancel(_targets, _values, _calldatas, _descriptionHash);
    }

    /// @notice Returns the details of a proposalId. Reverts if `proposalId` is not a known proposal.
    /// @param _proposalId The enumerated proposal ID.
    /// @return The targets, values, calldatas, and descriptionHash of the proposal.
    function proposalDetails(uint256 _proposalId)
        public
        view
        virtual
        returns (address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        GovernorSequentialProposalIdStorage storage $ = _getGovernorSequentialProposalIdStorage();
        ProposalDetails memory _details = $._proposalDetails[_proposalId];
        if (_details.descriptionHash == 0) {
            revert GovernorNonexistentProposal(_proposalId);
        }
        return (_details.targets, _details.values, _details.calldatas, _details.descriptionHash);
    }

    /// @notice Returns the number of stored proposals.
    /// @return The number of stored proposals.
    function proposalCount() public view virtual returns (uint256) {
        GovernorSequentialProposalIdStorage storage $ = _getGovernorSequentialProposalIdStorage();
        return $._nextProposalId;
    }
}