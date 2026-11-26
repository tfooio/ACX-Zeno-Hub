-- Dev heartbeat: every 5 s writes "unixtime|PlaceVersion|PlaceId|JobId|place name" to workspace/AnimeChampionsX/status.txt.
-- A watcher outside Roblox reads it to notice the release (place name loses [COUNTDOWN] / version changes) or a dead client.
local g = getgenv()
g.ACXHeartbeat = (g.ACXHeartbeat or 0) + 1 -- re-running replaces the old loop
local me = g.ACXHeartbeat
if not isfolder("AnimeChampionsX") then makefolder("AnimeChampionsX") end
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
