-- Anime Champions X hub. Obsidian UI (same as the old Chest Hunter), blue accent, config autosaved per account.
-- Feature loops are added in the FEATURES section once the real remotes are confirmed after release.
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
local env = getgenv()

if env.ACXUnload then pcall(env.ACXUnload) end -- re-running replaces the old copy

local REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/67c9cde7647456d60eec215257e938fbbe8688be/"
local ROOT = "AnimeChampionsX"
local CACHE = ROOT .. "/Cache"
if not isfolder(ROOT) then makefolder(ROOT) end
if not isfolder(CACHE) then makefolder(CACHE) end
local function fetch(file)
	local cache = CACHE .. "/obsidian_" .. (file:gsub("/", "_"))
	for try = 1, 3 do
		local ok, src = pcall(game.HttpGet, game, REPO .. file)
		local fn = ok and type(src) == "string" and loadstring(src)
		if fn then
			if not isfile(cache) then pcall(writefile, cache, src) end
			return fn()
		end
		if try < 3 then task.wait(try * 2) end
	end
	return assert(loadstring(readfile(cache)))() -- shortcut: saved copy is never refreshed; delete AnimeChampionsX/Cache to renew it
end
local Library = fetch("Library.lua")
local ThemeManager = fetch("addons/ThemeManager.lua")
local SaveManager = fetch("addons/SaveManager.lua")

-- dark navy panels, light-ish blue accent
Library.Scheme.BackgroundColor = Color3.fromRGB(14, 20, 33)
Library.Scheme.MainColor = Color3.fromRGB(22, 31, 49)
Library.Scheme.OutlineColor = Color3.fromRGB(40, 56, 84)
Library.Scheme.AccentColor = Color3.fromRGB(96, 165, 250)

env.ACXLib = Library -- handle for remote control/testing from the executor
local Options, Toggles = Library.Options, Library.Toggles
local alive = true

local function hrp()
	local ch = LP.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function tp(cf)
	local h = hrp()
	if not h then return false end
	h.CFrame = cf
	h.AssemblyLinearVelocity = Vector3.zero
	return true
end

-- Target priority over any candidate list: { { hp = number, pos = Vector3, ref = any }, ... }. Ties go to the earlier entry.
local PRIORITIES = { "Nearest", "Lowest HP", "Highest HP" }
local function pickTarget(list, mode, from)
	local best, bestKey
	for _, t in list do
		local key = mode == "Lowest HP" and t.hp or mode == "Highest HP" and -t.hp or (t.pos - from).Magnitude
		if not bestKey or key < bestKey then best, bestKey = t, key end
	end
	return best
end
do -- self-check, runs on every load
	local L = { { hp = 50, pos = Vector3.new(10, 0, 0) }, { hp = 10, pos = Vector3.new(30, 0, 0) }, { hp = 90, pos = Vector3.new(20, 0, 0) } }
	assert(pickTarget(L, "Nearest", Vector3.zero).hp == 50)
	assert(pickTarget(L, "Lowest HP", Vector3.zero).hp == 10)
	assert(pickTarget(L, "Highest HP", Vector3.zero).hp == 90)
	assert(pickTarget({}, "Nearest", Vector3.zero) == nil)
end

local Window = Library:CreateWindow({
	Title = "Zeno Hub", -- the sidebar is narrow; a longer title gets cut
	Footer = "per-account config: autosaved",
	ToggleKeybind = Enum.KeyCode.RightShift,
	Center = true,
	AutoShow = true,
	Size = UDim2.fromOffset(560, 400),
	CornerRadius = 12,
	Font = Enum.Font.GothamMedium,
})
local Tabs = {
	Main = Window:AddTab("Main", "swords"),
	Misc = Window:AddTab("Misc", "layout-grid"),
	Settings = Window:AddTab("Settings", "settings"),
}

-- ===== FARM =====
local main = Tabs.Main:AddLeftGroupbox("Farm", "swords")
local info = Tabs.Main:AddRightGroupbox("Status", "info")
local status = info:AddLabel("Auto Farm: off", true)
local lastStatus = "Auto Farm: off"
local function setStatus(text) -- only on change, and never let a label error stop the farm loop
	if text ~= lastStatus then
		lastStatus = text
		pcall(status.SetText, status, text)
	end
end
main:AddToggle("AutoFarm", {
	Text = "Auto Farm",
	Tooltip = "Orders your team to attack the best enemy pack, uses abilities, and teleports to enemies that are out of range.",
	Default = false,
	Callback = function(on) if not on then setStatus("Auto Farm: off") end end,
})
main:AddDropdown("Priority", { Text = "Target Priority", Values = PRIORITIES, Default = 1 })
main:AddToggle("UseAbilities", { Text = "Use Abilities", Tooltip = "Fires every champion ability the moment it is ready.", Default = true })
main:AddToggle("TeleportToEnemies", { Text = "Teleport To Enemies", Tooltip = "Jumps next to a pack that is too far away to be ordered.", Default = true })

local G -- the game's own modules, bound on first use so the hub still loads in places that lack them
local function bind()
	if G then return G end
	local ok, res = pcall(function()
		local RS = game:GetService("ReplicatedStorage")
		return {
			world = require(RS.Shared.ecs.world),
			C = require(RS.Shared.Components),
			TU = require(RS.Shared.utils.TeamUtils),
			Packs = require(RS.Shared.combat.Packs),
			rep = require(RS.Client.replicator),
			N = require(RS.Network),
			Orders = require(RS.Client.services.ClientUnitOrderService),
			Data = require(RS.Client.services.ClientDataService).GetStore(),
			MAX = require(RS.Config.CombatConfig).ATTACK_ORDER.MAX_DISTANCE,
		}
	end)
	if ok then G = res end
	return G
end

-- how many of my champions are standing / knocked out (the game is hard: units go down and need a moment to recover)
local function teamState(g, me)
	local up, down = 0, 0
	pcall(function()
		for i in g.world:query(g.C.CharacterModel):with(g.C.Team):without(g.C.Dying) do
			if i ~= me and not g.TU.areEntitiesHostile(me, i) and g.Packs.owningPlayer(i) == LP then
				if g.world:has(i, g.C.KnockedOut) then down += 1 else up += 1 end
			end
		end
	end)
	return up, down
end

local function farmStep()
	local g = bind()
	if not g then setStatus("Auto Farm: no combat in this place") return end
	local root = hrp()
	if not root then return end
	local me
	for i, v in g.world:query(g.C.Player) do if v == LP then me = i break end end
	if not me then return end
	local up, down = teamState(g, me)
	if down > 0 and down >= up then -- most of the team is down: call them back and let them recover instead of feeding them to the next pack
		g.N.RetreatUnits:FireServer()
		setStatus(("Auto Farm: recovering (%d up, %d down)"):format(up, down))
		return
	end
	local list, seen = {}, {}
	for i in g.world:query(g.C.CharacterModel):with(g.C.Targetable, g.C.Team):without(g.C.Sealed) do
		-- never pull the world boss by accident: it is a separate challenge and wipes an under-levelled team
		if g.TU.areEntitiesHostile(me, i) and not g.world:has(i, g.C.OverworldBoss) and not g.world:has(i, g.C.BossFight) then
			local pack = g.Packs.packOf(i)
			if pack and not seen[pack] and g.Packs.isLivePack(pack) then
				seen[pack] = true
				local cen = g.Packs.activeCentroid(pack)
				if cen then
					local hp = 0
					for _, m in g.Packs.activeMembers(pack) do hp += g.world:get(m, g.C.CurrentHealth) or 0 end
					list[#list + 1] = { hp = hp, pos = cen, ref = pack }
				end
			end
		end
	end
	local t = pickTarget(list, Options.Priority.Value, root.Position)
	if t then
		local flat = Vector3.new(t.pos.X - root.Position.X, 0, t.pos.Z - root.Position.Z)
		if flat.Magnitude > g.MAX - 15 then
			if Toggles.TeleportToEnemies.Value then tp(CFrame.new(t.pos - flat.Unit * 50 + Vector3.new(0, 4, 0))) end
		else
			g.N.EngagePack:FireServer(g.rep:get_server_entity(t.ref))
		end
	end
	if Toggles.UseAbilities.Value then
		for _, id in g.Data:get("EquippedChampions") or {} do
			if g.Orders.AbilityReady(id) then g.Orders.ActivateAbility(id) end
		end
	end
	setStatus(("Auto Farm: on\nKills: %s\nEnemy packs: %d"):format(tostring((g.Data:get("Stats") or {}).TotalKills), #list))
end

task.spawn(function()
	while alive do
		if Toggles.AutoFarm.Value then
			local ok, err = xpcall(farmStep, debug.traceback)
			if not ok then warn("[Zeno Hub] farm:", err) end
		end
		task.wait(1)
	end
end)

-- ===== ANTI-AFK (always on, no toggle) =====
local idled = LP.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

-- ===== MISC =====
local misc = Tabs.Misc:AddLeftGroupbox("Utility", "wrench")

-- ===== SETTINGS + per-account autosave =====
local set = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")
set:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
set:AddButton("Unload", function() Library:Unload() end)
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder(ROOT)
SaveManager:SetFolder(ROOT)
SaveManager:SetSubFolder(tostring(LP.UserId)) -- one config folder per account
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

local AUTO = "autosave"
if isfile(ROOT .. "/settings/" .. LP.UserId .. "/" .. AUTO .. ".json") then
	local ok, err = SaveManager:Load(AUTO)
	if not ok then warn("[ACX] autosave load failed:", err) end
end
task.spawn(function() -- shortcut: re-saves every 5 s instead of on change; fine for a handful of settings
	while alive do
		task.wait(5)
		pcall(SaveManager.Save, SaveManager, AUTO)
	end
end)

local function unload()
	alive = false
	pcall(SaveManager.Save, SaveManager, AUTO)
	idled:Disconnect()
	env.ACXUnload = nil
end
env.ACXUnload = function() Library:Unload() end
Library:OnUnload(unload)
