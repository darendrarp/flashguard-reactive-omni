#!/usr/bin/env bash
# FlashGuard one-command testnet deployment.
#
# Order matters (Reactive docs, "Deployment Order"):
#   1. PriceFeed on Unichain Sepolia (origin).
#   2. FlashGuardReactive on Lasna (subscribes to the feed).
#   3. ProtectedVault (+ mock tokens) on Base Sepolia (needs reactive address).
#   4. setVault on the reactive contract (closes the loop).
#
# Prerequisites: .env with PRIVATE_KEY. The deployer needs:
#   - ~0.05 test ETH on Unichain Sepolia + Base Sepolia (public faucets, free)
#   - ~1 lREACT on Lasna (faucet: send 0.01 Sepolia ETH to the Base Sepolia
#     faucet contract 0x2afaFD298b23b62760711756088F75B7409f5967 -> 1 lREACT)
#
# Usage: ./scripts/deploy_all.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source .env
export PATH="$HOME/.foundry/bin:$PATH"

echo "== 1/4 PriceFeed on Unichain Sepolia =="
forge script script/DeployPriceFeed.s.sol --rpc-url unichain-sepolia --broadcast \
  --verify --verifier sourcify 2>&1 | tee /tmp/fg-deploy-feed.log
PRICE_FEED=$(grep -oP 'PriceFeed: \K0x[a-fA-F0-9]{40}' /tmp/fg-deploy-feed.log | head -1)
echo "PRICE_FEED=$PRICE_FEED"

echo "== 2/4 FlashGuardReactive on Lasna =="
PRICE_FEED="$PRICE_FEED" forge script script/DeployReactive.s.sol --rpc-url lasna --broadcast \
  --verify --verifier sourcify 2>&1 | tee /tmp/fg-deploy-reactive.log
REACTIVE=$(grep -oP 'FlashGuardReactive: \K0x[a-fA-F0-9]{40}' /tmp/fg-deploy-reactive.log | head -1)
echo "REACTIVE=$REACTIVE"

echo "== 3/4 ProtectedVault + mock tokens on Base Sepolia =="
REACTIVE="$REACTIVE" forge script script/DeployVault.s.sol --rpc-url base-sepolia --broadcast \
  --verify --verifier sourcify 2>&1 | tee /tmp/fg-deploy-vault.log
VAULT=$(grep -oP 'ProtectedVault: \K0x[a-fA-F0-9]{40}' /tmp/fg-deploy-vault.log | head -1)
METH=$(grep -oP 'mETH: \K0x[a-fA-F0-9]{40}' /tmp/fg-deploy-vault.log | head -1)
MUSDC=$(grep -oP 'mUSDC: \K0x[a-fA-F0-9]{40}' /tmp/fg-deploy-vault.log | head -1)
echo "VAULT=$VAULT METH=$METH MUSDC=$MUSDC"

echo "== 4/4 Link vault on the reactive contract =="
cast send "$REACTIVE" --rpc-url https://lasna-rpc.rnk.dev/ --private-key "$PRIVATE_KEY" \
  "setVault(address)" "$VAULT"

# Persist addresses for the demo + dashboard.
cat >> .env <<EOF
PRICE_FEED=$PRICE_FEED
REACTIVE=$REACTIVE
VAULT=$VAULT
METH=$METH
MUSDC=$MUSDC
EOF
mkdir -p deployments
cat > deployments/testnet.json <<EOF
{
  "priceFeed_unichainSepolia": "$PRICE_FEED",
  "reactive_lasna": "$REACTIVE",
  "vault_baseSepolia": "$VAULT",
  "mETH_baseSepolia": "$METH",
  "mUSDC_baseSepolia": "$MUSDC",
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo
echo "Deployment complete. Addresses saved to deployments/testnet.json"
echo "Next: ./scripts/demo.sh"
