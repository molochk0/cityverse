import { connectorsForWallets } from "@rainbow-me/rainbowkit";
import { injectedWallet } from "@rainbow-me/rainbowkit/wallets";
import { createConfig, http } from "wagmi";
import { foundry } from "wagmi/chains";

// Только injected-кошельки (MetaMask/Rabby и пр. расширения). НЕ подключаем WalletConnect:
// он открывает relay-WebSocket по projectId и без реального id падает с
// "Connection interrupted while trying to subscribe". Для локальной разработки WC не нужен.
const connectors = connectorsForWallets(
  [{ groupName: "Кошельки", wallets: [injectedWallet] }],
  { appName: "Cityverse", projectId: "cityverse-dev" },
);

// foundry = локальный anvil (chainId 31337, RPC http://127.0.0.1:8545).
export const config = createConfig({
  connectors,
  chains: [foundry],
  transports: { [foundry.id]: http() },
  ssr: true,
});
