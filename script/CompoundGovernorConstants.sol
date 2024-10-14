// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign
pragma solidity 0.8.26;

contract CompoundGovernorConstants {
    // TODO: Verify these values are correct for launch of the CompoundGovernor

    // These constants are taken from the existing GovernorBravoDelegate contract.

    uint48 INITIAL_VOTING_DELAY = 13_140; // The delay before voting takes place, in blocks
    uint32 INITIAL_VOTING_PERIOD = 19_710; // The duration of voting on a proposal, in blocks
    uint256 INITIAL_PROPOSAL_THRESHOLD = 25_000e18; // Votes required in order for a voter to become proposer
    uint256 INITIAL_QUORUM = 400_000e18; // 400,000 = 4% of Comp

    uint48 INITIAL_VOTE_EXTENSION = 7200; // Prevents sudden token moves before voting ends (2 days of blocks)

    // The address of the COMP token
    address COMP_TOKEN_ADDRESS = 0xc00e94Cb662C3520282E6f5717214004A7f26888;

    // The address of the Timelock
    address payable TIMELOCK_ADDRESS = payable(0x6d903f6003cca6255D85CcA4D3B5E5146dC33925);

    // The fork block for testing
    uint256 FORK_BLOCK = 20_885_000;

    address[] public _majorDelegates;

    constructor() {
        _majorDelegates = new address[](18);
        _majorDelegates[0] = 0x1B686eE8E31c5959D9F5BBd8122a58682788eeaD; // L2BEAT
        _majorDelegates[1] = 0xF4B0556B9B6F53E00A1FDD2b0478Ce841991D8fA; // olimpio
        _majorDelegates[2] = 0x11cd09a0c5B1dc674615783b0772a9bFD53e3A8F; // Gauntlet
        _majorDelegates[3] = 0xB933AEe47C438f22DE0747D57fc239FE37878Dd1; // Wintermute
        _majorDelegates[4] = 0x0eB5B03c0303f2F47cD81d7BE4275AF8Ed347576; // Treasure
        _majorDelegates[5] = 0xF92F185AbD9E00F56cb11B0b709029633d1E37B4; //
        _majorDelegates[6] = 0x186e505097BFA1f3cF45c2C9D7a79dE6632C3cdc;
        _majorDelegates[7] = 0x5663D01D8109DDFC8aACf09fBE51F2d341bb3643;
        _majorDelegates[8] = 0x2ef27b114917dD53f8633440A7C0328fef132e2F; // MUX Protocol
        _majorDelegates[9] = 0xE48C655276C23F1534AE2a87A2bf8A8A6585Df70; // ercwl
        _majorDelegates[10] = 0x8A3e9846df0CDc723C06e4f0C642ffFF82b54610;
        _majorDelegates[11] = 0xAD16ebE6FfC7d96624A380F394cD64395B0C6144; // DK (Premia)
        _majorDelegates[12] = 0xA5dF0cf3F95C6cd97d998b9D990a86864095d9b0; // Blockworks Research
        _majorDelegates[13] = 0x839395e20bbB182fa440d08F850E6c7A8f6F0780; // Griff Green
        _majorDelegates[14] = 0x2e3BEf6830Ae84bb4225D318F9f61B6b88C147bF; // Camelot
        _majorDelegates[15] = 0x8F73bE66CA8c79382f72139be03746343Bf5Faa0; // mihal.eth
        _majorDelegates[16] = 0xb5B069370Ef24BC67F114e185D185063CE3479f8; // Frisson
        _majorDelegates[17] = 0xdb5781a835b60110298fF7205D8ef9678Ff1f800; // yoav.eth
    }
}
