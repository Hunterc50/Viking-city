--[[
	IntroController
	The title screen and the short intro story.

	When the valley has loaded, the camera drifts slowly over your village
	behind the title. Play goes into the game. A new chieftain (still on the
	first saga goal) sees the intro story first: five short scenes over the
	fjord, the forest, your land and Greywater Hold. Click to go on, or Skip.
	The Story button plays it again.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local IntroController = {}

local controllers
local player = Players.LocalPlayer

local BONE = Color3.fromRGB(226, 206, 160)
local TEXT = Color3.fromRGB(238, 234, 226)
local MUTED = Color3.fromRGB(156, 152, 146)
local SERIF = Enum.Font.Garamond

IntroController.Active = false

function IntroController:Init(all)
	controllers = all
end

local function new(class: string, props, children)
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

-- The middle of your plot, and handy spots around the valley.
local function places()
	local origin = player:GetAttribute("PlotOrigin")
	if typeof(origin) ~= "Vector3" then
		origin = Vector3.new(0, 1, 0)
	end
	local half = Grid.PLOT_SIZE / 2
	local home = origin + Vector3.new(half, 0, half)
	local rival = Config.Rivals[1]
	return home, rival
end

-- Camera shots: each is a start and end CFrame the camera glides between.
local function shots()
	local home, rival = places()
	local gate = rival.Center + Vector3.new(math.cos(rival.GateAngle or 0), 0, math.sin(rival.GateAngle or 0)) * rival.Radius
	local function look(from: Vector3, at: Vector3)
		return CFrame.lookAt(from, at)
	end
	return {
		-- 1. low over the fjord, looking in at the land
		{ look(home + Vector3.new(-160, 14, -340), home + Vector3.new(0, 30, 200)), look(home + Vector3.new(-40, 16, -260), home + Vector3.new(60, 30, 200)) },
		-- 2. over the pine forest toward the mountains
		{ look(home + Vector3.new(-60, 70, 160), home + Vector3.new(-20, 120, 600)), look(home + Vector3.new(40, 80, 220), home + Vector3.new(80, 130, 620)) },
		-- 3. down onto your land
		{ look(home + Vector3.new(90, 90, -110), home), look(home + Vector3.new(50, 55, -80), home) },
		-- 4. the walls of Greywater Hold
		{ look(gate + Vector3.new(60, 30, -70), rival.Center + Vector3.new(0, 10, 0)), look(gate + Vector3.new(30, 18, -30), rival.Center + Vector3.new(0, 12, 0)) },
		-- 5. back home, rising over the village
		{ look(home + Vector3.new(-30, 20, -60), home + Vector3.new(0, 8, 20)), look(home + Vector3.new(-60, 70, -120), home + Vector3.new(0, 0, 40)) },
	}
end

local STORY = {
	"The old jarl is dead, and his sons have drawn swords over his hall.",
	"You took a longship and a handful of your kin, and sailed north up the cold fjord.",
	"Here, between the mountains and the sea, is land no one has claimed. Here you will build.",
	"But you are not alone. Greywater Hold watches from behind its walls, and raiders come by sea.",
	"Feed your people. Raise your hall. Make your name one the skalds will sing.",
}

local function camera(): Camera
	return workspace.CurrentCamera
end

-- Glides the camera along `shot` over `seconds`, until `stop()` is true.
local function glide(shot, seconds: number, stop)
	local cam = camera()
	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	while not stop() do
		local a = math.clamp((os.clock() - t0) / seconds, 0, 1)
		local e = a * a * (3 - 2 * a)
		cam.CFrame = shot[1]:Lerp(shot[2], e)
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

function IntroController:Start()
	local state = controllers.StateController
	while not state.State do
		task.wait(0.2)
	end
	IntroController.Active = true
	local camCtl = controllers.CameraController
	camCtl.Suspended = true
	-- no walking off while the title is up
	local controls
	pcall(function()
		controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
		controls:Disable()
	end)

	local gui = new("ScreenGui", { Name = "Title", IgnoreGuiInset = true, DisplayOrder = 90, ResetOnSpawn = false })

	-- film bars and a dark vignette
	local top = new("Frame", { Size = UDim2.new(1, 0, 0.11, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
	local bottom = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.11, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
	local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 14), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = gui }, {
		new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.45, 0.85), NumberSequenceKeypoint.new(1, 1) }) }),
	})

	-- the title block, left of centre
	local block = new("Frame", { Position = UDim2.fromScale(0.07, 0.24), Size = UDim2.fromOffset(620, 400), BackgroundTransparency = 1, Parent = gui })
	new("TextLabel", { Size = UDim2.fromOffset(620, 26), BackgroundTransparency = 1, Font = SERIF, TextSize = 22, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Text = "A  SAGA  OF  THE  NORTH", Parent = block })
	local title = new("TextLabel", { Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(620, 110), BackgroundTransparency = 1, Font = SERIF, TextSize = 96, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = "VIKING CITY", Parent = block })
	new("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.6, Thickness = 1.5, Parent = title })
	new("Frame", { Position = UDim2.fromOffset(2, 142), Size = UDim2.fromOffset(420, 2), BackgroundColor3 = BONE, BorderSizePixel = 0, Parent = block }, {
		new("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
	})
	new("TextLabel", { Position = UDim2.fromOffset(0, 156), Size = UDim2.fromOffset(560, 50), BackgroundTransparency = 1, Font = SERIF, TextSize = 22, TextWrapped = true, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "Settle the fjord. Grow a village into a kingdom. Raid your rivals by land and sea.", Parent = block })

	local buttons = new("Frame", { Position = UDim2.fromOffset(0, 230), Size = UDim2.fromOffset(300, 170), BackgroundTransparency = 1, Parent = block }, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function button(label: string, order: number, main: boolean?)
		local b = new("TextButton", {
			Size = UDim2.fromOffset(main and 260 or 200, main and 52 or 40),
			BackgroundColor3 = main and Color3.fromRGB(60, 55, 48) or Color3.fromRGB(26, 26, 28),
			BackgroundTransparency = 0.1,
			AutoButtonColor = true,
			Font = SERIF,
			TextSize = main and 30 or 22,
			TextColor3 = main and BONE or TEXT,
			Text = label,
			LayoutOrder = order,
			Parent = buttons,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0, 4) }),
			new("UIStroke", { Color = BONE, Transparency = main and 0.3 or 0.7, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		return b
	end
	local q = state.State.quest
	local fresh = q and q.index == 1
	local play = button(fresh and "BEGIN" or "CONTINUE", 1, true)
	local story = button("THE STORY", 2)
	local hint = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(700, 24), BackgroundTransparency = 1, Font = SERIF, TextSize = 18, TextColor3 = MUTED, Text = "In the game, press H for the controls", Parent = gui })

	-- the story caption, centred low over the film bar
	local caption = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.86, 0), Size = UDim2.new(0.7, 0, 0, 110), BackgroundTransparency = 1, Font = SERIF, TextSize = 32, TextWrapped = true, TextColor3 = TEXT, TextTransparency = 1, Text = "", Parent = gui })
	new("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.4, Thickness = 1.5, Parent = caption })
	local skip = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -14), Size = UDim2.fromOffset(110, 34), BackgroundColor3 = Color3.fromRGB(26, 26, 28), BackgroundTransparency = 0.2, Font = SERIF, TextSize = 20, TextColor3 = TEXT, Text = "Skip  »", Visible = false, Parent = gui }, {
		new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	})
	local moreHint = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(400, 22), BackgroundTransparency = 1, Font = SERIF, TextSize = 17, TextColor3 = MUTED, Text = "Click to continue", Visible = false, Parent = gui })

	gui.Parent = player:WaitForChild("PlayerGui")

	-- the game's own panels (saga, build menu, hotbar...) hide behind the title
	local hidden = {}
	task.spawn(function()
		local playerGui = player:WaitForChild("PlayerGui")
		while gui.Parent and IntroController.Active do
			for _, other in playerGui:GetChildren() do
				if other:IsA("ScreenGui") and other ~= gui and other.Name ~= "Loading" and other.Enabled and hidden[other] == nil then
					hidden[other] = true
					other.Enabled = false
				end
			end
			task.wait(0.1)
		end
	end)
	local function showHud()
		for other in hidden do
			if other.Parent then
				other.Enabled = true
			end
		end
		hidden = {}
	end
	if controllers.AudioController and controllers.AudioController.PlayTheme then
		controllers.AudioController:PlayTheme()
	end

	-- the slow drift behind the title
	local mode = "title"
	local home = places()
	task.spawn(function()
		local cam = camera()
		local t0 = os.clock()
		while gui.Parent do
			if mode == "title" then
				cam.CameraType = Enum.CameraType.Scriptable
				local a = (os.clock() - t0) * 0.035 + math.pi * 1.15
				local from = home + Vector3.new(math.cos(a) * 170, 70, math.sin(a) * 170 - 60)
				cam.CFrame = CFrame.lookAt(from, home + Vector3.new(0, 6, 30))
			end
			RunService.RenderStepped:Wait()
		end
	end)

	local function fadeMenu(show: boolean)
		local info = TweenInfo.new(0.6)
		block.Visible = true
		for _, d in block:GetDescendants() do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				TweenService:Create(d, info, { TextTransparency = show and 0 or 1 }):Play()
			end
			if d:IsA("TextButton") then
				TweenService:Create(d, info, { BackgroundTransparency = show and 0.1 or 1 }):Play()
			end
			if d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = show and 0.5 or 1 }):Play()
			end
		end
		TweenService:Create(shade, info, { BackgroundTransparency = show and 0.35 or 0.75 }):Play()
		hint.Visible = show
		task.delay(0.6, function()
			if not show then
				block.Visible = false
			end
		end)
	end

	local busy = false
	local function runStory()
		if busy then
			return
		end
		busy = true
		mode = "story"
		fadeMenu(false)
		skip.Visible = true
		local skipped = false
		local advance = false
		local skipConn = skip.Activated:Connect(function()
			skipped = true
		end)
		local clickConn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
				advance = true
			end
		end)
		local list = shots()
		for i, line in STORY do
			if skipped then
				break
			end
			advance = false
			caption.Text = line
			TweenService:Create(caption, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
			moreHint.Visible = true
			local t0 = os.clock()
			glide(list[i], 9, function()
				return skipped or advance or os.clock() - t0 > 9
			end)
			TweenService:Create(caption, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			task.wait(0.5)
		end
		skipConn:Disconnect()
		clickConn:Disconnect()
		skip.Visible = false
		moreHint.Visible = false
		caption.Text = ""
		busy = false
		return true
	end

	local function enterGame()
		mode = "done"
		local info = TweenInfo.new(0.9)
		for _, f in { top, bottom } do
			TweenService:Create(f, info, { BackgroundTransparency = 1 }):Play()
		end
		TweenService:Create(shade, info, { BackgroundTransparency = 1 }):Play()
		fadeMenu(false)
		task.wait(0.4)
		camCtl.Suspended = false
		IntroController.Active = false
		showHud()
		if controls then
			controls:Enable()
		end
		task.wait(0.6)
		gui:Destroy()
		state:LocalNotify("Follow the gold marker to your next goal. Press H for the controls.", "info")
	end

	play.Activated:Connect(function()
		if busy then
			return
		end
		if fresh and not IntroController.SeenStory then
			IntroController.SeenStory = true
			runStory()
		end
		enterGame()
	end)
	story.Activated:Connect(function()
		IntroController.SeenStory = true
		runStory()
		mode = "title"
		fadeMenu(true)
	end)
end

return IntroController
