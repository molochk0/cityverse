"use client";

import { useEffect } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { formatEther } from "viem";
import { useAccount, useReadContract, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { addresses, cityAbi, placeAbi, vaultAbi, CATEGORY_LABELS } from "@/lib/contracts";

function short(addr?: string) {
  return addr ? `${addr.slice(0, 6)}…${addr.slice(-4)}` : "—";
}

function fmt(wei?: bigint) {
  if (wei === undefined) return "—";
  return Number(formatEther(wei)).toFixed(2);
}

type PlaceInfo = {
  id: number;
  owner?: string;
  cat?: number;
  pending?: bigint;
  mine: boolean;
};

function PlaceCard({ place, onClaimed }: { place: PlaceInfo; onClaimed: () => void }) {
  const { writeContract, data: hash, isPending, error, reset } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  useEffect(() => {
    if (isSuccess) {
      onClaimed();
      reset();
    }
  }, [isSuccess, onClaimed, reset]);

  const canClaim = place.mine && place.pending !== undefined && place.pending > 0n;

  return (
    <div className={place.mine ? "place mine" : "place"}>
      <div>
        <span className="place-id">Место #{place.id}</span>
        <span className={place.mine ? "tag mine" : "tag"}>
          {place.cat !== undefined ? CATEGORY_LABELS[place.cat] : "—"}
        </span>
      </div>
      <div className="row">
        <span>Владелец</span>
        <b>{place.mine ? "ты" : short(place.owner)}</b>
      </div>
      <div className="row">
        <span>Накоплено</span>
        <b>{fmt(place.pending)} $CITY</b>
      </div>

      {canClaim && (
        <button
          className="btn"
          disabled={isPending || confirming}
          onClick={() =>
            writeContract({
              address: addresses.vault,
              abi: vaultAbi,
              functionName: "claim",
              args: [BigInt(place.id)],
            })
          }
        >
          {isPending ? "Подтверди в кошельке…" : confirming ? "Майнится…" : "Забрать доход"}
        </button>
      )}
      {error && <div className="error">{(error as { shortMessage?: string }).shortMessage ?? "Ошибка транзакции"}</div>}
    </div>
  );
}

export default function Home() {
  const { address } = useAccount();

  const { data: balance, refetch: refetchBalance } = useReadContract({
    address: addresses.city,
    abi: cityAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) },
  });

  const { data: total } = useReadContract({
    address: addresses.place,
    abi: placeAbi,
    functionName: "totalMinted",
  });

  const count = total ? Number(total) : 0;

  // По 3 чтения на место: владелец, категория, накопленный доход. Один multicall.
  const calls = Array.from({ length: count }, (_, i) => [
    { address: addresses.place, abi: placeAbi, functionName: "ownerOf", args: [BigInt(i)] },
    { address: addresses.place, abi: placeAbi, functionName: "categoryOf", args: [BigInt(i)] },
    { address: addresses.vault, abi: vaultAbi, functionName: "pendingYield", args: [BigInt(i)] },
  ]).flat();

  const { data: placeData, refetch: refetchPlaces } = useReadContracts({
    contracts: calls,
    query: { enabled: count > 0 },
  });

  const refetchAll = () => {
    refetchPlaces();
    refetchBalance();
  };

  const places: PlaceInfo[] = Array.from({ length: count }, (_, i) => {
    const owner = placeData?.[i * 3]?.result as string | undefined;
    const cat = placeData?.[i * 3 + 1]?.result as number | undefined;
    const pending = placeData?.[i * 3 + 2]?.result as bigint | undefined;
    const mine = Boolean(address && owner && owner.toLowerCase() === address.toLowerCase());
    return { id: i, owner, cat, pending, mine };
  });

  return (
    <main className="container">
      <header>
        <h1>🏙️ Cityverse</h1>
        <ConnectButton />
      </header>
      <p className="subtitle">Места Воронежа как NFT — владей, зарабатывай $CITY, перекупай.</p>

      {address ? (
        <div className="balance">
          Баланс: <strong>{fmt(balance as bigint | undefined)} $CITY</strong>
        </div>
      ) : (
        <div className="balance muted">Подключи кошелёк, чтобы увидеть баланс и свои места.</div>
      )}

      {count === 0 ? (
        <p className="muted">
          Мест не найдено. Запущен ли anvil и задеплоены ли контракты? (см. web/README.md)
        </p>
      ) : (
        <div className="grid">
          {places.map((p) => (
            <PlaceCard key={p.id} place={p} onClaimed={refetchAll} />
          ))}
        </div>
      )}
    </main>
  );
}
