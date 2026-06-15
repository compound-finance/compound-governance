import { Addressable } from "ethers";

export async function getTypedDomainComp(
  address: Addressable,
  chainId: bigint,
) {
  return {
    name: "Compound",
    chainId: chainId.toString(),
    verifyingContract: await address.getAddress(),
  };
}

export function getDelegationTypes() {
  return {
    Delegation: [
      { name: "delegatee", type: "address" },
      { name: "nonce", type: "uint256" },
      { name: "expiry", type: "uint256" },
    ],
  };
}
