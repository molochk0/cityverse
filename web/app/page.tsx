"use client";

import { useState } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { formatEther, parseEther } from "viem";
import { useAccount, useReadContract, useReadContracts, useWriteContract, usePublicClient } from "wagmi";
import { addresses, cityAbi, placeAbi, vaultAbi, marketAbi, CATEGORY_LABELS } from "@/lib/contracts";

const ZERO = "0x0000000000000000000000000000000000000000";

function short(addr?: string) {
  return addr ? `${addr.slice(0, 6)}…${addr.slice(-4)}` : "—";
}

function fmt(wei?: bigint) {
  if (wei === undefined) return "—";
  return Number(formatEther(wei)).toFixed(2);
}

type PlaceInfo = {
  id: number;
  cat?: number;
  pending?: bigint;
  listed: boolean;
  price?: bigint;
  ownerDisplay?: string; // бенефициарный владелец (продавец, если в листинге)
  mine: boolean;
};

function PlaceCard({ place, onChanged }: { place: PlaceInfo; onChanged: () => void }) {
  const { writeContractAsync } = useWriteContract();
  const publicClient = usePublicClient();
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [priceInput, setPriceInput] = useState("10");

  async function run(label: string, fn: () => Promise<void>) {
    setErr(null);
    setBusy(label);
    try {
      await fn();
      onChanged();
    } catch (e) {
      setErr((e as { shortMessage?: string }).shortMessage ?? "Ошибка транзакции");
    } finally {
      setBusy(null);
    }
  }

  async function send(params: Parameters<typeof writeContractAsync>[0]) {
    const hash = await writeContractAsync(params);
    await publicClient!.waitForTransactionReceipt({ hash });
  }

  const claim = () =>
    run("Клейм…", () =>
      send({ address: addresses.vault, abi: vaultAbi, functionName: "claim", args: [BigInt(place.id)] }),
    );

  const list = () =>
    run("Approve NFT → листинг…", async () => {
      await send({ address: addresses.place, abi: placeAbi, functionName: "approve", args: [addresses.market, BigInt(place.id)] });
      await send({ address: addresses.market, abi: marketAbi, functionName: "list", args: [BigInt(place.id), parseEther(priceInput || "0")] });
    });

  const buy = () =>
    run("Approve $CITY → покупка…", async () => {
      await send({ address: addresses.city, abi: cityAbi, functionName: "approve", args: [addresses.market, place.price!] });
      await send({ address: addresses.market, abi: marketAbi, functionName: "buy", args: [BigInt(place.id)] });
    });

  const cancel = () =>
    run("Снятие с продажи…", () =>
      send({ address: addresses.market, abi: marketAbi, functionName: "cancel", args: [BigInt(place.id)] }),
    );

  return (
    <div className={place.mine ? "place mine" : "place"}>
      <div>
        <span className="place-id">Место #{place.id}</span>
        <span className={place.mine ? "tag mine" : "tag"}>
          {place.cat !== undefined ? CATEGORY_LABELS[place.cat] : "—"}
        </span>
        {place.listed && <span className="tag">на продаже</span>}
      </div>
      <div className="row">
        <span>Владелец</span>
        <b>{place.mine ? "ты" : short(place.ownerDisplay)}</b>
      </div>
      {place.listed ? (
        <div className="row">
          <span>Цена</span>
          <b>{fmt(place.price)} $CITY</b>
        </div>
      ) : (
        <div className="row">
          <span>Накоплено</span>
          <b>{fmt(place.pending)} $CITY</b>
        </div>
      )}

      {busy ? (
        <div className="muted" style={{ marginTop: 12, fontSize: 13 }}>
          {busy}
        </div>
      ) : (
        <div className="actions">
          {!place.listed && place.mine && (
            <>
              {place.pending !== undefined && place.pending > 0n && (
                <button className="btn" onClick={claim}>
                  Забрать доход
                </button>
              )}
              <div className="list-row">
                <input
                  className="price-input"
                  value={priceInput}
                  onChange={(e) => setPriceInput(e.target.value)}
                  inputMode="decimal"
                  aria-label="Цена в $CITY"
                />
                <button className="btn" onClick={list}>
                  Продать
                </button>
              </div>
            </>
          )}
          {place.listed && place.mine && (
            <button className="btn" onClick={cancel}>
              Снять с продажи
            </button>
          )}
          {place.listed && !place.mine && (
            <button className="btn" onClick={buy}>
              Купить за {fmt(place.price)} $CITY
            </button>
          )}
        </div>
      )}
      {err && <div className="error">{err}</div>}
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

  // По 4 чтения на место: владелец NFT, категория, доход, листинг (продавец+цена). Один multicall.
  const calls = Array.from({ length: count }, (_, i) => [
    { address: addresses.place, abi: placeAbi, functionName: "ownerOf", args: [BigInt(i)] },
    { address: addresses.place, abi: placeAbi, functionName: "categoryOf", args: [BigInt(i)] },
    { address: addresses.vault, abi: vaultAbi, functionName: "pendingYield", args: [BigInt(i)] },
    { address: addresses.market, abi: marketAbi, functionName: "listings", args: [BigInt(i)] },
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
    const owner = placeData?.[i * 4]?.result as string | undefined;
    const cat = placeData?.[i * 4 + 1]?.result as number | undefined;
    const pending = placeData?.[i * 4 + 2]?.result as bigint | undefined;
    const listing = placeData?.[i * 4 + 3]?.result as readonly [string, bigint] | undefined;

    const listed = Boolean(listing && listing[0] !== ZERO);
    const seller = listed ? listing![0] : undefined;
    const price = listed ? listing![1] : undefined;
    const ownerDisplay = listed ? seller : owner;
    const mine = Boolean(address && ownerDisplay && ownerDisplay.toLowerCase() === address.toLowerCase());

    return { id: i, cat, pending, listed, price, ownerDisplay, mine };
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
            <PlaceCard key={p.id} place={p} onChanged={refetchAll} />
          ))}
        </div>
      )}
    </main>
  );
}
