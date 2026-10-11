-- Brew Guardians client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CaptureFX = require(script.CaptureFX)
local Hud = require(script.Hud)
local Menus = require(script.Menus)
local State = require(script.State)
local Targeting = require(script.Targeting)

Hud.Init()
Menus.Init()
CaptureFX.Init()
Hud.OpenMenu = Menus.Open

Remotes.StateUpdate.OnClientEvent:Connect(State.Set)
Remotes.Notify.OnClientEvent:Connect(Hud.Toast)
Remotes.Announce.OnClientEvent:Connect(Hud.Announce)
Remotes.OpenUI.OnClientEvent:Connect(Menus.Open)
Remotes.RequestState:FireServer()

task.spawn(Targeting.Init)

-- First-time players get the how-to-play page.
task.delay(2, function()
	local data = State.Data
	if data and data.Stats.Throws == 0 then
		Menus.Open("Help")
	end
end)
