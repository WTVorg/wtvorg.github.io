-- Brew Guardians server entry point.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

require(ReplicatedStorage.Shared.Remotes) -- create the RemoteEvents first

local Actions = require(script.Actions)
local Art = require(script.Art)
local Environment = require(script.Environment)
local GuardianService = require(script.GuardianService)
local Harvest = require(script.Harvest)
local PlayerData = require(script.PlayerData)
local Plots = require(script.Plots)
local WorldBuilder = require(script.WorldBuilder)

-- Each step runs on its own so one failure can't take the whole game down.
-- Any error still shows in the Output window with its stack trace.
local function start(name: string, fn: () -> ())
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		warn(string.format("[BrewGuardians] %s failed to start:\n%s", name, tostring(err)))
	end
end

start("Art", Art.Init) -- before anything is built, so builders can use the meshes
start("Environment", Environment.Setup)
start("World", WorldBuilder.Build)
start("Plots", Plots.Start)
start("PlayerData", PlayerData.Start)
start("Harvest", Harvest.Start)
start("Guardians", GuardianService.Start)
start("Actions", Actions.Start)

-- In Studio, remind the developer when the art pack hasn't been imported yet.
if RunService:IsStudio() and not Art.Has("Mossling") then
	local Remotes = require(ReplicatedStorage.Shared.Remotes)
	local function remind(player: Player)
		task.delay(4, function()
			Remotes.Notify:FireClient(player, "Using fallback models. Import art/BrewGuardiansArt.fbx (File > Import 3D) for the full art.", "info")
		end)
	end
	Players.PlayerAdded:Connect(remind)
	for _, player in Players:GetPlayers() do
		remind(player)
	end
end

print("[BrewGuardians] server ready")
