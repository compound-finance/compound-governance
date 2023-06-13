import {
  loadFixture,
  time,
  mine,
} from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { GovernorAlpha, GovernorBravoDelegate } from "../typechain-types";
import { propose, proposeAndPass, proposeAndQueue } from "./governanceHelpers";

describe("Governor Bravo", function () {
  async function deployFixtures() {
    const [owner, otherAccount] = await ethers.getSigners();

    const Timelock = await ethers.getContractFactory("Timelock");
    const Comp = await ethers.getContractFactory("Comp");
    const GovernorAlpha = await ethers.getContractFactory(
      "contracts/GovernorAlpha.sol:GovernorAlpha"
    );
    const GovernorBravoDelegator = await ethers.getContractFactory(
      "GovernorBravoDelegator"
    );
    const GovernorBravoDelegate = await ethers.getContractFactory(
      "GovernorBravoDelegate"
    );

    const timelock = await Timelock.deploy(owner.address, 172800);
    const comp = await Comp.deploy(owner.address);
    const governorAlpha: GovernorAlpha = (await GovernorAlpha.deploy(
      timelock.address,
      comp.address,
      owner.address
    )) as unknown as GovernorAlpha;

    let eta =
      BigInt(Math.round(Date.now() / 1000)) +
      100n +
      (await timelock.MINIMUM_DELAY()).toBigInt();
    let txData = (
      await timelock.populateTransaction.setPendingAdmin(governorAlpha.address)
    ).data!;
    await timelock.queueTransaction(timelock.address, 0, "", txData, eta);
    await time.increaseTo(eta);
    await timelock.executeTransaction(timelock.address, 0, "", txData, eta);
    await governorAlpha.__acceptAdmin();
    const governorBravoDelegate = await GovernorBravoDelegate.deploy();
    let governorBravo: GovernorBravoDelegate =
      (await GovernorBravoDelegator.deploy(
        timelock.address,
        comp.address,
        owner.address,
        governorBravoDelegate.address,
        5760,
        100,
        BigInt("1000") * 10n ** 18n
      )) as unknown as GovernorBravoDelegate;
    await comp.delegate(owner.address);
    eta =
      BigInt(Math.round(Date.now() / 1000)) +
      100n +
      (await timelock.MINIMUM_DELAY()).toBigInt();
    txData = (
      await timelock.populateTransaction.setPendingAdmin(governorBravo.address)
    ).data!;
    await propose(
      governorAlpha,
      [timelock.address],
      [0n],
      [txData],
      "Transfer admin for bravo"
    );
    await governorAlpha.castVote(await governorAlpha.votingDelay(), true);
    await mine(await governorAlpha.votingPeriod());
    await governorAlpha.queue(1);
    await time.increase(await timelock.MINIMUM_DELAY());
    await governorAlpha.execute(1);
    governorBravo = GovernorBravoDelegate.attach(governorBravo.address);
    await governorBravo._initiate(governorAlpha.address);

    return { governorBravo, comp, owner, otherAccount };
  }

  describe("Propose", function () {
    it("Happy Path", async function () {
      const { governorBravo, owner, otherAccount } = await loadFixture(
        deployFixtures
      );

      let proposalId = await propose(
        governorBravo,
        [governorBravo],
        [0],
        [
          (
            await governorBravo.populateTransaction._setPendingAdmin(
              owner.address
            )
          ).data!,
        ],
        "Steal governance"
      );

      await governorBravo.cancel(proposalId);

      proposalId = await propose(
        governorBravo,
        [governorBravo],
        [0],
        [
          (
            await governorBravo.populateTransaction._setPendingAdmin(
              owner.address
            )
          ).data!,
        ],
        "Steal governance"
      );
    });

    it("Error: arity Mismatch", async function () {
      const { governorBravo, owner, otherAccount } = await loadFixture(
        deployFixtures
      );

      await expect(
        propose(
          governorBravo,
          [governorBravo, governorBravo],
          [0],
          [
            (
              await governorBravo.populateTransaction._setPendingAdmin(
                owner.address
              )
            ).data!,
          ],
          "Steal governance"
        )
      ).to.be.revertedWith(
        "GovernorBravo::propose: proposal function information arity mismatch"
      );
    });

    it("Error: below proposal threshold", async function () {
      const { governorBravo, owner, otherAccount } = await loadFixture(
        deployFixtures
      );

      await expect(
        propose(
          governorBravo.connect(otherAccount),
          [governorBravo],
          [0],
          [
            (
              await governorBravo.populateTransaction._setPendingAdmin(
                owner.address
              )
            ).data!,
          ],
          "Steal governance"
        )
      ).to.be.revertedWith(
        "GovernorBravo::propose: proposer votes below proposal threshold"
      );
    });

    it("Error: active proposal", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);

      await propose(
        governorBravo,
        [governorBravo],
        [0],
        [
          (
            await governorBravo.populateTransaction._setPendingAdmin(
              owner.address
            )
          ).data!,
        ],
        "Steal governance"
      );

      await expect(
        propose(
          governorBravo,
          [governorBravo],
          [0],
          [
            (
              await governorBravo.populateTransaction._setPendingAdmin(
                owner.address
              )
            ).data!,
          ],
          "Steal governance"
        )
      ).to.be.revertedWith(
        "GovernorBravo::propose: one live proposal per proposer, found an already active proposal"
      );
    });

    it("Error: pending proposal", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);

      await governorBravo.propose(
        [governorBravo.address],
        [0],
        [""],
        [
          (
            await governorBravo.populateTransaction._setPendingAdmin(
              owner.address
            )
          ).data!,
        ],
        "Steal governance"
      );

      await expect(
        propose(
          governorBravo,
          [governorBravo],
          [0],
          [
            (
              await governorBravo.populateTransaction._setPendingAdmin(
                owner.address
              )
            ).data!,
          ],
          "Steal governance"
        )
      ).to.be.revertedWith(
        "GovernorBravo::propose: one live proposal per proposer, found an already pending proposal"
      );
    });

    it("Error: at least one action", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);

      await expect(
        propose(governorBravo, [], [], [], "Empty")
      ).to.be.revertedWith("GovernorBravo::propose: must provide actions");
    });

    it("Error: below max operations", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);
      await expect(
        propose(
          governorBravo,
          Array(11).fill(governorBravo),
          Array(11).fill("0"),
          Array(11).fill("0x"),
          "11 actions"
        )
      ).to.be.revertedWith("GovernorBravo::propose: too many actions");
    });

    describe("Whitelist", function () {
      it("Happy Path", async function () {
        const { governorBravo, owner, otherAccount } = await loadFixture(
          deployFixtures
        );

        await governorBravo._setWhitelistAccountExpiration(
          otherAccount.address,
          (await time.latest()) + 1000
        );

        await propose(
          governorBravo.connect(otherAccount),
          [governorBravo],
          [0],
          [
            (
              await governorBravo.populateTransaction._setPendingAdmin(
                owner.address
              )
            ).data!,
          ],
          "Steal governance"
        );
      });
    });
  });

  describe("Queue", function () {
    it("Happy Path", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = proposeAndPass(
        governorBravo,
        [governorBravo],
        [1],
        ["0x"],
        "Will queue"
      );

      await governorBravo.queue(proposalId);
    });

    it("Error: identical actions", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = proposeAndPass(
        governorBravo,
        [governorBravo, governorBravo],
        [1, 1],
        ["0x", "0x"],
        "Will queue"
      );

      await expect(governorBravo.queue(proposalId)).to.be.revertedWith(
        "GovernorBravo::queueOrRevertInternal: identical proposal action already queued at eta"
      );
    });

    it("Error: proposal not passed", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = propose(
        governorBravo,
        [governorBravo],
        [1],
        ["0x"],
        "Not passed"
      );

      await expect(governorBravo.queue(proposalId)).to.be.revertedWith(
        "GovernorBravo::queue: proposal can only be queued if it is succeeded"
      );
    });
  });

  describe("Execute", function () {
    it("Happy Path", async function () {
      const { governorBravo, owner, otherAccount } = await loadFixture(
        deployFixtures
      );
      const tx = { to: await governorBravo.timelock(), value: 1000 };
      await owner.sendTransaction(tx);
      const proposalId = proposeAndQueue(
        governorBravo,
        [owner.address],
        [1],
        ["0x"],
        "Will be executed"
      );

      const timelockAddress = await governorBravo.timelock();
      const timelock = await ethers.getContractAt("Timelock", timelockAddress);

      await time.increase(await timelock.delay());

      await governorBravo.execute(proposalId);
    });

    it("Error: not queued", async function () {
      const { governorBravo, owner, otherAccount } = await loadFixture(
        deployFixtures
      );
      const tx = { to: await governorBravo.timelock(), value: 1000 };
      await owner.sendTransaction(tx);
      const proposalId = propose(
        governorBravo,
        [owner.address],
        [1],
        ["0x"],
        "Not queued"
      );

      await expect(governorBravo.execute(proposalId)).to.be.revertedWith(
        "GovernorBravo::execute: proposal can only be executed if it is queued"
      );
    });
  });

  describe("Cancel", function () {
    it("Happy Path: proposer cancel", async function () {
      const { governorBravo, otherAccount } = await loadFixture(deployFixtures);
      const proposalId = await proposeAndPass(
        governorBravo,
        [governorBravo],
        [1],
        ["0x"],
        "Will queue"
      );

      await governorBravo.cancel(proposalId);
    });

    it("Happy Path: below threshold", async function () {
      const { governorBravo, comp, otherAccount } = await loadFixture(
        deployFixtures
      );
      const proposalId = await proposeAndPass(
        governorBravo,
        [governorBravo],
        [1],
        ["0x"],
        "Will queue"
      );

      await comp.delegate(otherAccount.address);
      await governorBravo.connect(otherAccount).cancel(proposalId);
    });

    it("Error: above threshold", async function () {
      const { governorBravo, comp, otherAccount } = await loadFixture(
        deployFixtures
      );
      const proposalId = await proposeAndPass(
        governorBravo,
        [governorBravo],
        [1],
        ["0x"],
        "Will queue"
      );

      await expect(
        governorBravo.connect(otherAccount).cancel(proposalId)
      ).to.be.revertedWith("GovernorBravo::cancel: proposer above threshold");
    });

    it("Error: cancel executed proposal", async function () {
      const { governorBravo, owner, otherAccount } = await loadFixture(
        deployFixtures
      );
      const tx = { to: await governorBravo.timelock(), value: 1000 };
      await owner.sendTransaction(tx);
      const proposalId = proposeAndQueue(
        governorBravo,
        [owner.address],
        [1],
        ["0x"],
        "Will be executed"
      );

      const timelockAddress = await governorBravo.timelock();
      const timelock = await ethers.getContractAt("Timelock", timelockAddress);

      await time.increase(await timelock.delay());
      await governorBravo.execute(proposalId);

      await expect(governorBravo.cancel(proposalId)).to.be.revertedWith(
        "GovernorBravo::cancel: cannot cancel executed proposal"
      );
    });
  });

  it("Get Actions", async function () {
    const { governorBravo } = await loadFixture(deployFixtures);
    const proposalId = await propose(
      governorBravo,
      [governorBravo],
      [0],
      [ethers.utils.defaultAbiCoder.encode(["string"], ["encoded value"])],
      "My proposal"
    );

    expect(await governorBravo.getActions(proposalId)).to.deep.equal([
      [governorBravo.address],
      [0],
      [""],
      [ethers.utils.defaultAbiCoder.encode(["string"], ["encoded value"])],
    ]);
  });
});
