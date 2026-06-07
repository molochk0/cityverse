"use client";

import { useState } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { formatEther, parseEther } from "viem";
import { useAccount, useReadContract, useReadContracts, useWriteContract, usePublicClient } from "wagmi";
import { addresses, cityAbi, placeAbi, vaultAbi, marketAbi, harbergerAbi, CATEGORY_LABELS } from "@/lib/contracts";

const ZERO = "0x0000000000000000000000000000000000000000";

function short(addr?: string) {
  return addr ? `${addr.slice(0, 6)}…${addr.slice(-4)}` : "—";
}

function fmt(wei?: bigint) {
  if (wei === undefined) return "—";
  return Number(formatEther(wei)).toFixed(2);
}

type Mode = "held" | "listed" | "harberger";

type PlaceInfo = {
  id: number;
  cat?: number;
  pending?: bigint;
  mode: Mode;
  ownerDisplay?: string;
  mine: boolean;
  listPrice?: bigint;
  hbPrice?: bigint;
  hbDeposit?: bigint;
  effPrice?: bigint;
  inDefault?: boolean;
};

function PlaceCard({ place, onChanged }: { place: PlaceInfo; onChanged: () => void }) {
  const { writeContractAsync } = useWriteContract();
  const publicClient = usePublicClient();
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const [sellPrice, setSellPrice] = useState("5");
  const [regPrice, setRegPrice] = useState("20");
  const [regDeposit, setRegDeposit] = useState("10");
  const [fbPrice, setFbPrice] = useState("25");
  const [fbDeposit, setFbDeposit] = useState("10");
  const [topUp, setTopUp] = useState("5");

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

  const id = BigInt(place.id);

  const claim = () =>
    run("Клейм…", () => send({ address: addresses.vault, abi: vaultAbi, functionName: "claim", args: [id] }));

  const list = () =>
    run("Approve NFT → листинг…", async () => {
      await send({ address: addresses.place, abi: placeAbi, functionName: "approve", args: [addresses.market, id] });
      await send({ address: addresses.market, abi: marketAbi, functionName: "list", args: [id, parseEther(sellPrice || "0")] });
    });

  const buy = () =>
    run("Approve $CITY → покупка…", async () => {
      await send({ address: addresses.city, abi: cityAbi, functionName: "approve", args: [addresses.market, place.listPrice!] });
      await send({ address: addresses.market, abi: marketAbi, functionName: "buy", args: [id] });
    });

  const cancel = () =>
    run("Снятие с продажи…", () => send({ address: addresses.market, abi: marketAbi, functionName: "cancel", args: [id] }));

  const register = () =>
    run("Approve NFT → approve $CITY → Harberger…", async () => {
      const deposit = parseEther(regDeposit || "0");
      await send({ address: addresses.place, abi: placeAbi, functionName: "approve", args: [addresses.harberger, id] });
      await send({ address: addresses.city, abi: cityAbi, functionName: "approve", args: [addresses.harberger, deposit] });
      await send({ address: addresses.harberger, abi: harbergerAbi, functionName: "register", args: [id, parseEther(regPrice || "0"), deposit] });
    });

  const forceBuy = () =>
    run("Approve $CITY → выкуп…", async () => {
      const newDeposit = parseEther(fbDeposit || "0");
      await send({ address: addresses.city, abi: cityAbi, functionName: "approve", args: [addresses.harberger, (place.effPrice ?? 0n) + newDeposit] });
      await send({ address: addresses.harberger, abi: harbergerAbi, functionName: "forceBuy", args: [id, parseEther(fbPrice || "0"), newDeposit] });
    });

  const addDeposit = () =>
    run("Approve $CITY → пополнение…", async () => {
      const amount = parseEther(topUp || "0");
      await send({ address: addresses.city, abi: cityAbi, functionName: "approve", args: [addresses.harberger, amount] });
      await send({ address: addresses.harberger, abi: harbergerAbi, functionName: "addDeposit", args: [id, amount] });
    });

  const withdraw = () =>
    run("Вывод из Harberger…", () => send({ address: addresses.harberger, abi: harbergerAbi, functionName: "withdraw", args: [id] }));

  return (
    <div className={place.mine ? "place mine" : "place"}>
      <div>
        <span className="place-id">Место #{place.id}</span>
        <span className={place.mine ? "tag mine" : "tag"}>
          {place.cat !== undefined ? CATEGORY_LABELS[place.cat] : "—"}
        </span>
        {place.mode === "listed" && <span className="tag">на продаже</span>}
        {place.mode === "harberger" && <span className="tag">Harberger</span>}
        {place.inDefault && <span className="tag default">дефолт</span>}
      </div>

      <div className="row">
        <span>Владелец</span>
        <b>{place.mine ? "ты" : short(place.ownerDisplay)}</b>
      </div>

      {place.mode === "held" && (
        <div className="row">
          <span>Накоплено</span>
          <b>{fmt(place.pending)} $CITY</b>
        </div>
      )}
      {place.mode === "listed" && (
        <div className="row">
          <span>Цена</span>
          <b>{fmt(place.listPrice)} $CITY</b>
        </div>
      )}
      {place.mode === "harberger" && (
        <>
          <div className="row">
            <span>Самооценка</span>
            <b>{fmt(place.hbPrice)} $CITY</b>
          </div>
          <div className="row">
            <span>Депозит</span>
            <b>{fmt(place.hbDeposit)} $CITY</b>
          </div>
          <div className="row">
            <span>Выкуп сейчас</span>
            <b>{place.inDefault ? "0 (дефолт)" : `${fmt(place.effPrice)} $CITY`}</b>
          </div>
        </>
      )}

      {busy ? (
        <div className="muted" style={{ marginTop: 12, fontSize: 13 }}>
          {busy}
        </div>
      ) : (
        <div className="actions">
          {place.mode === "held" && place.mine && (
            <>
              {place.pending !== undefined && place.pending > 0n && (
                <button className="btn" onClick={claim}>
                  Забрать доход
                </button>
              )}
              <div className="list-row">
                <input className="price-input" value={sellPrice} onChange={(e) => setSellPrice(e.target.value)} inputMode="decimal" aria-label="Цена продажи" />
                <button className="btn" onClick={list}>
                  Продать
                </button>
              </div>
              <div className="list-row">
                <input className="price-input" value={regPrice} onChange={(e) => setRegPrice(e.target.value)} inputMode="decimal" aria-label="Самооценка" />
                <input className="price-input" value={regDeposit} onChange={(e) => setRegDeposit(e.target.value)} inputMode="decimal" aria-label="Депозит" />
                <button className="btn" onClick={register}>
                  Под Harberger
                </button>
              </div>
            </>
          )}

          {place.mode === "listed" && place.mine && (
            <button className="btn" onClick={cancel}>
              Снять с продажи
            </button>
          )}
          {place.mode === "listed" && !place.mine && (
            <button className="btn" onClick={buy}>
              Купить за {fmt(place.listPrice)} $CITY
            </button>
          )}

          {place.mode === "harberger" && place.mine && (
            <>
              <div className="list-row">
                <input className="price-input" value={topUp} onChange={(e) => setTopUp(e.target.value)} inputMode="decimal" aria-label="Пополнить депозит" />
                <button className="btn" onClick={addDeposit}>
                  Пополнить
                </button>
              </div>
              <button className="btn" onClick={withdraw} disabled={place.inDefault}>
                {place.inDefault ? "В дефолте — нельзя вывести" : "Забрать из Harberger"}
              </button>
            </>
          )}
          {place.mode === "harberger" && !place.mine && (
            <div className="list-row">
              <input className="price-input" value={fbPrice} onChange={(e) => setFbPrice(e.target.value)} inputMode="decimal" aria-label="Новая самооценка" />
              <input className="price-input" value={fbDeposit} onChange={(e) => setFbDeposit(e.target.value)} inputMode="decimal" aria-label="Новый депозит" />
              <button className="btn" onClick={forceBuy}>
                Выкупить за {place.inDefault ? "0" : fmt(place.effPrice)}
              </button>
            </div>
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

  // По 7 чтений на место: владелец NFT, категория, доход, листинг, parcel(Harberger),
  // effectivePrice, inDefault. Один multicall.
  const calls = Array.from({ length: count }, (_, i) => {
    const tid = BigInt(i);
    return [
      { address: addresses.place, abi: placeAbi, functionName: "ownerOf", args: [tid] },
      { address: addresses.place, abi: placeAbi, functionName: "categoryOf", args: [tid] },
      { address: addresses.vault, abi: vaultAbi, functionName: "pendingYield", args: [tid] },
      { address: addresses.market, abi: marketAbi, functionName: "listings", args: [tid] },
      { address: addresses.harberger, abi: harbergerAbi, functionName: "parcels", args: [tid] },
      { address: addresses.harberger, abi: harbergerAbi, functionName: "effectivePrice", args: [tid] },
      { address: addresses.harberger, abi: harbergerAbi, functionName: "inDefault", args: [tid] },
    ];
  }).flat();

  const { data: placeData, refetch: refetchPlaces } = useReadContracts({
    contracts: calls,
    query: { enabled: count > 0 },
  });

  const refetchAll = () => {
    refetchPlaces();
    refetchBalance();
  };

  const places: PlaceInfo[] = Array.from({ length: count }, (_, i) => {
    const base = i * 7;
    const owner = placeData?.[base]?.result as string | undefined;
    const cat = placeData?.[base + 1]?.result as number | undefined;
    const pending = placeData?.[base + 2]?.result as bigint | undefined;
    const listing = placeData?.[base + 3]?.result as readonly [string, bigint] | undefined;
    const parcel = placeData?.[base + 4]?.result as readonly [string, bigint, bigint, bigint] | undefined;
    const effPrice = placeData?.[base + 5]?.result as bigint | undefined;
    const inDefault = placeData?.[base + 6]?.result as boolean | undefined;

    const inHarberger = Boolean(parcel && parcel[0] !== ZERO);
    const listed = Boolean(listing && listing[0] !== ZERO);

    let mode: Mode = "held";
    let ownerDisplay = owner;
    if (inHarberger) {
      mode = "harberger";
      ownerDisplay = parcel![0];
    } else if (listed) {
      mode = "listed";
      ownerDisplay = listing![0];
    }

    const mine = Boolean(address && ownerDisplay && ownerDisplay.toLowerCase() === address.toLowerCase());

    return {
      id: i,
      cat,
      pending,
      mode,
      ownerDisplay,
      mine,
      listPrice: listed ? listing![1] : undefined,
      hbPrice: inHarberger ? parcel![1] : undefined,
      hbDeposit: inHarberger ? parcel![2] : undefined,
      effPrice,
      inDefault: inHarberger ? inDefault : undefined,
    };
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
