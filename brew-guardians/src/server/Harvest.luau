-- Ingredient nodes: hold the prompt to pick, the node regrows after a while.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Harvest = {}

local function setVisible(node: Model, visible: boolean)
	for _, d in node:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("BaseTransparency") == nil then
				d:SetAttribute("BaseTransparency", d.Transparency)
			end
			d.Transparency = if visible then d:GetAttribute("BaseTransparency") :: number else 1
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("ProximityPrompt") then
			d.Enabled = visible
		end
	end
end

local function hook(node: Model)
	local ingredientId = node:GetAttribute("IngredientId") :: string
	local def = Config.Ingredients[ingredientId]
	local prompt = node:FindFirstChild("HarvestPrompt", true) :: ProximityPrompt
	local ready = true

	prompt.Triggered:Connect(function(player)
		if not ready then
			return
		end
		ready = false
		setVisible(node, false)

		local amount = if def.Tier <= 1 then 2 else 1
		PlayerData.Update(player, function(data)
			data.Ingredients[ingredientId] = (data.Ingredients[ingredientId] or 0) + amount
			return true
		end)
		Remotes.Notify:FireClient(player, string.format("+%d %s", amount, def.Name), "item")

		task.delay(def.Respawn, function()
			ready = true
			setVisible(node, true)
		end)
	end)
end

function Harvest.Start()
	for _, node in WorldBuilder.IngredientNodes do
		hook(node)
	end
end

return Harvest
