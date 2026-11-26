-- Lobby shard farmer: keeps collecting comet shards/cores (Shard Merchant trades them for items once the game opens).
-- Re-running replaces the old loop; set getgenv().ACXShardsGen = -1 to stop it.
local g = getgenv()
g.ACXShardsGen = (g.ACXShardsGen or 0) + 1
local me = g.ACXShardsGen
local lp = game.Players.LocalPlayer
local function root()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
task.spawn(function()
	while g.ACXShardsGen == me do
		local folder = workspace:FindFirstChild("CometShards")
		local home
		for _, s in folder and folder:GetChildren() or {} do
			local pp = s.PrimaryPart
			local prompt = pp and pp:FindFirstChild("CollectPrompt")
			if g.ACXShardsGen ~= me then break end
			if prompt and prompt.Enabled and s.Parent and root() then
				home = home or root().CFrame
				root().CFrame = pp.CFrame * CFrame.new(0, 3, 0)
				root().AssemblyLinearVelocity = Vector3.zero
				task.wait(0.35)
				local t = os.clock()
				while s.Parent and os.clock() - t < 3 do
					if prompt.Enabled then fireproximityprompt(prompt) end -- shortcut: ignores the hold time; the server accepted it in testing
					task.wait(0.3)
				end
			end
		end
		if home and root() then root().CFrame = home end
		task.wait(1.5)
	end
end)
