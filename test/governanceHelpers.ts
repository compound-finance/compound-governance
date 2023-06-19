import { time, mine } from "@nomicfoundation/hardhat-network-helpers";
import { BigNumberish, Contract } from "ethers";
import { ethers } from "hardhat";
import { Addressable, EventLog } from "ethers";
import {
  Comp,
  GovernorAlpha,
  GovernorBravoDelegate,
  Timelock,
} from "../typechain-types";

/**
 * Propose and fast forward to voting period of given governor
 * @returns Proposal id
 */
export async function propose(
  governor: GovernorAlpha | GovernorBravoDelegate,
  targets: (string | Addressable)[],
  values: BigNumberish[],
  callDatas: string[],
  description: string
): Promise<bigint> {
  const updateTargets = targets.map(async (m) => {
    if (typeof m == "string") {
      return m;
    }
    return await m.getAddress();
  });
  const tx = await governor.propose(
    updateTargets,
    values,
    Array(values.length).fill(""),
    callDatas,
    description
  );

  await mine(await governor.votingDelay());

  return ((await tx.wait())!.logs[0] as EventLog).args[0];
}

export async function proposeAndPass(
  governor: GovernorBravoDelegate,
  targets: (string | Addressable)[],
  values: BigNumberish[],
  callDatas: string[],
  description: string
): Promise<bigint> {
  const proposalId = await propose(
    governor,
    targets,
    values,
    callDatas,
    description
  );
  await governor.castVote(proposalId, 1);

  await mine(await governor.votingPeriod());

  return proposalId;
}

export async function proposeAndQueue(
  governor: GovernorBravoDelegate,
  targets: (string | Addressable)[],
  values: BigNumberish[],
  callDatas: string[],
  description: string
): Promise<bigint> {
  const proposalId = await proposeAndPass(
    governor,
    targets,
    values,
    callDatas,
    description
  );

  await governor.queue(proposalId);

  return proposalId;
}

export async function setupGovernorAlpha() {
  const [owner] = await ethers.getSigners();

  const Timelock = await ethers.getContractFactory("Timelock");
  const Comp = await ethers.getContractFactory("Comp");
  const GovernorAlpha = await ethers.getContractFactory(
    "contracts/GovernorAlpha.sol:GovernorAlpha"
  );

  const timelock = await Timelock.deploy(await owner.getAddress(), 172800);
  const comp = await Comp.deploy(await owner.getAddress());
  const governorAlpha: GovernorAlpha = (await GovernorAlpha.deploy(
    await timelock.getAddress(),
    await comp.getAddress(),
    await owner.getAddress()
  )) as unknown as GovernorAlpha;

  const eta =
    BigInt(await time.latest()) +
    100n +
    (await timelock.MINIMUM_DELAY());
  const txData = (
    await timelock.setPendingAdmin.populateTransaction(
      governorAlpha.getAddress()
    )
  ).data!;
  await timelock.queueTransaction(timelock.getAddress(), 0, "", txData, eta);
  await time.increaseTo(eta);
  await timelock.executeTransaction(timelock.getAddress(), 0, "", txData, eta);
  await governorAlpha.__acceptAdmin();

  return { governorAlpha, timelock, comp };
}

export async function setupGovernorBravo(
  timelock: Timelock,
  comp: Comp,
  governorAlpha: GovernorAlpha
) {
  const [owner, otherAccount] = await ethers.getSigners();
  const GovernorBravoDelegator = await ethers.getContractFactory(
    "GovernorBravoDelegator"
  );
  const GovernorBravoDelegate = await ethers.getContractFactory(
    "GovernorBravoDelegate"
  );

  const governorBravoDelegate = await GovernorBravoDelegate.deploy();
  let governorBravo: GovernorBravoDelegate =
    (await GovernorBravoDelegator.deploy(
      timelock.getAddress(),
      comp.getAddress(),
      owner.getAddress(),
      governorBravoDelegate.getAddress(),
      5760,
      100,
      BigInt("1000") * 10n ** 18n
    )) as unknown as GovernorBravoDelegate;
  await comp.delegate(owner.getAddress());
  const eta =
    BigInt(await time.latest()) +
    100n +
    (await timelock.MINIMUM_DELAY());
  const txData = (
    await timelock.setPendingAdmin.populateTransaction(
      governorBravo.getAddress()
    )
  ).data!;
  await propose(
    governorAlpha,
    [await timelock.getAddress()],
    [0n],
    [txData],
    "Transfer admin for bravo"
  );
  await governorAlpha.castVote(await governorAlpha.votingDelay(), true);
  await mine(await governorAlpha.votingPeriod());
  await governorAlpha.queue(1);
  await time.increase(await timelock.MINIMUM_DELAY());
  await governorAlpha.execute(1);
  governorBravo = GovernorBravoDelegate.attach(await governorBravo.getAddress()) as GovernorBravoDelegate;
  await governorBravo._initiate(governorAlpha.getAddress());

  return { governorBravo };
}
