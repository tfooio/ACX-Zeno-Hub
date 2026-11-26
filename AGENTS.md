# Zeno Hub (Anime Champions X)

Roblox script hub for Anime Champions X. Luau + Obsidian UI. Repo: tfooio/ACX-Zeno-Hub (public for now so friends can loadstring it; main must always load).
Single file `acx.luau`; `tools/sync.ps1` mirrors it into the executor workspace (autoexec loads that copy).

## Working rules
- Trunk workflow: small commits straight to `main`. The executor runs the working tree, so branches would swap files under a live test.
- Never guess a remote name or path: if it is not in `docs/game-rules.md`, mark it UNVERIFIED and discover it with the executor tools.
- Verify every feature live (remote-spy / console / screenshot) before calling it done.
- Never commit webhook URLs, tokens or per-account config (`AnimeChampionsX/settings/<UserId>/` lives in the executor workspace only).
- After editing `acx.luau`, run `tools/sync.ps1`.

## Roadmap
1. Core farm: teleport + attack, every in-game automation, target priority (highest HP / lowest HP / nearest)
2. Raid mode + world progression
3. Auto quest (accept, complete) + auto next world
4. Auto-equip best accessories on best units, with stat priority
