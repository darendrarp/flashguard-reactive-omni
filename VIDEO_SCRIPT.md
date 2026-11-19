# VIDEO SCRIPT — FlashGuard demo (target: 2:30, hard limit <3:00)

Record after deployment + demo run, so every number on screen is real. Capture
terminal + dashboard + explorers; voiceover in English. No facecam needed.

## Shot list + narration

### 0:00–0:20 — Hook (dashboard on screen)
> "Stop-losses today depend on bots watching prices off-chain. Bots go down,
> bots get frontrun. FlashGuard moves the whole reaction on-chain — a price
> event on Unichain triggers a reactive contract on Lasna, which exits your
> position on Base Sepolia. No keeper. And the loop latency is measured
> on-chain, not claimed."

### 0:20–0:50 — Architecture (diagram / README loop)
> "Three contracts, three chains. A price feed on Unichain Sepolia emits price
> events. Our reactive contract on Reactive Lasna subscribes to them and checks
> every stop-loss order. On breach it requests a callback to the vault on Base
> Sepolia, which pays out stablecoins at the trigger price."

### 0:50–1:20 — Setup (terminal: demo.sh part 1)
Show: deposit 1 mETH into the vault, register stop-loss at $2,500.
> "I deposit one mETH and set a stop-loss at twenty-five hundred dollars.
> The order lives on Lasna now — nothing off-chain is watching."

### 1:20–1:50 — The trigger (terminal: demo.sh part 2)
Show: post $3,000 → nothing happens; post $2,400 → trigger.
> "Three thousand dollars — nothing happens, the guard is quiet. Twenty-four
> hundred — below the threshold — and the reactive contract fires."

### 1:50–2:25 — Proof (explorers + dashboard + measure_latency.js)
Show: the three transactions (Unichain origin → Lasna react → Base callback),
the vault's `lastLoopLatencySeconds`, and `node scripts/measure_latency.js` output.
> "Here is the full loop: the origin event on Unichain, the reaction on Lasna,
> and the exit on Base — [X] seconds end to end, recorded on-chain by the vault
> itself. Two mETH at twenty-four hundred dollars paid out as forty-eight hundred
> mUSDC in the test run."

### 2:25–2:30 — Close (repo on screen)
> "FlashGuard — the stop-loss that fires itself. Code, tests, and deployment
> scripts are public on GitHub. Thank you."

## Recording checklist

- [ ] Deploy + demo run done; real addresses + hashes in SUBMISSION.md
- [ ] Dashboard shows real numbers (serve repo root, `app/index.html`)
- [ ] Terminal font large (≥18pt), no private keys visible — use a testnet-only key
- [ ] Keep under 3:00 — cut the architecture section first if over time
- [ ] Export 1080p, upload unlisted to YouTube, paste link in SUBMISSION.md
