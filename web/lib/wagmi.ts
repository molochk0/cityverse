import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { foundry } from "wagmi/chains";

// foundry = локальный anvil (chainId 31337, RPC http://127.0.0.1:8545), с предзадеплоенным Multicall3.
export const config = getDefaultConfig({
  appName: "Cityverse",
  projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID ?? "cityverse-dev",
  chains: [foundry],
  ssr: true,
});
