-- Dev heartbeat: every 5 s writes "unixtime|PlaceVersion|PlaceId|JobId|place name" to workspace/AnimeChampionsX/status.txt.
-- A watcher outside Roblox reads it to notice the release (place name loses [COUNTDOWN] / version changes) or a dead client.
local g = getgenv()
g.ACXHeartbeat = (g.ACXHeartbeat or 0) + 1 -- re-running replaces the old loop
local me = g.ACXHeartbeat
if not isfolder("AnimeChampionsX") then makefolder("AnimeChampionsX") end
-- Event log (events.txt): dev announcements, every server-to-client remote (minus noisy ones), attribute changes and new
-- top-level objects, so new drops/events are visible even though chat history is not kept anywhere.
for _, c in g.ACXEventConns or {} do pcall(c.Disconnect, c) end
g.ACXEventConns = {}
task.spawn(pcall, function()
	local RS, HS = game:GetService("ReplicatedStorage"), game:GetService("HttpService")
	local who = game:GetService("Players").LocalPlayer.Name
	local NOISY = { ShardSpawn = 1, ShardRemove = 1, AlienPunch = 1, AfkCover = 1, AfkCovered = 1, AfkUncover = 1, AfkDebugArrive = 1, WaterFallSplash = 1, WaterFallSplashShow = 1 }
	local function log(...)
		pcall(appendfile, "AnimeChampionsX/events.txt", ("%s | %s | %s\n"):format(os.date("%H:%M:%S"), who, table.concat({ ... }, " ")))
	end
	local function show(v)
		local ok, js = pcall(HS.JSONEncode, HS, v)
		return (ok and js or tostring(v)):sub(1, 300)
	end
	local function hold(c) table.insert(g.ACXEventConns, c) end
	local function hookRemote(r)
		if r:IsA("RemoteEvent") and not NOISY[r.Name] and not r.Name:find("^__") then
			hold(r.OnClientEvent:Connect(function(...) log("remote", r.Name, show(table.pack(...))) end))
		end
	end
	local Network = RS:WaitForChild("Network", 30)
	for _, r in Network:GetChildren() do hookRemote(r) end
	hold(Network.ChildAdded:Connect(function(r) log("NEW remote", r.ClassName, r.Name) hookRemote(r) end))
	hold(RS.ChildAdded:Connect(function(c) log("NEW in ReplicatedStorage", c.ClassName, c.Name) end))
	hold(workspace.ChildAdded:Connect(function(c)
		if not game:GetService("Players"):GetPlayerFromCharacter(c) then log("NEW in workspace", c.ClassName, c.Name) end
	end))
	hold(workspace.AttributeChanged:Connect(function(a) log("workspace attr", a, show(workspace:GetAttribute(a))) end))
	local lp = game:GetService("Players").LocalPlayer
	hold(lp.AttributeChanged:Connect(function(a)
		if a ~= "InvasionShards" then log("player attr", a, show(lp:GetAttribute(a))) end -- shards change constantly while farming
	end))
end)
local name, lastName = "?", 0
task.spawn(function()
	while g.ACXHeartbeat == me do
		if os.clock() - lastName > 30 then -- the name comes from the web, so refresh it only every 30 s
			lastName = os.clock()
			local ok, info = pcall(game:GetService("MarketplaceService").GetProductInfo, game:GetService("MarketplaceService"), game.PlaceId)
			if ok and info then name = info.Name end
		end
		pcall(writefile, "AnimeChampionsX/status.txt", ("%d|%d|%d|%s|%s"):format(os.time(), game.PlaceVersion, game.PlaceId, game.JobId, name))
		task.wait(5)
	end
end)
