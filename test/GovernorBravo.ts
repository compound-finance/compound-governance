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
  getTypedDomain,
  getVoteTypes,
  ProposalState,
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
      await GovernorBravoDelegator.deploy(
        addresses[0],
        addresses[1],
        addresses[2],
        governorBravoDelegate,
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
          addresses[0],
          addresses[1],
          addresses[2],
          governorBravoDelegate,
          5759,
          100,
          BigInt("1000") * 10n ** 18n
        )
      ).to.be.revertedWith("GovernorBravo::initialize: invalid voting period");

      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0],
          addresses[1],
          addresses[2],
          governorBravoDelegate,
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
          addresses[0],
          addresses[1],
          addresses[2],
          governorBravoDelegate,
          5760,
          0,
          BigInt("1000") * 10n ** 18n
        )
      ).to.be.revertedWith("GovernorBravo::initialize: invalid voting delay");

      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0],
          addresses[1],
          addresses[2],
          governorBravoDelegate,
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
          addresses[0],
          addresses[1],
          addresses[2],
          await governorBravoDelegate,
          5760,
          40320,
          BigInt("10") * 10n ** 18n
        )
      ).to.be.revertedWith(
        "GovernorBravo::initialize: invalid proposal threshold"
      );

      await expect(
        GovernorBravoDelegator.deploy(
          addresses[0],
          addresses[1],
          addresses[2],
          governorBravoDelegate,
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
          addresses[0],
          addresses[1],
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
          addresses[0],
          ethers.zeroPadBytes("0x", 20),
          addresses[2],
          governorBravoDelegate,
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
          addresses[0],
          addresses[2],
          governorBravoDelegate,
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
      const { governorBravo } = await loadFixture(deployFixtures);

      let proposalId = await propose(governorBravo);

      await governorBravo.cancel(proposalId);

      proposalId = await propose(governorBravo);
    });

    it("Error: arity Mismatch", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);

      await expect(
        propose(
          governorBravo,
          [governorBravo, governorBravo],
          [0],
          [
            // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
            (
              await governorBravo._setPendingAdmin.populateTransaction(owner)
            ).data!,
          ],
          "Steal governance"
        )
      ).to.be.revertedWith(
        "GovernorBravo::propose: proposal function information arity mismatch"
      );
    });

    it("Error: below proposal threshold", async function () {
      const { governorBravo, otherAccount } = await loadFixture(deployFixtures);

      await expect(
        propose(governorBravo.connect(otherAccount))
      ).to.be.revertedWith(
        "GovernorBravo::propose: proposer votes below proposal threshold"
      );
    });

    it("Error: active proposal", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);

      await propose(governorBravo);

      await expect(propose(governorBravo)).to.be.revertedWith(
        "GovernorBravo::propose: one live proposal per proposer, found an already active proposal"
      );
    });

    it("Error: pending proposal", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);

      // Need to stay in the pending state
      await governorBravo.propose(
        [governorBravo],
        [0],
        [""],
        [
          // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
          (
            await governorBravo._setPendingAdmin.populateTransaction(owner)
          ).data!,
        ],
        "Steal governance"
      );

      await expect(propose(governorBravo)).to.be.revertedWith(
        "GovernorBravo::propose: one live proposal per proposer, found an already pending proposal"
      );
    });

    it("Error: at least one action", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);

      await expect(
        propose(governorBravo, [], [], [], "Empty")
      ).to.be.revertedWith("GovernorBravo::propose: must provide actions");
    });

    it("Error: max operations", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
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
      const owner = (await ethers.getSigners())[0];

      const GovernorBravoDelegator = await ethers.getContractFactory(
        "GovernorBravoDelegator"
      );
      const GovernorBravoDelegate = await ethers.getContractFactory(
        "GovernorBravoDelegate"
      );
      const governorBravoDelegate = await GovernorBravoDelegate.deploy();
      let governorBravo = (await GovernorBravoDelegator.deploy(
        timelock,
        comp,
        owner,
        governorBravoDelegate,
        5760,
        100,
        BigInt("1000") * 10n ** 18n
      )) as unknown as GovernorBravoDelegate;
      governorBravo = GovernorBravoDelegate.attach(
        governorBravo
      ) as GovernorBravoDelegate;

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
          otherAccount,
          (await time.latest()) + 1000
        );

        await propose(
          governorBravo.connect(otherAccount),
          [governorBravo],
          [0],
          [
            // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
            (
              await governorBravo._setPendingAdmin.populateTransaction(owner)
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
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await proposeAndQueue(governorBravo);

      const timelockAddress = await governorBravo.timelock();
      const timelock = await ethers.getContractAt("Timelock", timelockAddress);

      await time.increase(await timelock.delay());

      await governorBravo.execute(proposalId);
    });

    it("Error: not queued", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await propose(governorBravo);

      await expect(governorBravo.execute(proposalId)).to.be.revertedWith(
        "GovernorBravo::execute: proposal can only be executed if it is queued"
      );
    });
  });

  describe("Cancel", function () {
    it("Happy Path: proposer cancel", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await proposeAndPass(governorBravo);

      await governorBravo.cancel(proposalId);
    });

    it("Happy Path: below threshold", async function () {
      const { governorBravo, comp, otherAccount } = await loadFixture(
        deployFixtures
      );
      const proposalId = await proposeAndPass(governorBravo);

      await comp.delegate(otherAccount);
      await governorBravo.connect(otherAccount).cancel(proposalId);
    });

    it("Error: above threshold", async function () {
      const { governorBravo, otherAccount } = await loadFixture(deployFixtures);
      const proposalId = await proposeAndPass(governorBravo);

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
        [owner],
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
          otherAccount,
          (await time.latest()) + 1000
        );
        const proposalId = await propose(governorBravo.connect(otherAccount));

        await governorBravo._setWhitelistGuardian(owner);
        await governorBravo.cancel(proposalId);
      });

      it("Error: whitelisted proposer", async function () {
        const { governorBravo, otherAccount } = await loadFixture(
          deployFixtures
        );

        await governorBravo._setWhitelistAccountExpiration(
          otherAccount,
          (await time.latest()) + 1000
        );
        const proposalId = await propose(governorBravo.connect(otherAccount));

        await expect(governorBravo.cancel(proposalId)).to.be.revertedWith(
          "GovernorBravo::cancel: whitelisted proposer"
        );
      });

      it("Error: whitelisted proposer above threshold", async function () {
        const { governorBravo, owner, otherAccount, comp } = await loadFixture(
          deployFixtures
        );

        await governorBravo._setWhitelistAccountExpiration(
          otherAccount,
          (await time.latest()) + 1000
        );
        const proposalId = await propose(governorBravo.connect(otherAccount));
        await comp.transfer(
          otherAccount,
          BigInt("100000") * BigInt("10") ** BigInt("18")
        );
        await comp.connect(otherAccount).delegate(otherAccount);

        await governorBravo._setWhitelistGuardian(owner);
        await expect(governorBravo.cancel(proposalId)).to.be.revertedWith(
          "GovernorBravo::cancel: whitelisted proposer"
        );
      });
    });
  });

  describe("Vote", function () {
    it("With Reason", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);
      const proposalId = await propose(governorBravo);

      await expect(
        governorBravo.castVoteWithReason(proposalId, 0, "We need more info")
      )
        .to.emit(governorBravo, "VoteCast")
        .withArgs(
          owner.address,
          proposalId,
          0,
          BigInt("10000000000000000000000000"),
          "We need more info"
        );
    });

    it("Error: double vote", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await propose(governorBravo);

      await governorBravo.castVote(proposalId, 2);
      expect((await governorBravo.proposals(proposalId)).abstainVotes).to.equal(
        "10000000000000000000000000"
      );
      await expect(governorBravo.castVote(proposalId, 1)).to.be.revertedWith(
        "GovernorBravo::castVoteInternal: voter already voted"
      );
    });

    it("Error: voting closed", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await propose(governorBravo);

      await mine(await governorBravo.votingPeriod());
      await expect(governorBravo.castVote(proposalId, 1)).to.be.revertedWith(
        "GovernorBravo::castVoteInternal: voting is closed"
      );
    });

    it("Error: invalid vote type", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await propose(governorBravo);
      await expect(governorBravo.castVote(proposalId, 3)).to.be.revertedWith(
        "GovernorBravo::castVoteInternal: invalid vote type"
      );
    });

    it("By Sig", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);
      const domain = await getTypedDomain(
        governorBravo,
        (
          await ethers.provider.getNetwork()
        ).chainId
      );

      const proposalId = await propose(governorBravo);

      const sig = await owner.signTypedData(domain, getVoteTypes(), {
        proposalId,
        support: 1,
      });

      const r = "0x" + sig.substring(2, 66);
      const s = "0x" + sig.substring(66, 130);
      const v = "0x" + sig.substring(130, 132);
      await expect(governorBravo.castVoteBySig(proposalId, 1, v, r, s))
        .to.emit(governorBravo, "VoteCast")
        .withArgs(
          owner.address,
          proposalId,
          1,
          BigInt("10000000000000000000000000"),
          ""
        );
    });

    it("Error: invalid sig", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);
      const domain = await getTypedDomain(
        governorBravo,
        (
          await ethers.provider.getNetwork()
        ).chainId
      );

      const proposalId = await propose(governorBravo);

      const sig = await owner.signTypedData(domain, getVoteTypes(), {
        proposalId,
        support: 1,
      });

      const r = "0x" + sig.substring(2, 66);
      const s = "0x" + sig.substring(66, 130);
      const v = "0x00";
      await expect(
        governorBravo.castVoteBySig(proposalId, 1, v, r, s)
      ).to.be.revertedWith("GovernorBravo::castVoteBySig: invalid signature");
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
    const proposalId = await propose(governorBravo);

    await governorBravo.castVote(proposalId, 2);
    expect(await governorBravo.getReceipt(proposalId, owner)).to.deep.equal([
      true,
      2,
      BigInt("10000000000000000000000000"),
    ]);
  });

  describe("State", async function () {
    it("Canceled", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await propose(governorBravo);

      await governorBravo.cancel(proposalId);

      expect(await governorBravo.state(proposalId)).to.equal(
        ProposalState.Canceled
      );
    });

    it("Pending", async function () {
      const { governorBravo, owner } = await loadFixture(deployFixtures);
      await governorBravo.propose([owner], [0], [""], ["0x"], "Test Proposal");

      expect(await governorBravo.state(2)).to.equal(ProposalState.Pending);
    });

    it("Active", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await propose(governorBravo);

      expect(await governorBravo.state(proposalId)).to.equal(
        ProposalState.Active
      );
    });

    it("Defeated: quorum", async function () {
      const { governorBravo, comp, otherAccount } = await loadFixture(
        deployFixtures
      );
      await comp.transfer(otherAccount, BigInt("100000"));
      await comp.connect(otherAccount).delegate(otherAccount);

      const proposalId = await propose(governorBravo);
      await governorBravo.connect(otherAccount).castVote(proposalId, 1);
      await mine(await governorBravo.votingPeriod());

      expect(await governorBravo.state(proposalId)).to.equal(
        ProposalState.Defeated
      );
    });

    it("Defeated: against", async function () {
      const { governorBravo, comp, otherAccount } = await loadFixture(
        deployFixtures
      );
      await comp.transfer(
        otherAccount,
        BigInt("400000") * BigInt("10") ** BigInt("18") // quorum
      );
      await comp.connect(otherAccount).delegate(otherAccount);

      const proposalId = await propose(governorBravo);
      await governorBravo.connect(otherAccount).castVote(proposalId, 1);
      await governorBravo.castVote(proposalId, 0);
      await mine(await governorBravo.votingPeriod());

      expect(await governorBravo.state(proposalId)).to.equal(
        ProposalState.Defeated
      );
    });

    it("Error: invalid state", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      await expect(governorBravo.state(1)).to.be.revertedWith(
        "GovernorBravo::state: invalid proposal id"
      );
    });

    it("Succeeded", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await proposeAndPass(governorBravo);

      expect(await governorBravo.state(proposalId)).to.equal(
        ProposalState.Succeeded
      );
    });

    it("Executed", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await proposeAndQueue(governorBravo);

      const timelockAddress = await governorBravo.timelock();
      const timelock = await ethers.getContractAt("Timelock", timelockAddress);

      await time.increase(await timelock.delay());

      await governorBravo.execute(proposalId);
      expect(await governorBravo.state(proposalId)).to.equal(
        ProposalState.Executed
      );
    });

    it("Expired", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await proposeAndQueue(governorBravo);

      const timelockAddress = await governorBravo.timelock();
      const timelock = await ethers.getContractAt("Timelock", timelockAddress);

      await time.increase(
        (await timelock.GRACE_PERIOD()) + (await timelock.delay())
      );

      expect(await governorBravo.state(proposalId)).to.equal(
        ProposalState.Expired
      );
    });

    it("Queued", async function () {
      const { governorBravo } = await loadFixture(deployFixtures);
      const proposalId = await proposeAndQueue(governorBravo);

      expect(await governorBravo.state(proposalId)).to.equal(
        ProposalState.Queued
      );
    });
  });

  describe("Admin Functions", function () {
    describe("Set Voting Delay", function () {
      it("Admin only", async function () {
        const { governorBravo, otherAccount } = await loadFixture(
          deployFixtures
        );
        await expect(
          governorBravo.connect(otherAccount)._setVotingDelay(2)
        ).to.be.revertedWith("GovernorBravo::_setVotingDelay: admin only");
      });

      it("Invalid voting delay", async function () {
        const { governorBravo } = await loadFixture(deployFixtures);
        await expect(governorBravo._setVotingDelay(0)).to.be.revertedWith(
          "GovernorBravo::_setVotingDelay: invalid voting delay"
        );
        await expect(governorBravo._setVotingDelay(40321)).to.be.revertedWith(
          "GovernorBravo::_setVotingDelay: invalid voting delay"
        );
      });

      it("Happy Path", async function () {
        const { governorBravo } = await loadFixture(deployFixtures);
        await expect(governorBravo._setVotingDelay(2))
          .to.emit(governorBravo, "VotingDelaySet")
          .withArgs(100, 2);
      });
    });

    describe("Set Voting Period", function () {
      it("Admin only", async function () {
        const { governorBravo, otherAccount } = await loadFixture(
          deployFixtures
        );
        await expect(
          governorBravo.connect(otherAccount)._setVotingPeriod(2)
        ).to.be.revertedWith("GovernorBravo::_setVotingPeriod: admin only");
      });

      it("Invalid voting period", async function () {
        const { governorBravo } = await loadFixture(deployFixtures);
        await expect(governorBravo._setVotingPeriod(5759)).to.be.revertedWith(
          "GovernorBravo::_setVotingPeriod: invalid voting period"
        );
        await expect(governorBravo._setVotingPeriod(80641)).to.be.revertedWith(
          "GovernorBravo::_setVotingPeriod: invalid voting period"
        );
      });

      it("Happy Path", async function () {
        const { governorBravo } = await loadFixture(deployFixtures);
        await expect(governorBravo._setVotingPeriod(5761))
          .to.emit(governorBravo, "VotingPeriodSet")
          .withArgs(5760, 5761);
      });
    });

    describe("Set Proposal Threshold", function () {
      it("Admin only", async function () {
        const { governorBravo, otherAccount } = await loadFixture(
          deployFixtures
        );
        await expect(
          governorBravo.connect(otherAccount)._setProposalThreshold(2)
        ).to.be.revertedWith(
          "GovernorBravo::_setProposalThreshold: admin only"
        );
      });

      it("Invalid proposal threshold", async function () {
        const { governorBravo } = await loadFixture(deployFixtures);
        await expect(
          governorBravo._setProposalThreshold(1000)
        ).to.be.revertedWith(
          "GovernorBravo::_setProposalThreshold: invalid proposal threshold"
        );
        await expect(
          governorBravo._setProposalThreshold(100001n * 10n ** 18n)
        ).to.be.revertedWith(
          "GovernorBravo::_setProposalThreshold: invalid proposal threshold"
        );
      });

      it("Happy Path", async function () {
        const { governorBravo } = await loadFixture(deployFixtures);
        await expect(governorBravo._setProposalThreshold(1001n * 10n ** 18n))
          .to.emit(governorBravo, "ProposalThresholdSet")
          .withArgs(1000n * 10n ** 18n, 1001n * 10n ** 18n);
      });
    });
  });
});
