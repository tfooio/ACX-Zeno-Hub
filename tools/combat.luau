-- Combat loop prototype (test on GilbertXII first): every tick, order the units to attack the nearest hostile pack and use abilities
-- whenever they are ready. Same calls the game's own click/ability buttons make. Re-running replaces the old loop; set
-- getgenv().ACXCombat = -1 to stop.
local RS = game:GetService("ReplicatedStorage")
local LP = game.Players.LocalPlayer
local g = getgenv()
g.ACXCombat = (g.ACXCombat or 0) + 1
local gen = g.ACXCombat
local world = require(RS.Shared.ecs.world)
local C = require(RS.Shared.Components)
local TU = require(RS.Shared.utils.TeamUtils)
local Packs = require(RS.Shared.combat.Packs)
local rep = require(RS.Client.replicator)
local N = require(RS.Network)
local Orders = require(RS.Client.services.ClientUnitOrderService)
local Data = require(RS.Client.services.ClientDataService).GetStore()
local MAX = require(RS.Config.CombatConfig).ATTACK_ORDER.MAX_DISTANCE

local function myEntity()
	for i, v in world:query(C.Player) do if v == LP then return i end end
end
-- nearest live hostile pack within order range; candidates are { hp?, pos } so a priority mode can plug in later
local function nearestPack(me)
	local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local best, bestD, bestCen, seen = nil, math.huge, nil, {}
	for i in world:query(C.CharacterModel):with(C.Targetable, C.Team):without(C.Sealed) do
		if TU.areEntitiesHostile(me, i) then
			local pack = Packs.packOf(i)
			if pack and not seen[pack] and Packs.isLivePack(pack) and Packs.hasActiveMember(pack) then
				seen[pack] = true
				local cen = Packs.activeCentroid(pack)
				if cen then
					local d = (Vector3.new(cen.X, 0, cen.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
					if d < bestD then best, bestD, bestCen = pack, d, cen end
				end
			end
		end
	end
	if best and bestD > MAX - 15 then -- out of order range: teleport next to the pack (50 studs short of it)
		local dir = (Vector3.new(bestCen.X, 0, bestCen.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Unit
		root.CFrame = CFrame.new(bestCen - dir * 50 + Vector3.new(0, 4, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		return nil
	end
	return best
end

task.spawn(function()
	local me = myEntity()
	while g.ACXCombat == gen do
		local ok, err = pcall(function()
			me = me or myEntity()
			local pack = me and nearestPack(me)
			if pack then N.EngagePack:FireServer(rep:get_server_entity(pack)) end
			for _, id in Data:get("EquippedChampions") or {} do
				if Orders.AbilityReady(id) then Orders.ActivateAbility(id) end
			end
		end)
		if not ok then warn("[ACX combat]", err) end
		task.wait(1)
	end
end)
