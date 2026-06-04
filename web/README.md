# Cityverse — фронтенд

Next.js + wagmi + viem + RainbowKit. Пока read-only: подключение кошелька, список мест
(владелец, категория, накопленный доход) и баланс $CITY. Читает контракты с локального `anvil`.

## Запуск локально

Нужно 3 терминала.

**1. Локальная сеть (anvil):**

```bash
anvil
```

**2. Деплой контрактов в anvil** (из корня репо; ключ — дефолтный тестовый account#0 anvil, не секрет):

```bash
forge script contracts/script/Deploy.s.sol:Deploy \
  --root contracts \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

Адреса контрактов детерминированы (account#0, nonce 0..4) и уже прописаны в `lib/contracts.ts`.

**3. Фронтенд:**

```bash
cd web
cp .env.example .env.local   # projectId-плейсхолдер; для MetaMask/Rabby хватает
npm install
npm run dev
```

Открой http://localhost:3000.

## Кошелёк

- Поставь MetaMask или Rabby.
- Добавь сеть: RPC `http://127.0.0.1:8545`, chainId `31337`.
- Импортируй тестовый аккаунт anvil (он печатает приватные ключи при старте) — у account#0
  на руках все засеянные места, у остальных — нет, удобно проверять «мои/чужие».

## Что дальше

- Карта Воронежа (Leaflet) — после добавления координат/метаданных мест.
- Действия из UI: claim дохода, list/buy на маркете, forced buyout.
- Деплой в Base Sepolia + подмена адресов.
