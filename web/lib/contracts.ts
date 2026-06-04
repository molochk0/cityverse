// Адреса контрактов на локальном anvil (детерминированы: деплоер account#0, nonce 0..4
// в порядке Deploy.s.sol). При деплое в тестнет — подменить на реальные.
export const addresses = {
  city: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  place: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  vault: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  market: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
  harberger: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
} as const;

export const placeAbi = [
  { type: "function", name: "totalMinted", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  {
    type: "function",
    name: "ownerOf",
    stateMutability: "view",
    inputs: [{ name: "tokenId", type: "uint256" }],
    outputs: [{ type: "address" }],
  },
  {
    type: "function",
    name: "categoryOf",
    stateMutability: "view",
    inputs: [{ name: "tokenId", type: "uint256" }],
    outputs: [{ type: "uint8" }],
  },
] as const;

export const cityAbi = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

export const vaultAbi = [
  {
    type: "function",
    name: "pendingYield",
    stateMutability: "view",
    inputs: [{ name: "tokenId", type: "uint256" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

// Порядок соответствует enum Category в Place.sol.
export const CATEGORY_LABELS = ["Landmark", "Transit", "Food", "Park"] as const;
