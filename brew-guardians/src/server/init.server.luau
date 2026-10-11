-- Brew Guardians server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes) -- create the RemoteEvents first

local Actions = require(script.Actions)
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

start("World", WorldBuilder.Build)
start("Plots", Plots.Start)
start("PlayerData", PlayerData.Start)
start("Harvest", Harvest.Start)
start("Guardians", GuardianService.Start)
start("Actions", Actions.Start)

print("[BrewGuardians] server ready")
