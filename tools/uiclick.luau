-- Tutorial helper: clicks the game's dialogue "advance" button and a whitelist of safe prompt buttons (Accept / Continue / Claim / Skip),
-- exactly like a player would. Never touches Buy/Purchase buttons. Re-running replaces the old loop; set getgenv().ACXClick = -1 to stop.
local g = getgenv()
g.ACXClick = (g.ACXClick or 0) + 1
local gen = g.ACXClick
local PG = game.Players.LocalPlayer.PlayerGui
local SAFE = { Accept = true, Continue = true, Claim = true, ["Claim All"] = true, Skip = true, Next = true }

local function press(btn)
	for _, sig in { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" } do pcall(firesignal, btn[sig]) end
end

task.spawn(function()
	while g.ACXClick == gen do
		pcall(function()
			local d = PG:FindFirstChild("Dialogue")
			local adv = d and d.Enabled and d:FindFirstChild("Button", true)
			if adv and adv:IsA("GuiButton") and adv.Visible then press(adv) end
			for _, l in PG:GetDescendants() do
				if l:IsA("TextLabel") and SAFE[l.Text] and l.Visible then
					local b = l
					while b and not b:IsA("GuiButton") do b = b.Parent end
					if b and b.Visible and b.Active ~= false then press(b) end
				end
			end
		end)
		task.wait(1.2)
	end
end)
