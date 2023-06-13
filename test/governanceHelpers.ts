import {
  loadFixture,
  time,
  mine,
} from "@nomicfoundation/hardhat-network-helpers";
import { GovernorAlpha, GovernorBravoDelegate } from "../typechain-types";
import { BigNumber, BigNumberish, Contract } from "ethers";
import { ethers } from "hardhat";

/**
 * Propose and fast forward to voting period of given governor
 * @returns Proposal id
 */
export async function propose(
  governor: GovernorAlpha | GovernorBravoDelegate,
  targets: (string | Contract)[],
  values: BigNumberish[],
  callDatas: string[],
  description: string
): Promise<bigint> {
  const updateTargets = targets.map((m) =>
    typeof m == "string" ? m : m.address
  );
  const tx = await governor.propose(
    updateTargets,
    values,
    Array(values.length).fill(""),
    callDatas,
    description
  );

  await mine(await governor.votingDelay());

  return ((await tx.wait()).events![0]!.args!.id as BigNumber).toBigInt();
}

export async function proposeAndPass(
  governor: GovernorBravoDelegate,
  targets: (string | Contract)[],
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
  targets: (string | Contract)[],
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
