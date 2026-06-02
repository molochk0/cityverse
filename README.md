# Cityverse

Учебный on-chain проект: игра, где знаковые места реального города токенизированы как NFT —
ими можно владеть, они пассивно приносят внутриигровую валюту, и любое место можно перекупить
силой по механике Harberger Tax.

> Статус: **Фаза 3 — `YieldVault`.** Готовы: `Place` (ERC-721) + seed Воронежа; `CityToken`
> ($CITY, ERC-20); `YieldVault` — пассивный доход мест в $CITY по времени и `claim()`. Все на
> едином `AccessControl`. Фронта пока нет.

## Что это

Гибрид экономики, конфликта и социалки:

- **Place** — ERC-721 NFT, уникальное место города (фиксированное предложение → дефицит).
- **$CITY** — ERC-20 токен, внутриигровая валюта.
- **Yield** — владеешь местом → пассивно копится $CITY, клеймишь когда удобно.
- **Forced buyout** — любое место можно выкупить силой по эскалирующей цене.

Подробный план, игровая петля и дорожная карта — в [PLAN.md](PLAN.md).

## Структура (монорепо)

```
contracts/   # Foundry-проект: смарт-контракты + тесты на Solidity
web/          # Next.js + wagmi + viem + карта (появляется рано, растёт walking-skeleton'ом)
signer/       # Node-сервис для чек-инов (v2)
```

## Стек

Solidity · Foundry · OpenZeppelin · Base Sepolia (тестнет) · Next.js · wagmi/viem · IPFS

## Контракты (Foundry)

Зависимости подключены git-сабмодулями, поэтому после клона их надо подтянуть:

```bash
git clone https://github.com/molochk0/cityverse.git
cd cityverse
git submodule update --init --recursive   # тянет forge-std в contracts/lib

# установить Foundry, если ещё нет:
curl -L https://foundry.paradigm.xyz | bash && foundryup

forge build --root contracts   # компиляция
forge test  --root contracts   # тесты (Place: 7 passed)

# симуляция деплоя + сидинга мест Воронежа (без кошелька, в локальной EVM):
forge script contracts/script/SeedVoronezh.s.sol:SeedVoronezh --root contracts
```

## Безопасность

Это блокчейн-проект: утечка приватного ключа = реальные потерянные деньги.

- Секреты (`.env`, ключи, мнемоники, keystore) **никогда** не коммитятся — см. [.gitignore](.gitignore).
- Для разработки — **отдельный** тестовый кошелёк, не основной.
- Переменные окружения — по шаблону [.env.example](.env.example).

## Лицензия

MIT (учебный проект).
