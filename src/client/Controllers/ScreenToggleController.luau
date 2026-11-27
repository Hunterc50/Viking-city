--[[
	ScreenToggleController
	Press X to hide every panel on screen (for screenshots and for just
	looking at your village), and X again to bring them back.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ScreenToggleController = {}

local controllers

function ScreenToggleController:Init(all)
	controllers = all
end

function ScreenToggleController:Start()
	local player = Players.LocalPlayer
	local hidden: { [ScreenGui]: boolean }? = nil
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.X then
			return
		end
		if controllers.IntroController and controllers.IntroController.Active then
			return -- the title screen manages the panels itself
		end
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return
		end
		if hidden then
			for gui in hidden do
				if gui.Parent then
					gui.Enabled = true
				end
			end
			hidden = nil
		else
			hidden = {}
			for _, gui in playerGui:GetChildren() do
				if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "TerrainError" then
					hidden[gui] = true
					gui.Enabled = false
				end
			end
		end
	end)
end

return ScreenToggleController
