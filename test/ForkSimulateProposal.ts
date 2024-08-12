import { expect } from "chai";
import hardhat, { ethers } from "hardhat";
import {
  proposeAndExecute,
  propose,
  getVoteWithReasonTypes,
  getTypedDomain,
  proposeAndQueue,
} from "./governanceHelpers";
import {
  mine,
  reset,
  impersonateAccount,
  loadFixture,
  time,
} from "@nomicfoundation/hardhat-network-helpers";

const PROPOSAL_ID = 304;
const COMMUNITY_MULTISIG = "0xbbf3f1421D886E9b2c5D716B5192aC998af2012c";

describe("ForkTestSimulateUpgrade", function () {
  // Update the implementation of GovernorBravo before each test
  async function deployFixtures() {
    if (process.env.RPC_URL === undefined) {
      throw new Error("RPC_URL is undefined");
    }
    await reset(process.env.RPC_URL);

    const comp = await ethers.getContractAt(
      "Comp",
      "0xc00e94Cb662C3520282E6f5717214004A7f26888"
    );
    const governorBravoDelegator = await ethers.getContractAt(
      "GovernorBravoDelegate",
      "0xc0Da02939E1441F497fd74F78cE7Decb17B66529"
    );
    const voter1 = await ethers.getSigner(
      "0x7e959eab54932f5cfd10239160a7fd6474171318"
    );
    const voter2 = await ethers.getSigner(
      "0x9aa835bc7b8ce13b9b0c9764a52fbf71ac62ccf1"
    );
    const proposingSigner = await ethers.getSigner(
      "0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B"
    );
    await hardhat.network.provider.send("hardhat_setBalance", [
      proposingSigner.address,
      "0x" + BigInt(10n * 10n ** 18n).toString(16),
    ]);
    await hardhat.network.provider.send("hardhat_setBalance", [
      voter1.address,
      "0x" + BigInt(10n * 10n ** 18n).toString(16),
    ]);
    await hardhat.network.provider.send("hardhat_setBalance", [
      voter2.address,
      "0x" + BigInt(10n * 10n ** 18n).toString(16),
    ]);
    await impersonateAccount(await voter1.getAddress());
    await impersonateAccount(await voter2.getAddress());
    await impersonateAccount(await proposingSigner.getAddress());
    await comp.connect(proposingSigner).delegate(proposingSigner);

    await governorBravoDelegator.connect(voter1).castVote(PROPOSAL_ID, 1);
    await governorBravoDelegator.connect(voter2).castVote(PROPOSAL_ID, 1);
    await mine(20533049 - (await ethers.provider.getBlockNumber()));

    await governorBravoDelegator.queue(PROPOSAL_ID);

    await time.increase(60 * 60 * 24 * 3);

    await governorBravoDelegator.execute(PROPOSAL_ID);

    return { comp, governorBravoDelegator, proposingSigner };
  }

  it("access old proposals", async function () {
    const { governorBravoDelegator } = await loadFixture(deployFixtures);
    const proposal43 = await governorBravoDelegator.proposals(43);
    expect(proposal43).to.deep.equal([
      43,
      "0x8169522c2C57883E8EF80C498aAB7820dA539806",
      "1618779737",
      "12235672",
      "12252952",
      "1367841964900760752685033",
      "5000000000000000000000",
      "0",
      false,
      true,
    ]);
  });

  it("access old actions", async function () {
    const { governorBravoDelegator } = await loadFixture(deployFixtures);
    const proposal43Actions = await governorBravoDelegator.getActions(43);
    expect(proposal43Actions).to.deep.equal([
      [
        "0xc0Da02939E1441F497fd74F78cE7Decb17B66529",
        "0xc0Da02939E1441F497fd74F78cE7Decb17B66529",
      ],
      [0, 0],
      ["_setVotingDelay(uint256)", "_setVotingPeriod(uint256)"],
      [
        "0x0000000000000000000000000000000000000000000000000000000000003354",
        "0x0000000000000000000000000000000000000000000000000000000000004cfe",
      ],
    ]);
  });

  it("validate storage fields", async function () {
    const { governorBravoDelegator } = await loadFixture(deployFixtures);
    expect(await governorBravoDelegator.admin()).to.equal(
      "0x6d903f6003cca6255D85CcA4D3B5E5146dC33925"
    );
    expect(await governorBravoDelegator.pendingAdmin()).to.equal(
      ethers.ZeroAddress
    );
    expect(await governorBravoDelegator.comp()).to.equal(
      "0xc00e94Cb662C3520282E6f5717214004A7f26888"
    );
    expect(await governorBravoDelegator.timelock()).to.equal(
      "0x6d903f6003cca6255D85CcA4D3B5E5146dC33925"
    );
  });

  it("Grant COMP proposal", async function () {
    const { comp, governorBravoDelegator, proposingSigner } = await loadFixture(
      deployFixtures
    );
    const [signer] = await ethers.getSigners();
    const comptrollerAddress = "0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B";
    const grantCompSelector = ethers
      .id("_grantComp(address,uint256)")
      .substring(0, 10);
    const grantCompData =
      grantCompSelector +
      ethers.AbiCoder.defaultAbiCoder()
        .encode(["address", "uint256"], [signer.address, 10000])
        .slice(2);
    expect(await comp.balanceOf(signer.address)).to.equal(0);
    await proposeAndExecute(
      governorBravoDelegator.connect(proposingSigner),
      [comptrollerAddress],
      [0],
      [grantCompData],
      "Grant COMP"
    );

    expect(await comp.balanceOf(signer.address)).to.equal(10000);
  });

  it("Cast vote by sig with reason", async function () {
    const { comp, governorBravoDelegator, proposingSigner } = await loadFixture(
      deployFixtures
    );
    const [signer, otherSigner] = await ethers.getSigners();
    await comp.delegate(signer);
    await comp.connect(proposingSigner).transfer(signer.address, 1000);
    const proposalId = await propose(
      governorBravoDelegator.connect(proposingSigner),
      [governorBravoDelegator],
      [0],
      ["0x"],
      "Test Proposal"
    );

    const domain = await getTypedDomain(
      governorBravoDelegator,
      (
        await ethers.provider.getNetwork()
      ).chainId
    );

    const sig = await signer.signTypedData(domain, getVoteWithReasonTypes(), {
      proposalId,
      support: 1,
      reason: "Great Idea!",
    });

    const r = "0x" + sig.substring(2, 66);
    const s = "0x" + sig.substring(66, 130);
    const v = "0x" + sig.substring(130, 132);
    await expect(
      governorBravoDelegator
        .connect(otherSigner)
        .castVoteWithReasonBySig(proposalId, 1, "Great Idea!", v, r, s)
    )
      .to.emit(governorBravoDelegator, "VoteCast")
      .withArgs(signer.address, proposalId, 1, BigInt("1000"), "Great Idea!");
  });

  it("Proposal Guardian Set Properly", async function () {
    const { governorBravoDelegator } = await loadFixture(deployFixtures);
    expect(await governorBravoDelegator.proposalGuardian()).to.deep.equal([
      COMMUNITY_MULTISIG,
      1739768400n,
    ]);
  });

  it("Use Proposal Guardian", async function () {
    const { governorBravoDelegator, proposingSigner } = await loadFixture(
      deployFixtures
    );

    const [signer] = await ethers.getSigners();
    const comptrollerAddress = "0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B";
    const grantCompSelector = ethers
      .id("_grantComp(address,uint256)")
      .substring(0, 10);
    const grantCompData =
      grantCompSelector +
      ethers.AbiCoder.defaultAbiCoder()
        .encode(["address", "uint256"], [signer.address, 10000])
        .slice(2);
    const newProposalId = await proposeAndQueue(
      governorBravoDelegator.connect(proposingSigner),
      [comptrollerAddress],
      [0],
      [grantCompData],
      "Grant COMP"
    );

    const multisigSigner = await ethers.getSigner(COMMUNITY_MULTISIG);
    await impersonateAccount(await multisigSigner.getAddress());
    await governorBravoDelegator.connect(multisigSigner).cancel(newProposalId);
    expect(await governorBravoDelegator.state(newProposalId)).to.equal(2);
  });
});
