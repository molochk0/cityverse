# Деплой в Base Sepolia (тестнет)

Гайд по выкатке контрактов Cityverse в публичный тестнет **Base Sepolia**, чтобы играть с друзьями.

> ⚠️ **Безопасность.** Используем **отдельный** кошелёк только для разработки — не основной.
> Приватный ключ **не** кладём в `.env` и **не** коммитим. Храним его в зашифрованном
> **Foundry keystore** (с паролем). Боты сканируют GitHub в реальном времени — утечка ключа = потеря средств.

---

## 0. Что понадобится (твоя часть)

1. **Кошелёк-расширение** (Rabby или MetaMask) — заведи в нём **новый** аккаунт под разработку.
2. **Сеть Base Sepolia** в кошельке:
   - RPC: `https://sepolia.base.org`
   - Chain ID: `84532`
   - Символ: `ETH`
   - Explorer: `https://sepolia.basescan.org`
3. **Тест-ETH** из faucet (нужен на газ, немного):
   - https://www.alchemy.com/faucets/base-sepolia, или
   - Coinbase / Superchain faucet (любой для Base Sepolia).
4. **Basescan API key** (бесплатно, для верификации контрактов): зарегистрируйся на
   https://basescan.org → API Keys → создай ключ.

---

## 1. Положить ключ в keystore (без `.env`)

Экспортируй приватный ключ дев-аккаунта из кошелька и импортируй в зашифрованный keystore Foundry:

```bash
cast wallet import cityverse-deployer --interactive
# вставь приватный ключ, задай пароль
```

Ключ зашифрован и лежит в `~/.foundry/keystores/cityverse-deployer` — в репозиторий ничего не попадает.
Проверить адрес:

```bash
cast wallet address --account cityverse-deployer
```

Это и есть твой **deployer/admin/treasury** — на него уйдут все засеянные места.

---

## 2. Задеплоить + верифицировать

Из корня репозитория (подставь свой адрес из шага 1 в `--sender`):

```bash
export BASESCAN_API_KEY=<твой_ключ_basescan>

forge script contracts/script/Deploy.s.sol:Deploy \
  --root contracts \
  --rpc-url base_sepolia \
  --account cityverse-deployer \
  --sender 0xТВОЙ_АДРЕС \
  --broadcast \
  --verify
```

Forge спросит пароль от keystore. Деплой развернёт все 5 контрактов, свяжет роли, засеет места
Воронежа и (с `--verify`) выложит исходники на Basescan.

---

## 3. Забрать адреса контрактов

Адреса печатаются в конце скрипта (CityToken / Place / YieldVault / Marketplace / Harberger), а также
лежат в `contracts/broadcast/Deploy.s.sol/84532/run-latest.json`.

Скопируй эти 5 адресов — **пришли мне**, и я обновлю фронт (подменю anvil-адреса на тестнет и
добавлю сеть Base Sepolia в кошелёк-конфиг). После этого фронт будет работать с публичной сетью,
и можно звать друзей.

---

## Частые вопросы

- **Газа не хватает / транзакция падает** — налей ещё тест-ETH из faucet.
- **Верификация не прошла** — проверь `BASESCAN_API_KEY`; можно доверифицировать позже командой
  `forge verify-contract` (адреса есть в `run-latest.json`).
- **Rate limit на публичном RPC** — замени `base_sepolia` в `contracts/foundry.toml` на свой
  Alchemy/Infura URL для Base Sepolia.
- **Друзья играют** — каждому нужен кошелёк на сети Base Sepolia и немного тест-ETH из faucet;
  `$CITY` они получат в игре (claim дохода с купленных мест).
