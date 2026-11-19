# ⚡ FlashGuard — Cross-Chain Stop-Loss in ~1 Second

**Reactive Omni Buildathon · Track: Every Second Counts · $2,000 first place**

A price event on **Unichain Sepolia** is watched by a reactive contract on **Reactive
Lasna**. The moment a stop-loss threshold breaks, the reactive contract fires a
callback to the **ProtectedVault on Base Sepolia**, which exits the user's position
into stablecoins — with the full-loop latency measured **on-chain**, from the origin
event's timestamp to the callback's execution block.

No bot. No keeper. No off-chain signer. The reaction is on-chain.

## The loop (live on testnets)

```
PriceFeed                  FlashGuardReactive           ProtectedVault
Unichain Sepolia (1301)    Reactive Lasna (5318007)     Base Sepolia (84532)
┌──────────────────┐       ┌──────────────────────┐     ┌────────────────────┐
│ postPrice()      │ PriceUpdated event │ react(): check orders │     │ executeStopLoss()  │
│  → PriceUpdated ─┼──────► │  price <= threshold? │     │  exit full position│
│  (asset, price)  │       │  → requestCallback   │────►│  → mUSDC at trigger│
└──────────────────┘       └──────────────────────┘     │  price, record     │
                                                        │  loop latency      │
                                                        └────────────────────┘
```

## Why this fits the track

The organizers' brief for *Every Second Counts* names stop-loss orders explicitly
and says the strongest entries show **latency numbers measured across the full
loop, not just one leg**. FlashGuard does exactly that:

- **Execution is the whole product.** Every exit is a real reactive transaction
  on Lasna plus a real cross-chain callback on Base Sepolia — visible on three
  explorers, with transaction hashes in `deployments/` and `SUBMISSION.md`.
- **Latency is measured, not claimed.** The vault records full-loop latency
  on-chain (`lastLoopLatencySeconds`, `averageLoopLatencySeconds`), and
  `scripts/measure_latency.js` cross-checks it from receipts.
- **Reactive does the real work.** Threshold evaluation, trigger dedup, and the
  callback decision live in the reactive contract. The vault only executes
  callbacks authenticated by the proxy + the injected sender address.
- **Honest scope.** The price feed is a documented demo oracle (production path:
  Chainlink feed or Uniswap TWAP reader); tokens are testnet mocks. Nothing here
  pretends to be mainnet-ready DeFi.

## Contracts

| Contract | Chain | Role |
|---|---|---|
| `src/PriceFeed.sol` | Unichain Sepolia (1301) | Origin. Updater posts prices (8 decimals, Chainlink style); emits `PriceUpdated`. |
| `src/FlashGuardReactive.sol` | Reactive Lasna (5318007) | Subscribes to `PriceUpdated`; on threshold breach requests a callback to the vault. |
| `src/ProtectedVault.sol` | Base Sepolia (84532) | Destination. Holds mETH deposits; authenticated callback exits the full position into mUSDC at the trigger price and records loop latency. |
| `src/MockToken.sol` | Base Sepolia (84532) | Minimal ERC-20: mETH (18 dec) + mUSDC (6 dec) for the demo. |

Key protocol facts (from [Reactive docs](https://dev.reactive.network)):

- System contract (Lasna + mainnet): `0x8888888888888888888888888888888888888888`
- Base Sepolia callback proxy: `0x476F44b11F5C942c58f4c8E3d0300E5710743585`
- Callback payloads reserve the first argument as an `address` placeholder — the
  proxy injects the reactive contract's address there for authentication.
- Callbacks are billed to the **recipient** in the destination chain's native
  token; reactive transactions are billed to the reactive contract in lREACT.
  Both contracts must stay funded, or they stop receiving transactions.
- All time logic uses **timestamps, never block counts** (Base Sepolia: 200ms blocks).

## Quickstart

```bash
forge build
forge test   # 16 tests, incl. a full-loop simulation (feed -> react -> callback -> exit)
```

## Deployment (testnets only)

```bash
cp .env.example .env   # fill PRIVATE_KEY with a fresh TESTNET-ONLY key
./scripts/deploy_all.sh
```

Deployment order (per Reactive docs): PriceFeed → Reactive (subscribes) → Vault
(needs reactive address) → `setVault` on the reactive contract. Addresses are
saved to `deployments/testnet.json`.

Funding the deployer (all free, testnet only):

- **Base Sepolia + Unichain Sepolia ETH:** any public testnet faucet
  (e.g. Alchemy, QuickNode, or the Superchain faucet). ~0.05 ETH per chain is plenty.
- **Lasna lREACT:** send Sepolia ETH to the faucet contract — 1 ETH → 100 lREACT
  (Base Sepolia faucet: `0x2afaFD298b23b62760711756088F75B7409f5967`, max 5 ETH/tx).
  0.01 ETH → 1 lREACT is enough for many demo runs:
  `cast send 0x2afaFD298b23b62760711756088F75B7409f5967 --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY "request(address)" $DEPLOYER --value 0.01ether`

## Demo

```bash
./scripts/demo.sh   # deposit -> order at $2,500 -> post $3,000 (no-op) -> post $2,400 (fires)
node scripts/measure_latency.js   # per-exit latency breakdown from receipts
```

The demo posts $3,000 first to prove the guard does nothing above the threshold,
then $2,400 to trigger the exit. The vault pays out `deposit × trigger price`
in mUSDC (e.g. 1 mETH at $2,400 → 2,400 mUSDC).

## Dashboard

`app/index.html` is a dependency-free single page that reads live state from the
three public testnet RPCs (price, triggers, exits, latencies). Serve the repo root
so it can auto-load `deployments/testnet.json`, or paste addresses manually:

```bash
python3 -m http.server 8000   # then open http://localhost:8000/app/
```

## Tests

16 Foundry tests, all passing (`forge test`):

- PriceFeed posting, access control, events
- Reactive subscription on deploy, order register/cancel
- `react()`: ignores above-threshold / wrong-topic / wrong-contract logs, triggers
  exactly once at or below threshold, rejects non-system callers, no-ops without a vault
- Vault: deposit/withdraw, rejects direct calls and wrong callback senders
- **Full loop:** simulated origin event → `react()` → callback delivery → exit
  payout math (2 mETH @ $2,400 = 4,800 mUSDC) + on-chain latency recording;
  per-user threshold independence

The system contract and callback proxy are mocked in tests (etched at the real
`0x8888…` address) — see `test/FlashGuard.t.sol`.

## Submission

See [`SUBMISSION.md`](SUBMISSION.md) (DoraHacks-ready text, links, and the
transaction-hash table) and [`VIDEO_SCRIPT.md`](VIDEO_SCRIPT.md) (under-3-minute
demo video script + shot list).

## License

MIT — see `LICENSE`. Built during the Reactive Omni Buildathon window
(5 Nov – 5 Dec 2026). Reactive base contracts come from
[`Reactive-Network/reactive-lib-omni`](https://github.com/Reactive-Network/reactive-lib-omni)
(dependency, not part of this submission).
