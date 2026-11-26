-- Release-day recon: dumps what matters for building farm/quest/raid/gear features into workspace/AnimeChampionsX/recon.txt.
-- Run with the executor (execute-file), then read the file. Everything is capped so the file stays readable.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local LP = Players.LocalPlayer
local out = {}
local function add(...) out[#out + 1] = table.concat({ ... }, " ") end
local function section(name) add("\n== " .. name .. " ==") end

section("game")
add("PlaceId", game.PlaceId, "GameId", game.GameId, "JobId", game.JobId)

section("remotes (all of ReplicatedStorage)")
for _, d in RS:GetDescendants() do
	if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") or d:IsA("BindableEvent") then
		add(d.ClassName, (d:GetFullName():gsub("^ReplicatedStorage%.", "")))
	end
end

section("player attributes")
for k, v in LP:GetAttributes() do add(k, "=", tostring(v)) end
local ls = LP:FindFirstChild("leaderstats")
if ls then for _, v in ls:GetChildren() do add("leaderstat", v.Name, "=", tostring(v.Value)) end end
for _, c in LP:GetChildren() do add("LP child", c.ClassName, c.Name) end

section("workspace top level")
for _, c in workspace:GetChildren() do
	if not Players:GetPlayerFromCharacter(c) then add(c.ClassName, c.Name, "children=" .. #c:GetChildren()) end
end

section("humanoid models by parent (enemy candidates)")
local byParent = {}
for _, h in workspace:GetDescendants() do
	if h:IsA("Humanoid") and h.Parent and not Players:GetPlayerFromCharacter(h.Parent) then
		local p = h.Parent.Parent and h.Parent.Parent:GetFullName() or "?"
		byParent[p] = byParent[p] or { n = 0, sample = h.Parent.Name }
		byParent[p].n += 1
	end
end
for p, v in byParent do add(p, "count=" .. v.n, "e.g.", v.sample) end

section("collection tags")
for _, tag in CS:GetAllTags() do add(tag, #CS:GetTagged(tag)) end

section("gui names with auto/setting/quest/raid/world/equip text (cap 80)")
local n = 0
for _, d in LP.PlayerGui:GetDescendants() do
	if n >= 80 then break end
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		local t = d.Text:lower()
		if t:find("auto") or t:find("quest") or t:find("raid") or t:find("world") or t:find("equip") or t:find("setting") then
			n += 1
			add((d:GetFullName():gsub("^Players%." .. LP.Name .. "%.PlayerGui%.", "")), "|", d.Text)
		end
	end
end

section("top-level modules under ReplicatedStorage")
for _, c in RS:GetChildren() do add(c.ClassName, c.Name) end

local text = table.concat(out, "\n")
if not isfolder("AnimeChampionsX") then makefolder("AnimeChampionsX") end
writefile("AnimeChampionsX/recon.txt", text)
return #text .. " chars written to AnimeChampionsX/recon.txt"
