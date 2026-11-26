-- Lobby quiz (daireb, "original UI" reward): answers by trial, remembering which option was right/wrong per question text.
-- A wrong answer restarts the quiz with 5 of 16 questions, so it keeps trying until it passes. Progress goes to the console.
local N = require(game.ReplicatedStorage.Network)
local lp = game.Players.LocalPlayer
local g = getgenv()
g.ACXQuiz = g.ACXQuiz or {} -- question text -> { right = option text, wrong = { [option text] = true } }
local known = g.ACXQuiz

local function near() -- the server refuses dialogue beyond ~45 studs
	local npc = workspace:FindFirstChild("daireb")
	local p = npc and npc:FindFirstChild("HumanoidRootPart")
	local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if p and r and (r.Position - p.Position).Magnitude > 10 then
		r.CFrame = p.CFrame * CFrame.new(0, 0, 5)
		r.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.4)
	end
end
local function call(remote, ...)
	local res = table.pack(pcall(remote.InvokeServer, remote, ...))
	return res[2], res[3] -- view, verdict
end
local function pick(view)
	local q = view.lines[1]
	known[q] = known[q] or { wrong = {} }
	local k = known[q]
	for i, o in view.options do if o == k.right then return i, k end end
	for i, o in view.options do if not k.wrong[o] then return i, k end end
	return 1, k
end

task.spawn(function()
	near()
	local view = call(N.DialogueStep, nil) -- resume whatever dialogue is open
	for n = 1, 120 do
		near()
		if not view then
			view = call(N.DialogueOpen, "QuizNpc")
			if not view then task.wait(2) end
		elseif #view.options == 0 then
			local ended = view.ends
			view = call(N.DialogueStep, nil)
			if ended then print("[ACX quiz] finished after", n, "steps; closed:", view == nil) return end
		else
			local i, k = pick(view)
			local text = view.options[i]
			local nextView, verdict = call(N.DialogueStep, i)
			if verdict == "right" then k.right = text elseif verdict == "wrong" then k.wrong[text] = true end
			print(("[ACX quiz] %s | %s -> %s"):format(view.progress or "?", text, tostring(verdict)))
			view = nextView
		end
		task.wait(0.5)
	end
	print("[ACX quiz] gave up after 120 steps")
end)
