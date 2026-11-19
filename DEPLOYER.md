# Deployer — FlashGuard (testnets only)

## Address (fund this)

```
0x49D3689864C4031C13040eCf857FEd2B18ca5aeC
```

Freshly generated for this hackathon on 2026-11-19. **Testnets only — it holds
no mainnet funds and must never receive any.** The private key lives only in
`.env` (mode 600) in this directory; it is not in this file, not in the repo,
and not in any report.

## What it needs (all free testnet tokens)

| Chain | Amount | How |
|---|---|---|
| Base Sepolia (84532) | ~0.05 ETH | Any Base Sepolia faucet, e.g. https://www.alchemy.com/faucets/base-sepolia (0.1 ETH/24h, needs 0.001 ETH mainnet history on the claiming wallet) or https://faucet.quicknode.com/base/sepolia |
| Unichain Sepolia (1301) | ~0.02 ETH | Superchain faucet or bridge from Sepolia ETH |
| Reactive Lasna (5318007) | ~1 lREACT | Send 0.01 Base Sepolia ETH to the faucet contract `0x2afaFD298b23b62760711756088F75B7409f5967` via `request(address)` — 1 ETH → 100 lREACT (see README) |

Note: most faucets check the *claiming* wallet for mainnet history or require a
captcha, so this step needs a human (or a browser agent) — it cannot be done
from this VM alone. Paste the address above into the faucet, wait for the drip,
then run:

```bash
./scripts/deploy_all.sh   # deploys all contracts, saves deployments/testnet.json
./scripts/demo.sh         # runs the full-loop demo, prints on-chain latency
node scripts/measure_latency.js
```

Then fill the TODO placeholders in `SUBMISSION.md` with the real addresses,
transaction hashes, and latency numbers, and record the video from
`VIDEO_SCRIPT.md`.
