-- Brew Guardians client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CaptureFX = require(script.CaptureFX)
local Hud = require(script.Hud)
local Menus = require(script.Menus)
local State = require(script.State)
local Targeting = require(script.Targeting)
local UI = require(script.UI)

UI.OnClick = function()
	Hud.PlaySound("Click")
end
Hud.Init()

if Config.Sounds.Music ~= "" then
	local music = Instance.new("Sound")
	music.Name = "Music"
	music.SoundId = Config.Sounds.Music
	music.Looped = true
	music.Volume = 0.3
	music.Parent = workspace
	music:Play()
end

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
