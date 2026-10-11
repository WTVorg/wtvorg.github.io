-- Player plots: your cauldron, your caught guardians on display, and the
-- coin collector they fill.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuardianModels = require(script.Parent.GuardianModels)
local PlayerData = require(script.Parent.PlayerData)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Plots = {}

type Plot = {
	Index: number,
	Owner: Player?,
	Frame: CFrame,
	Model: Model,
	Base: BasePart,
	Brew: BasePart,
	OwnerLabel: TextLabel,
	PendingLabel: TextLabel,
	Displays: Folder,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local DISPLAY_SLOTS = {}
for row = 0, 2 do
	for col = 0, 3 do
		table.insert(DISPLAY_SLOTS, Vector3.new(-18 + col * 12, 0, 4 + row * 10))
	end
end

local function local2world(plot: Plot, offset: Vector3): Vector3
	return (plot.Frame * CFrame.new(offset)).Position
end

local function label(parent: Instance, size: UDim2, offset: Vector3, color: Color3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = 150
	gui.Parent = parent
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.2
	text.Text = ""
	text.Parent = gui
	return text
end

local function buildPlot(index: number, parent: Instance): Plot
	local center = Config.PlotCenter(index)
	local frame = CFrame.lookAt(center, Vector3.zero)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local size = Config.PlotSize
	local base = WorldBuilder.Part({
		Name = "Base",
		Size = Vector3.new(size, 0.6, size),
		CFrame = frame * CFrame.new(0, 0.3, 0),
		Color = Color3.fromRGB(150, 130, 105),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})

	-- Fence posts around the back
	for i = -2, 2 do
		WorldBuilder.Part({
			Name = "Fence",
			Size = Vector3.new(size / 5 - 1, 3, 0.6),
			CFrame = frame * CFrame.new(i * size / 5, 1.8, size / 2 - 0.3),
			Color = Color3.fromRGB(120, 85, 55),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end

	-- Cauldron
	local potPos = (frame * CFrame.new(0, 0, -14)).Position
	local pot = WorldBuilder.Disc("Cauldron", potPos + Vector3.new(0, 2.6, 0), 4, 4.4, Color3.fromRGB(45, 45, 55), Enum.Material.Metal, model)
	local brew = WorldBuilder.Disc("Brew", potPos + Vector3.new(0, 4.85, 0), 3.4, 0.2, Color3.fromRGB(120, 255, 150), Enum.Material.Neon, model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrewPrompt"
	prompt.ActionText = "Brew"
	prompt.ObjectText = "Cauldron"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pot
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Rate = 6
	bubbles.Lifetime = NumberRange.new(0.8, 1.4)
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.Size = NumberSequence.new(0.5, 0)
	bubbles.EmitterDirection = Enum.NormalId.Right
	bubbles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170))
	bubbles.Parent = brew

	-- Collector pad
	local padPos = (frame * CFrame.new(16, 0, -18)).Position
	local pad = WorldBuilder.Disc("Collector", padPos + Vector3.new(0, 0.7, 0), 3.5, 0.5, Color3.fromRGB(255, 200, 60), Enum.Material.Neon, model)
	local collect = Instance.new("ProximityPrompt")
	collect.Name = "CollectPrompt"
	collect.ActionText = "Collect"
	collect.ObjectText = "Coins"
	collect.MaxActivationDistance = 10
	collect.RequiresLineOfSight = false
	collect.Parent = pad

	local signPost = WorldBuilder.Sign(model, (frame * CFrame.new(-8, 0, -size / 2 + 2)).Position, "", Color3.new(1, 1, 1))
	local ownerLabel = (signPost:FindFirstChildOfClass("BillboardGui") :: BillboardGui):FindFirstChildOfClass("TextLabel") :: TextLabel
	ownerLabel.Text = "Empty plot"

	local pendingLabel = label(pad, UDim2.fromOffset(160, 40), Vector3.new(0, 3, 0), Color3.fromRGB(255, 230, 120))

	local displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = model

	model.PrimaryPart = base
	model.Parent = parent

	local plot: Plot = {
		Index = index,
		Owner = nil,
		Frame = frame,
		Model = model,
		Base = base,
		Brew = brew,
		OwnerLabel = ownerLabel,
		PendingLabel = pendingLabel,
		Displays = displays,
	}

	prompt.Triggered:Connect(function(player)
		if plot.Owner ~= player then
			Remotes.Notify:FireClient(player, "That isn't your cauldron. Yours is on your own plot.", "error")
			return
		end
		Remotes.OpenUI:FireClient(player, "Brew")
	end)

	collect.Triggered:Connect(function(player)
		if plot.Owner ~= player then
			return
		end
		local amount = 0
		PlayerData.Update(player, function(data)
			amount = math.floor(data.PendingCoins)
			if amount <= 0 then
				return false
			end
			data.PendingCoins -= amount
			data.Coins += amount
			return true
		end)
		if amount > 0 then
			Remotes.Notify:FireClient(player, string.format("+%d coins", amount), "coins")
		end
	end)

	return plot
end

function Plots.Get(player: Player): Plot?
	return byPlayer[player]
end

function Plots.SpawnCFrame(player: Player): CFrame?
	local plot = byPlayer[player]
	if not plot then
		return nil
	end
	return CFrame.lookAt(local2world(plot, Vector3.new(-14, 4, -20)), local2world(plot, Vector3.new(0, 4, -14)))
end

function Plots.NearOwnPot(player: Player, range: number): boolean
	local plot = byPlayer[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plot or not root then
		return false
	end
	return (root.Position - plot.Brew.Position).Magnitude <= range
end

function Plots.BrewEffect(player: Player, color: Color3)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	local brew = plot.Brew
	local original = brew.Color
	brew.Color = color
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(color)
	burst.Speed = NumberRange.new(10, 18)
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Size = NumberSequence.new(1, 0)
	burst.SpreadAngle = Vector2.new(35, 35)
	burst.EmitterDirection = Enum.NormalId.Right
	burst.Rate = 0
	burst.Parent = brew
	burst:Emit(60)
	task.delay(2, function()
		burst:Destroy()
		TweenService:Create(brew, TweenInfo.new(1), { Color = original }):Play()
	end)
end

function Plots.Refresh(player: Player)
	local plot = byPlayer[player]
	local data = PlayerData.Get(player)
	if not plot or not data then
		return
	end
	plot.Displays:ClearAllChildren()

	local list = table.clone(data.Guardians)
	table.sort(list, function(a, b)
		return Config.GuardianIncome(a) > Config.GuardianIncome(b)
	end)
	for i = 1, math.min(#list, Config.MaxPlotDisplays) do
		local entry = list[i]
		if Config.Guardians[entry.Id] then
			local model = GuardianModels.Build(entry.Id, entry.Mutation)
			local pos = local2world(plot, DISPLAY_SLOTS[i])
			model:PivotTo(CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)))
			GuardianModels.SitOnGround(model, plot.Base.Position.Y + plot.Base.Size.Y / 2)
			model:SetAttribute("PlotGuardian", true)
			model:SetAttribute("DisplayName", Config.GuardianDisplayName(entry))
			model:SetAttribute("Income", Config.GuardianIncome(entry))
			model.Parent = plot.Displays
		end
	end
end

local function assign(player: Player)
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			byPlayer[player] = plot
			plot.OwnerLabel.Text = player.DisplayName .. "'s Plot"
			plot.Base.Color = Color3.fromRGB(175, 150, 115)
			Plots.Refresh(player)
			return plot
		end
	end
	Remotes.Notify:FireClient(player, "All plots are taken. You can still catch guardians!", "error")
	return nil
end

local function release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	plot.Owner = nil
	byPlayer[player] = nil
	plot.OwnerLabel.Text = "Empty plot"
	plot.PendingLabel.Text = ""
	plot.Base.Color = Color3.fromRGB(150, 130, 105)
	plot.Displays:ClearAllChildren()
end

local function onCharacter(player: Player, character: Model)
	task.wait(0.2)
	local cf = Plots.SpawnCFrame(player)
	if cf and character.Parent then
		character:PivotTo(cf)
	end
end

function Plots.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace
	for i = 1, Config.PlotCount do
		table.insert(plots, buildPlot(i, folder))
	end

	PlayerData.Loaded:Connect(function(player)
		assign(player)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerRemoving:Connect(release)

	-- Income
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTickSeconds)
			for player, plot in byPlayer do
				local data = PlayerData.Get(player)
				if data then
					local perSecond = 0
					for _, entry in data.Guardians do
						perSecond += Config.GuardianIncome(entry)
					end
					local cap = perSecond * Config.MaxPendingIncomeSeconds
					data.PendingCoins = math.min(data.PendingCoins + perSecond * Config.IncomeTickSeconds, cap)
					plot.PendingLabel.Text = if perSecond > 0
						then string.format("%d coins  (+%d/s)", math.floor(data.PendingCoins), math.floor(perSecond))
						else "Catch guardians to earn"
				end
			end
		end
	end)
end

return Plots
