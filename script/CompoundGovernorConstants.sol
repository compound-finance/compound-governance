// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign
pragma solidity 0.8.26;

contract CompoundGovernorConstants {
    // These constants are taken from the existing GovernorBravoDelegate contract.
    uint48 constant INITIAL_VOTING_DELAY = 13_140; // The delay before voting takes place, in blocks
    uint32 constant INITIAL_VOTING_PERIOD = 19_710; // The duration of voting on a proposal, in blocks
    uint256 constant INITIAL_PROPOSAL_THRESHOLD = 25_000e18; // Votes required in order for a voter to become proposer
    uint256 constant INITIAL_QUORUM = 400_000e18; // 400,000 = 4% of Comp

    uint48 constant INITIAL_VOTE_EXTENSION = 14_400; // Prevents sudden token moves before voting ends (2 days).

    // The address of the COMP token
    address constant COMP_TOKEN_ADDRESS = 0xc00e94Cb662C3520282E6f5717214004A7f26888;

    // The address of the Timelock
    address payable constant TIMELOCK_ADDRESS = payable(0x6d903f6003cca6255D85CcA4D3B5E5146dC33925);

    // The address of the proxy admin
    address constant PROXY_ADMIN_ADDRESS = 0x08af690B4bd347c13BA57D7731b277f5d3D7434A;
    address constant COMMUNITY_MULTISIG_ADDRESS = 0xbbf3f1421D886E9b2c5D716B5192aC998af2012c; // Current proposal
        // guardian.

    // The fork block for testing
    uint256 constant FORK_BLOCK = 21_017_323;

    uint8 constant VOTE_TYPE_FRACTIONAL = 255;

    // GovernorBravo to receive upgrade proposal
    address constant GOVERNOR_BRAVO_DELEGATE_ADDRESS = 0xc0Da02939E1441F497fd74F78cE7Decb17B66529;

    // The deployed CompooundGovernor address for testing upgradability after deployment
    // TODO: for now, just a placeholder
    address constant DEPLOYED_UPGRADE_CANDIDATE = 0x1111111111111111111111111111111111111111;

    address[] public _majorDelegates;

    constructor() {
        _majorDelegates = new address[](18);
        _majorDelegates[0] = 0x9AA835Bc7b8cE13B9B0C9764A52FbF71AC62cCF1; // a16z
        _majorDelegates[1] = 0x7E959eAB54932f5cFd10239160a7fd6474171318;
        _majorDelegates[2] = 0x8169522c2C57883E8EF80C498aAB7820dA539806; // Geoffrey Hayes
        _majorDelegates[3] = 0x683a4F9915D6216f73d6Df50151725036bD26C02; // Gauntlet
        _majorDelegates[4] = 0x8d07D225a769b7Af3A923481E1FdF49180e6A265; // MonetSupply
        _majorDelegates[5] = 0x66cD62c6F8A4BB0Cd8720488BCBd1A6221B765F9; // allthecolors
        _majorDelegates[6] = 0x2210dc066aacB03C9676C4F1b36084Af14cCd02E; // bryancolligan
        _majorDelegates[7] = 0x070341aA5Ed571f0FB2c4a5641409B1A46b4961b; // Franklin DAO
        _majorDelegates[8] = 0xB933AEe47C438f22DE0747D57fc239FE37878Dd1; // Wintermute Governance
        _majorDelegates[9] = 0x13BDaE8c5F0fC40231F0E6A4ad70196F59138548; // Michigan Blockchain
        _majorDelegates[10] = 0x3FB19771947072629C8EEE7995a2eF23B72d4C8A; // PGov
        _majorDelegates[11] = 0xB49f8b8613bE240213C1827e2E576044fFEC7948; // Avantgarde
        _majorDelegates[12] = 0x54A37d93E57c5DA659F508069Cf65A381b61E189; // blck
        _majorDelegates[13] = 0x7d1a02C0ebcF06E1A36231A54951E061673ab27f;
        _majorDelegates[14] = 0xb35659cbac913D5E4119F2Af47fD490A45e2c826; // Event Horizon DAO
        _majorDelegates[15] = 0x47C125DEe6898b6CB2379bCBaFC823Ff3f614770; // blockchainucla
        _majorDelegates[16] = 0x7AE109A63ff4DC852e063a673b40BED85D22E585; // CalBlockchain
        _majorDelegates[17] = 0xed11e5eA95a5A3440fbAadc4CC404C56D0a5bb04; // she256.eth
    }
}
