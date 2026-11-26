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

-- ===== FEATURES (filled in after remotes are confirmed) =====
local main = Tabs.Main:AddLeftGroupbox("Farm", "swords")
main:AddDropdown("Priority", { Text = "Target Priority", Values = PRIORITIES, Default = 1 })
local info = Tabs.Main:AddRightGroupbox("Status", "info")
local status = info:AddLabel("Loaded. Waiting for features.", true)

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
