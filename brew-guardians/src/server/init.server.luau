-- Brew Guardians server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes) -- create the RemoteEvents first

local Actions = require(script.Actions)
local GuardianService = require(script.GuardianService)
local Harvest = require(script.Harvest)
local PlayerData = require(script.PlayerData)
local Plots = require(script.Plots)
local WorldBuilder = require(script.WorldBuilder)

WorldBuilder.Build()
Plots.Start()
PlayerData.Start()
Harvest.Start()
GuardianService.Start()
Actions.Start()

print("[BrewGuardians] server ready")
