--[[
	StateController
	Keeps the latest colony snapshot from the server and tells other
	controllers when it changes.

	StateController.State    -- latest snapshot (nil until the first one)
	StateController.Blocked  -- set of blocked grid cells { ["x,z"] = true }
	StateController.Changed  -- Event, fires with the snapshot
	StateController.Notified -- Event, fires with (text, kind)
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local StateController = {}

local changed = Instance.new("BindableEvent")
local notified = Instance.new("BindableEvent")
StateController.Changed = changed.Event
StateController.Notified = notified.Event
StateController.State = nil
StateController.Blocked = {}

function StateController:Start()
	Remotes.ColonyState.OnClientEvent:Connect(function(state)
		if state.blocked then
			local set = {}
			for _, key in state.blocked do
				set[key] = true
			end
			self.Blocked = set
		end
		self.State = state
		changed:Fire(state)
	end)
	Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		notified:Fire(text, kind)
	end)
end

-- Lets other client code show a message in the same feed.
function StateController:LocalNotify(text: string, kind: string?)
	notified:Fire(text, kind or "info")
end

return StateController
