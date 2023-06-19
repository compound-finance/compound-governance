import {
  loadFixture,
  time,
  mine,
} from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import {
  setupGovernorBravo,
  setupGovernorAlpha,
  propose,
  proposeAndPass,
  proposeAndQueue,
} from "./governanceHelpers";
import { GovernorBravoDelegate } from "../typechain-types";

describe("Governor Bravo", function () {
  async function deployFixtures() {
    const [owner, otherAccount] = await ethers.getSigners();
    const { governorAlpha, timelock, comp } = await setupGovernorAlpha();
    const { governorBravo } = await setupGovernorBravo(
      timelock,
      comp,
      governorAlpha
    );

    return { owner, otherAccount, governorBravo, comp };
  }

  describe("Initialize", function () {
    it("Happy Path", async function () {
      const GovernorBravoDelegator = await ethers.getContractFactory(
        "GovernorBravoDelegator"
      );
      const GovernorBravoDelegate = await ethers.getContractFactory(
        "GovernorBravoDelegate"
      );
      const addresses = (await ethers.getSigners()).slice(3);
      const governorBravoDelegate = await GovernorBravoDelegate.deploy();
      let governorBravo = await GovernorBravoDelegator.deploy(
        addresses[0].address,
        addresses[1].address,
        addresses[2].address,
        await governorBravoDelegate.getAddress(),
        5760,
        100,
        BigInt("1000") * 10n ** 18n
      );
    });

    it("Error: voting period", async function () {
      const GovernorBravoDelegator = await ethers.getContractFactory(
        "GovernorBravoDelegator"
      );
      const GovernorBravoDelegate = await ethers.getContractFactory(
        "GovernorBravoDelegate"
      );
      const addresses = (await ethers.getSigners()).slice(3);
      const governorBravoDelegate = await GovernorBravoDelegate.deploy();
      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0].address,
          addresses[1].address,
          addresses[2].address,
          await governorBravoDelegate.getAddress(),
          5759,
          100,
          BigInt("1000") * 10n ** 18n
        )
      ).to.be.revertedWith("GovernorBravo::initialize: invalid voting period");

      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0].address,
          addresses[1].address,
          addresses[2].address,
          await governorBravoDelegate.getAddress(),
          80641,
          100,
          BigInt("1000") * 10n ** 18n
        )
      ).to.be.revertedWith("GovernorBravo::initialize: invalid voting period");
    });

    it("Error: voting delay", async function () {
      const GovernorBravoDelegator = await ethers.getContractFactory(
        "GovernorBravoDelegator"
      );
      const GovernorBravoDelegate = await ethers.getContractFactory(
        "GovernorBravoDelegate"
      );
      const addresses = (await ethers.getSigners()).slice(3);
      const governorBravoDelegate = await GovernorBravoDelegate.deploy();
      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0].address,
          addresses[1].address,
          addresses[2].address,
          await governorBravoDelegate.getAddress(),
          5760,
          0,
          BigInt("1000") * 10n ** 18n
        )
      ).to.be.revertedWith("GovernorBravo::initialize: invalid voting delay");

      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0].address,
          addresses[1].address,
          addresses[2].address,
          await governorBravoDelegate.getAddress(),
          5760,
          40321,
          BigInt("1000") * 10n ** 18n
        )
      ).to.be.revertedWith("GovernorBravo::initialize: invalid voting delay");
    });

    it("Error: proposal threshold", async function () {
      const GovernorBravoDelegator = await ethers.getContractFactory(
        "GovernorBravoDelegator"
      );
      const GovernorBravoDelegate = await ethers.getContractFactory(
        "GovernorBravoDelegate"
      );
      const addresses = (await ethers.getSigners()).slice(3);
      const governorBravoDelegate = await GovernorBravoDelegate.deploy();
      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0].address,
          addresses[1].address,
          addresses[2].address,
          await governorBravoDelegate.getAddress(),
          5760,
          40320,
          BigInt("10") * 10n ** 18n
        )
      ).to.be.revertedWith(
        "GovernorBravo::initialize: invalid proposal threshold"
      );

      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0].address,
          addresses[1].address,
          addresses[2].address,
          await governorBravoDelegate.getAddress(),
          5760,
          40320,
          BigInt("100001") * 10n ** 18n
        )
      ).to.be.revertedWith(
        "GovernorBravo::initialize: invalid proposal threshold"
      );
    });

    it("Error: reinitialize", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const addresses = (await ethers.getSigners()).slice(3);

      await expect(
        governorBravo.initialize(
          addresses[0].address,
          addresses[1].address,
          5760,
          100,
          BigInt("1000") * 10n ** 18n
        )
      ).to.be.revertedWith(
        "GovernorBravo::initialize: can only initialize once"
      );
    });

    it("Error: invalid comp", async function () {
      const GovernorBravoDelegator = await ethers.getContractFactory(
        "GovernorBravoDelegator"
      );
      const GovernorBravoDelegate = await ethers.getContractFactory(
        "GovernorBravoDelegate"
      );
      const addresses = (await ethers.getSigners()).slice(3);
      const governorBravoDelegate = await GovernorBravoDelegate.deploy();
      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0].address,
          ethers.zeroPadBytes("0x", 20),
          addresses[2].address,
          await governorBravoDelegate.getAddress(),
          5760,
          40320,
          BigInt("1000") * 10n ** 18n
        )
      ).to.be.revertedWith("GovernorBravo::initialize: invalid comp address");
    });

    it("Error: invalid timelock", async function () {
      const GovernorBravoDelegator = await ethers.getContractFactory(
        "GovernorBravoDelegator"
      );
      const GovernorBravoDelegate = await ethers.getContractFactory(
        "GovernorBravoDelegate"
      );
      const addresses = (await ethers.getSigners()).slice(3);
      const governorBravoDelegate = await GovernorBravoDelegate.deploy();
      await expect(
        GovernorBravoDelegator.deploy(
          ethers.zeroPadBytes("0x", 20),
          addresses[0].address,
          addresses[2].address,
          await governorBravoDelegate.getAddress(),
          5760,
          40320,
          BigInt("1000") * 10n ** 18n
        )
      ).to.be.revertedWith(
        "GovernorBravo::initialize: invalid timelock address"
      );
    });
  });

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
            await governorBravo._setPendingAdmin.populateTransaction(
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
            await governorBravo._setPendingAdmin.populateTransaction(
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
              await governorBravo._setPendingAdmin.populateTransaction(
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
              await governorBravo._setPendingAdmin.populateTransaction(
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
            await governorBravo._setPendingAdmin.populateTransaction(
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
              await governorBravo._setPendingAdmin.populateTransaction(
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
        [await governorBravo.getAddress()],
        [0],
        [""],
        [
          (
            await governorBravo._setPendingAdmin.populateTransaction(
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
              await governorBravo._setPendingAdmin.populateTransaction(
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

    it("Error: bravo not active", async function () {
      const { timelock, comp } = await setupGovernorAlpha();
      const owner = (await ethers.getSigners())[0].address;

      const GovernorBravoDelegator = await ethers.getContractFactory(
        "GovernorBravoDelegator"
      );
      const GovernorBravoDelegate = await ethers.getContractFactory(
        "GovernorBravoDelegate"
      );
      const governorBravoDelegate = await GovernorBravoDelegate.deploy();
      let governorBravo = (await GovernorBravoDelegator.deploy(
        await timelock.getAddress(),
        await comp.getAddress(),
        owner,
        await governorBravoDelegate.getAddress(),
        5760,
        100,
        BigInt("1000") * 10n ** 18n
      )) as unknown as GovernorBravoDelegate;
      governorBravo = GovernorBravoDelegate.attach(await governorBravo.getAddress()) as GovernorBravoDelegate;

      await expect(
        propose(governorBravo, [owner], [1], ["0x"], "Desc")
      ).to.be.revertedWith("GovernorBravo::propose: Governor Bravo not active");
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
              await governorBravo._setPendingAdmin.populateTransaction(
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
      const proposalId = await proposeAndPass(
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
      const proposalId = await proposeAndPass(
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
      const proposalId = await propose(
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
      const proposalId = await proposeAndQueue(
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
      const proposalId = await propose(
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
      const { governorBravo, owner } = await loadFixture(deployFixtures);
      const tx = { to: await governorBravo.timelock(), value: 1000 };
      await owner.sendTransaction(tx);
      const proposalId = await proposeAndQueue(
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

    describe("Whitelisted", function () {
      it("Happy Path", async function () {
        const { governorBravo, owner, otherAccount } = await loadFixture(
          deployFixtures
        );

        await governorBravo._setWhitelistAccountExpiration(
          otherAccount.address,
          (await time.latest()) + 1000
        );
        const proposalId = await propose(
          governorBravo.connect(otherAccount),
          [owner.address],
          [1],
          ["0x"],
          "Whitelist proposal"
        );

        await governorBravo._setWhitelistGuardian(owner.address);
        await governorBravo.cancel(proposalId);
      });

      it("Error: whitelisted proposer", async function () {
        const { governorBravo, owner, otherAccount } = await loadFixture(
          deployFixtures
        );

        await governorBravo._setWhitelistAccountExpiration(
          otherAccount.address,
          (await time.latest()) + 1000
        );
        const proposalId = await propose(
          governorBravo.connect(otherAccount),
          [owner.address],
          [1],
          ["0x"],
          "Whitelist proposal"
        );

        await expect(governorBravo.cancel(proposalId)).to.be.revertedWith(
          "GovernorBravo::cancel: whitelisted proposer"
        );
      });

      it("Error: whitelisted proposer above threshold", async function () {
        const { governorBravo, owner, otherAccount, comp } = await loadFixture(
          deployFixtures
        );

        await governorBravo._setWhitelistAccountExpiration(
          otherAccount.address,
          (await time.latest()) + 1000
        );
        const proposalId = await propose(
          governorBravo.connect(otherAccount),
          [owner.address],
          [1],
          ["0x"],
          "Whitelist proposal"
        );
        await comp.transfer(
          otherAccount.address,
          BigInt("100000") * BigInt("10") ** BigInt("18")
        );
        await comp.connect(otherAccount).delegate(otherAccount.address);

        await governorBravo._setWhitelistGuardian(owner.address);
        await expect(governorBravo.cancel(proposalId)).to.be.revertedWith(
          "GovernorBravo::cancel: whitelisted proposer"
        );
      });
    });
  });

  describe("Vote", function () {
    it("With Reason", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);
      const proposalId = await propose(
        governorBravo,
        [governorBravo],
        [0],
        [ethers.AbiCoder.defaultAbiCoder().encode(["string"], ["encoded value"])],
        "My proposal"
      );

      await expect(
        governorBravo.castVoteWithReason(proposalId, 0, "We need more info")
      )
        .to.emit(governorBravo, "VoteCast");
    });
  });

  it("Get Actions", async function () {
    const { governorBravo } = await loadFixture(deployFixtures);
    const proposalId = await propose(
      governorBravo,
      [governorBravo],
      [0],
      [ethers.AbiCoder.defaultAbiCoder().encode(["string"], ["encoded value"])],
      "My proposal"
    );

    expect(await governorBravo.getActions(proposalId)).to.deep.equal([
      [await governorBravo.getAddress()],
      [0],
      [""],
      [ethers.AbiCoder.defaultAbiCoder().encode(["string"], ["encoded value"])],
    ]);
  });

  it("Get Receipt", async function () {
    const { governorBravo, owner } = await loadFixture(deployFixtures);
    const proposalId = await propose(
      governorBravo,
      [governorBravo],
      [0],
      [ethers.AbiCoder.defaultAbiCoder().encode(["string"], ["encoded value"])],
      "My proposal"
    );

    await governorBravo.castVote(proposalId, 2);
    expect(
      await governorBravo.getReceipt(proposalId, owner.address)
    ).to.deep.equal([
      true,
      2,
      BigInt("10000000000000000000000000"),
    ]);
  });
});
