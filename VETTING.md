# VETTING — Reactive Omni Buildathon

**Vetted:** 2026-11-19 ~17:55 WIB
**Verdict: ✅ PASSES — proceed to build (Track: "Every Second Counts")**

## Official links

- **DoraHacks page:** https://dorahacks.io/hackathon/reactive-omni-buildathon
  (full URL recovered from the official blog's outbound link; the DoraHacks page itself
  returns HTTP 405 to automated fetches, so rule details below come from the official
  Reactive blog announcement + DoraHacks newsletters + third-party listings, and are
  marked as such where the DoraHacks page could not be read directly.)
- **Official announcement:** https://blog.reactive.network/reactive-omni-buildathon-thirty-days-to-find-out-what-one-second-buys/ (published 2026-11-04)
- **Reactive docs:** https://dev.reactive.network/
- **DoraHacks newsletter (Nov III):** https://hidorahacks.medium.com/dorahacks-hackathon-newsletter-november-2026-iii-1bed32165991

## Event facts (verified)

| Item | Value | Source |
|---|---|---|
| Organizer | Reactive Network | Official blog |
| Platform | DoraHacks (registration + submissions) | Official blog |
| Format | **Online / virtual** | DoraHacks newsletter "Virtual Hackathons"; all-conf.com listing "Online Hackathon" |
| Dates | **5 Nov 2026 – 5 Dec 2026** (all-conf lists end as 6 Dec 2026 00:00 UTC, i.e. deadline is end of 5 Dec) | Official blog; DoraHacks newsletter; all-conf |
| Deadline timezone | Not stated precisely on the blog; all-conf lists times in UTC. **Treat as 5 Dec 2026 23:59 UTC / 6 Dec 06:59 WIB until confirmed on the DoraHacks page** | all-conf.com |
| Time remaining (at vetting) | ~16 days — realistic for a focused build | — |
| Entry fee | **None found — free.** No fee is mentioned in the announcement, newsletter, or listings | Official blog |
| Student requirement | **None.** Blog: "You can join whether you write Solidity daily or have never deployed a contract." | Official blog |
| Domicile / residency restriction | **None found** | Official blog |
| Team requirement | **No team mandate found.** The announcement never requires a team; DoraHacks supports solo BUIDL submissions. Exact team-size cap (if any) on the DoraHacks page: **not found** (page unreadable to fetcher) — to be confirmed by the user at registration | Official blog |
| KYC / identity attestation | **None found.** No KYC or identity attestation is mentioned anywhere in the announcement | Official blog |
| Travel | **None — fully remote** | Newsletter / all-conf |
| Prizes | **$5,500 total, denominated in USD, paid in REACT:** Every Second Counts $2,000 1st + $250 runner-up; Set It and Forget It $2,000 1st + $250 runner-up; Reactive Meets AI $1,000 1st | Official blog |
| Judging | Reactive team. Four equally-weighted criteria scored 1–5: Execution, Integration, Usefulness, Craft. **Entries without on-chain reactive transactions + callbacks are not scored further.** | Official blog |

## What must be built

Reactive contracts = event-driven smart contracts on Reactive Network (an EVM
automation layer). A reactive contract subscribes to event logs on origin chains;
when a matching log appears, the system contract calls `react()`, and the contract
can request a cross-chain callback to a destination chain. No off-chain bot needed.

**Reactive Omni** is the new version: CometBFT consensus, ~1s blocks, instant
finality (previous version: ~7s blocks). Lasna is the Omni testnet.

### Tracks

1. **Every Second Counts** (chosen) — DeFi where reaction time matters, on
   **Unichain Sepolia** (1s blocks) and/or **Base Sepolia** (200ms blocks since the
   Denim upgrade), with **Reactive Lasna testnet** in the middle. Ideas named by the
   organizers: arbitrage on price gaps, stop-loss / take-profit orders, rebalancing
   vaults, withdrawal queues. **Strongest entries show latency numbers measured
   across the full loop, not just one leg.**
2. Set It and Forget It — personal automations, any supported chain.
3. Reactive Meets AI — AI must be part of the running system, not just the coding tool.

### Ground rules (official blog)

- "Every Second Counts" runs on **Lasna testnet**. Other tracks may use mainnet or Lasna.
- Repositories must be **public and open-source** by submission time.
- **Everything should be built during the event.** Prior work can come in as a
  dependency, but not as the submission itself. → Build window = 5 Nov – 5 Dec 2026.
  Building now (19 Nov) is **inside the window**. ✅
- On Base Sepolia, use **timestamps, not block counts**, for timers/cooldowns/deadlines
  (200ms blocks).
- Submission must include: public repo link, deployed contract addresses, a few
  transaction hashes showing the full loop from origin event to callback, and a
  **demo video under 3 minutes**.

## Hard-criteria checklist

| Criterion | Result |
|---|---|
| Solo-friendly | ✅ PASS — no team mandate found; DoraHacks supports solo submissions |
| Remote / online | ✅ PASS — virtual hackathon, no travel |
| Free, no fee | ✅ PASS — no fee found anywhere |
| No student requirement | ✅ PASS |
| No domicile restriction | ✅ PASS — none found |
| No travel required | ✅ PASS |
| No KYC / identity attestation | ✅ PASS — none found |
| Deadline open & realistic | ✅ PASS — closes 5 Dec 2026, ~16 days left |

**No hard criterion failed. Build approved.**

## Caveats / "not found" items (must be confirmed by the user on the DoraHacks page)

1. **Exact submission cutoff time-of-day** (only "December 5th" / "6 Dec 00:00 UTC" found).
2. **Team-size cap** (if any) — no team requirement found, but the DoraHacks page's
   team rules could not be read (HTTP 405 to fetcher).
3. **Prize-claim mechanics** (how REACT is paid, wallet requirements) — not stated
   in the announcement.
4. **Judging / results timeline** after 5 Dec — not stated in the announcement.

## Technical facts verified from official docs (dev.reactive.network)

- Lasna testnet: chain ID **5318007**, RPC `https://lasna-rpc.rnk.dev/`,
  explorer `https://lasna.reactscan.net/`, currency lREACT. System contract
  `0x8888888888888888888888888888888888888888` (same on mainnet + Lasna).
- Base Sepolia: chain ID **84532**, callback proxy
  `0x476F44b11F5C942c58f4c8E3d0300E5710743585`.
- Unichain Sepolia: chain ID **1301**, callback proxy
  `0x775c9B990ADe401060B78D0e98684eEf8d2466C1`.
- Mainnets and testnets must not be mixed (testnet origin → testnet destination).
- Reactive lib (Omni): https://github.com/Reactive-Network/reactive-lib-omni
  (`AbstractReactive`, `AbstractCallback`, `ISystemContract`; Solidity ^0.8.29).
- Lasna lREACT faucet: send Sepolia ETH to the faucet contract
  (Base Sepolia faucet `0x2afaFD298b23b62760711756088F75B7409f5967`), 1 ETH → 100 lREACT,
  max 5 ETH per tx.
- RPC liveness checked 19 Nov 2026 from this VM: Lasna block 8,727,951;
  Base Sepolia block 60,818,326; Unichain Sepolia block 68,233,111 — all reachable.

## Chosen build (Track: Every Second Counts)

**FlashGuard — a cross-chain stop-loss that fires in ~1 second.**
A price feed on Unichain Sepolia emits price events; a reactive contract on Lasna
watches them and, the moment a registered stop-loss threshold is breached, fires a
callback to a vault on Base Sepolia that exits the user's position. Full-loop
latency (origin event → callback execution) is measured on-chain and displayed.
See `README.md` in this directory for the build.
