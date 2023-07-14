import { expect } from "chai";
import { ethers } from "hardhat";
import { proposeAndExecute } from "./governanceHelpers";
import {
  mine,
  reset,
  impersonateAccount,
} from "@nomicfoundation/hardhat-network-helpers";
import { Comp, GovernorBravoDelegate } from "../typechain-types";
import { Signer } from "ethers";

describe("ForkTestSimulateUpgrade", function () {
  let proposingSigner: Signer;
  let comp: Comp;
  let governorBravoDelegator: GovernorBravoDelegate;

  before(async function () {
    comp = await ethers.getContractAt(
      "Comp",
      "0xc00e94Cb662C3520282E6f5717214004A7f26888"
    );
    governorBravoDelegator = await ethers.getContractAt(
      "GovernorBravoDelegate",
      "0xc0Da02939E1441F497fd74F78cE7Decb17B66529"
    );
    proposingSigner = await ethers.getSigner(
      "0xF977814e90dA44bFA03b6295A0616a897441aceC"
    );
  });

  // Update the implementation of GovernorBravo before each test
  beforeEach(async function () {
    await reset(process.env.RPC_URL);
    await impersonateAccount(await proposingSigner.getAddress());
    await comp.connect(proposingSigner).delegate(proposingSigner);
    const NewImplementation = await ethers.getContractFactory(
      "GovernorBravoDelegate"
    );
    const newImplementation = await NewImplementation.deploy();

    await mine();
    await proposeAndExecute(
      governorBravoDelegator.connect(proposingSigner),
      [governorBravoDelegator],
      [0],
      [
        ethers.id("_setImplementation(address)").substring(0, 10) +
          ethers.AbiCoder.defaultAbiCoder()
            .encode(["address"], [await newImplementation.getAddress()])
            .slice(2),
      ],
      "Upgrade Governance"
    );
  });

  it("access old proposals", async function () {
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
});
