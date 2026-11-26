# Game facts (Anime Champions X)

Mark anything not seen in the executor as UNVERIFIED.

## Verified (countdown lobby, 2026-11-26)
- GameId 10778033190, PlaceId 78266264678775 (countdown place; expected to become the main place on release).
- Remotes live in ReplicatedStorage.Network (ModuleScript with RemoteEvent/RemoteFunction children).
  Lobby ones: HuntOpen (RF, chest id), HuntClaimBonus, ShardCollect, PlayReward, AfkIdle, AfkExit.
- The game has its own AFK service (ClientAfkService, AfkIdle/AfkExit remotes) besides Roblox's idle kick.

## UNVERIFIED (after release)
- Combat/attack remotes, enemy folders, unit/pet equip, quests, raids, worlds, accessories.
