#!/usr/bin/env bash
# FlashGuard end-to-end demo on testnets.
#
# Prerequisites: contracts deployed (see README "Deployment"), .env filled with
# PRICE_FEED, REACTIVE, VAULT, METH, MUSDC addresses and PRIVATE_KEY funded with
# testnet ETH on Unichain Sepolia + Base Sepolia and lREACT on Lasna.
#
# Flow:
#   1. Deposit 1 mETH into the vault (Base Sepolia).
#   2. Register a stop-loss order at $2,500 (Lasna).
#   3. Post $3,000 — nothing happens (price above threshold).
#   4. Post $2,400 — Reactive fires, the vault exits the position into mUSDC.
#   5. Print the on-chain measured full-loop latency.
#
# Usage: ./scripts/demo.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source .env

UNI_RPC="https://sepolia.unichain.org"
BASE_RPC="https://sepolia.base.org"
LASNA_RPC="https://lasna-rpc.rnk.dev/"
ASSET_ID=1

echo "== 1. Deposit 1 mETH into the vault =="
cast send "$METH" --rpc-url "$BASE_RPC" --private-key "$PRIVATE_KEY" \
  "approve(address,uint256)" "$VAULT" 1000000000000000000 >/dev/null
cast send "$VAULT" --rpc-url "$BASE_RPC" --private-key "$PRIVATE_KEY" \
  "deposit(uint256)" 1000000000000000000
echo "Deposited. Vault balance:"
cast call "$VAULT" --rpc-url "$BASE_RPC" "deposits(address)(uint256)" "$(cast wallet address --private-key "$PRIVATE_KEY")"

echo
echo "== 2. Register stop-loss at \$2,500 (2500e8) =="
cast send "$REACTIVE" --rpc-url "$LASNA_RPC" --private-key "$PRIVATE_KEY" \
  "registerOrder(address,uint256,uint256)" \
  "$(cast wallet address --private-key "$PRIVATE_KEY")" "$ASSET_ID" 250000000000

echo
echo "== 3. Post \$3,000 — above threshold, no trigger expected =="
cast send "$PRICE_FEED" --rpc-url "$UNI_RPC" --private-key "$PRIVATE_KEY" \
  "postPrice(uint256,uint256)" "$ASSET_ID" 300000000000

echo
echo "== 4. Post \$2,400 — below threshold, stop-loss fires =="
cast send "$PRICE_FEED" --rpc-url "$UNI_RPC" --private-key "$PRIVATE_KEY" \
  "postPrice(uint256,uint256)" "$ASSET_ID" 240000000000

echo
echo "== 5. Waiting 60s for the full loop (Unichain -> Lasna -> Base) =="
sleep 60

echo
echo "== Result =="
echo "Vault exits:"
cast call "$VAULT" --rpc-url "$BASE_RPC" "exitCount()(uint256)"
echo "Last full-loop latency (seconds, measured on-chain):"
cast call "$VAULT" --rpc-url "$BASE_RPC" "lastLoopLatencySeconds()(uint256)"
echo "Average full-loop latency (seconds):"
cast call "$VAULT" --rpc-url "$BASE_RPC" "averageLoopLatencySeconds()(uint256)"
echo "mUSDC balance of demo wallet:"
cast call "$MUSDC" --rpc-url "$BASE_RPC" "balanceOf(address)(uint256)" "$(cast wallet address --private-key "$PRIVATE_KEY")"
echo
echo "For transaction hashes + per-leg timing, run: node scripts/measure_latency.js"
