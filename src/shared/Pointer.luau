--[[
	Pointer (client only)
	Where the player is pointing on screen, in viewport pixels (the same space
	as UserInputService:GetMouseLocation and Camera:ViewportPointToRay).
	With a mouse that is the mouse; on a phone or tablet it is the last spot
	tapped on the 3D world (taps on buttons and the thumbstick are ignored).
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Pointer = {}

local lastTouch: Vector2? = nil
local usingTouch = false

UserInputService.TouchStarted:Connect(function(input, processed)
	if not processed then
		usingTouch = true
		lastTouch = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
	end
end)
UserInputService.TouchMoved:Connect(function(input, processed)
	if not processed and lastTouch then
		lastTouch = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		usingTouch = false
	end
end)

function Pointer.location(): Vector2
	if usingTouch and lastTouch then
		return lastTouch
	end
	return UserInputService:GetMouseLocation()
end

function Pointer.isTouch(): boolean
	return usingTouch
end

return Pointer
