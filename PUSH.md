# PUSH — retry after the GitHub secondary rate limit lifts

**Status 2026-11-19 ~18:00 WIB: NOT PUSHED.** Repo creation via the GitHub API
returned HTTP 403 "secondary rate limit … temporarily blocked from content
creation" (request 40FF:F38E8:4340E63:D607344:6AFED61D, 2026-11-19 10:57 UTC) —
most likely because several batch agents are creating/pushing repos at the same
time. No further GitHub API calls were made after that (rate-limit hard stop).
The local git repo is complete and committed (2 commits, 106 files, `.env` NOT
tracked). Retry in a later run.

## Retry commands (in order)

```bash
cd ~/workspace/hackathons-2026-11-19/builds/reactive-omni

# 1. Create the public repo (skip if it already exists)
printf '%s' '{"name":"flashguard-reactive-omni","description":"FlashGuard — cross-chain stop-loss in ~1 second. Reactive Omni Buildathon, track Every Second Counts: Unichain Sepolia price events trigger a reactive contract on Lasna that exits positions on Base Sepolia.","private":false,"has_issues":true,"has_projects":false,"has_wiki":false}' > /tmp/fg-repo.json
python3 ~/workspace/custom-connectors/custom.github/bin/gh_api.py POST /user/repos /tmp/fg-repo.json

# 2. Push (patched wrapper — works around the VM egress proxy truncation bug)
#    --exclude .env is REQUIRED: gh_push does not respect .gitignore and .env
#    holds the testnet deployer key.
python3 ~/workspace/hackathons-2026-11-19/builds/buildhybridai/gh_push_patched.py \
  darendrarp flashguard-reactive-omni \
  ~/workspace/hackathons-2026-11-19/builds/reactive-omni \
  "FlashGuard: cross-chain stop-loss on Reactive Omni (Every Second Counts)" \
  --exclude .env
```

Expected repo URL: https://github.com/darendrarp/flashguard-reactive-omni

## After the push

1. Fund the deployer (address in `DEPLOYER.md`) with free testnet ETH, then
   `./scripts/deploy_all.sh` + `./scripts/demo.sh`.
2. Fill the TODOs in `SUBMISSION.md` (addresses, tx hashes, latency).
3. Record the video from `VIDEO_SCRIPT.md`, submit on DoraHacks (user decision).
