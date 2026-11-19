# SUBMISSION — FlashGuard (DoraHacks-ready)

**Hackathon:** Reactive Omni Buildathon — https://dorahacks.io/hackathon/reactive-omni-buildathon
**Track:** Every Second Counts (1st place: $2,000 in REACT)
**Deadline:** 5 December 2026 (treat as 23:59 UTC / 6 Dec 06:59 WIB until confirmed on DoraHacks)
**Status:** ⏳ DEPLOYMENT PENDING — code complete + fully tested; testnet deployment
awaits faucet funding of the deployer (free, ~10 min). Fill the placeholders below
after `./scripts/deploy_all.sh` + `./scripts/demo.sh`.

---

## Project name

**FlashGuard — Cross-Chain Stop-Loss in ~1 Second**

## One-liner

A stop-loss that lives on-chain: a price event on Unichain Sepolia triggers a
reactive contract on Lasna, which fires a callback that exits your position on
Base Sepolia — no bot, no keeper, full-loop latency measured on-chain.

## Description (for the DoraHacks form)

Stop-losses on DEXes today depend on off-chain keepers: bots that watch prices
and submit transactions. They go down, they get frontrun, and they charge rent
for watching. FlashGuard moves the whole reaction on-chain with Reactive Network.

A user deposits mETH into the ProtectedVault on Base Sepolia and registers a
stop-loss (e.g. $2,500). A price feed on Unichain Sepolia emits `PriceUpdated`
events. The FlashGuard reactive contract on Reactive Lasna subscribes to those
events; the moment a price prints at or below the threshold, `react()` requests
a callback to the vault, which exits the user's full position into mUSDC at the
trigger price. The vault records the full-loop latency on-chain — origin event
timestamp to callback execution — so the speed claim is verifiable, not asserted.

Built with the Omni stack: `AbstractReactive` + `requestCallbackV_1_0` on Lasna,
`AbstractCallback` with proxy + injected-sender authentication on Base Sepolia.
16 Foundry tests pass, including a full-loop simulation. Testnets only; the price
feed is a documented demo oracle with a production path to Chainlink/TWAP.

## Links

- **Repo (public):** https://github.com/darendrarp/flashguard-reactive-omni
- **Demo dashboard:** `app/index.html` in the repo (static page, reads live
  testnet RPCs) — deploy to GitHub Pages / Vercel, or serve locally.
- **Demo video (<3 min):** TODO — record from `VIDEO_SCRIPT.md` after deployment.

## Deployed contracts (fill after deployment)

| Contract | Chain | Address |
|---|---|---|
| PriceFeed | Unichain Sepolia (1301) | `TODO` |
| FlashGuardReactive | Reactive Lasna (5318007) | `TODO` |
| ProtectedVault | Base Sepolia (84532) | `TODO` |
| mETH / mUSDC | Base Sepolia (84532) | `TODO` / `TODO` |

## Full-loop transaction hashes (fill after demo)

| Leg | Chain | Tx hash |
|---|---|---|
| Price post $2,400 (origin event) | Unichain Sepolia | `TODO` |
| `react()` trigger | Reactive Lasna | `TODO` |
| Callback execution / exit | Base Sepolia | `TODO` |

## Measured latency (fill after demo)

- Full-loop latency (on-chain, `lastLoopLatencySeconds`): `TODO` s
- Average over N exits: `TODO` s
- Cross-check: `node scripts/measure_latency.js`

## How to verify (for judges)

1. `git clone https://github.com/darendrarp/flashguard-reactive-omni && forge test` — 16/16 pass.
2. Open the dashboard (`app/index.html`) — live price, trigger count, exits, latencies.
3. Check the three explorers with the hashes above:
   Unichain Sepolia https://sepolia.uniscan.xyz,
   Lasna https://lasna.reactscan.net,
   Base Sepolia https://sepolia.basescan.org.
4. Re-run the demo: `./scripts/demo.sh` (needs a funded testnet key; see README).

## What the user still needs to do

1. Fund the deployer address (in `DEPLOYER.md`, testnet only) with free testnet
   ETH from any Base Sepolia / Unichain Sepolia faucet (~0.05 ETH each), then
   run `./scripts/deploy_all.sh` + `./scripts/demo.sh` (or ask Paijo to run them
   once funded) and fill the TODOs above.
2. Record the <3 min demo video from `VIDEO_SCRIPT.md`.
3. Register + submit on DoraHacks (user decision; no submission made by the agent).
