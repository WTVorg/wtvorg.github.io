-- Player plots: a fenced garden with your cauldron, your caught guardians on
-- display pedestals, and the coin chest they fill.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Build = require(script.Parent.Build)
local GuardianModels = require(script.Parent.GuardianModels)
local PlayerData = require(script.Parent.PlayerData)
local Props = require(script.Parent.Props)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Plots = {}

type Plot = {
	Index: number,
	Owner: Player?,
	Frame: CFrame, -- floor level, -Z faces the hub
	Model: Model,
	Floor: BasePart,
	Brew: BasePart,
	SetOwnerText: (string) -> (),
	PendingLabel: TextLabel,
	Displays: Folder,
	Pedestals: { { CFrame: CFrame, Top: number } },
	BrewPrompt: ProximityPrompt,
	CollectPrompt: ProximityPrompt,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local FLOOR_Y = 1 -- plot floor height above the ground
local GRASS = Color3.fromRGB(110, 175, 90)
local GRASS_OWNED = Color3.fromRGB(120, 190, 95)
local STONE = Color3.fromRGB(160, 154, 146)
local RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(110, 230, 120),
	Rare = Color3.fromRGB(90, 160, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
}

local function at(plot, x: number, z: number, y: number?): CFrame
	return plot.Frame * CFrame.new(x, y or 0, z)
end

local function buildPlot(index: number, parent: Instance): Plot
	local center = Config.PlotCenter(index)
	local frame = CFrame.lookAt(center, Vector3.zero) * CFrame.new(0, FLOOR_Y, 0)
	local half = Config.PlotSize / 2
	local model = Build.model("Plot" .. index, parent)

	local plot = {
		Index = index,
		Owner = nil,
		Frame = frame,
		Model = model,
		Displays = Instance.new("Folder"),
		Pedestals = {},
	} :: any

	-- Stone border and grass floor
	Build.part(model, frame * CFrame.new(0, -FLOOR_Y / 2, 0), Vector3.new(half * 2 + 2, FLOOR_Y, half * 2 + 2), STONE, Enum.Material.Cobblestone)
	plot.Floor = Build.part(model, frame * CFrame.new(0, 0.05, 0), Vector3.new(half * 2 - 2, 0.1, half * 2 - 2), GRASS, Enum.Material.Grass)

	-- Fence on three sides, gate gap at the front
	local y = frame.Position.Y
	local function corner(x, z)
		return (frame * CFrame.new(x, 0, z)).Position
	end
	Props.FenceRun(model, corner(-half + 1, half - 1), corner(half - 1, half - 1), y)
	Props.FenceRun(model, corner(-half + 1, -half + 1), corner(-half + 1, half - 1), y)
	Props.FenceRun(model, corner(half - 1, -half + 1), corner(half - 1, half - 1), y)
	Props.FenceRun(model, corner(-half + 1, -half + 1), corner(-7, -half + 1), y)
	Props.FenceRun(model, corner(7, -half + 1), corner(half - 1, -half + 1), y)

	-- Gate lanterns and owner sign
	Props.Lantern(model, at(plot, -8, -half + 1), 8)
	Props.Lantern(model, at(plot, 8, -half + 1) * CFrame.Angles(0, math.pi, 0), 8)
	local _, setText = Props.SignBoard(model, at(plot, -17, -half + 3), "Empty plot", 14, Color3.fromRGB(110, 76, 50))
	plot.SetOwnerText = setText

	-- Stepping-stone path from the gate
	for i = 0, 5 do
		Build.cylinder(model, at(plot, (i % 2) * 1.2 - 0.6, -half + 3 + i * 4, 0.1), 0.15, 3.2, Color3.fromRGB(190, 182, 170), Enum.Material.Slate)
	end

	-- Brewing corner: cauldron, shelf of flasks, crates
	local _, brew, belly = Props.Cauldron(model, at(plot, -14, -12), 3.2, Color3.fromRGB(120, 255, 150))
	plot.Brew = brew
	local prompt = WorldBuilder.Prompt(belly, "Brew", "Your Cauldron", 12)
	prompt.Name = "BrewPrompt"
	local shelf = at(plot, -24, -10) * CFrame.Angles(0, math.rad(90), 0)
	Build.part(model, shelf * CFrame.new(0, 3, 0.6), Vector3.new(8, 6, 0.4), Color3.fromRGB(110, 76, 50), Enum.Material.WoodPlanks)
	local flaskColors = { Color3.fromRGB(196, 132, 92), Color3.fromRGB(140, 220, 255), Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 240, 150) }
	for row = 0, 1 do
		Build.part(model, shelf * CFrame.new(0, 1.8 + row * 2.2, 0), Vector3.new(8, 0.25, 1.4), Color3.fromRGB(130, 92, 60), Enum.Material.WoodPlanks)
		for i = 1, 4 do
			local col = flaskColors[((i + row) % 4) + 1]
			Build.ellipsoid(model, shelf * CFrame.new(-4.5 + i * 1.8, 2.4 + row * 2.2, 0), Vector3.new(1, 1.1, 1), col, Enum.Material.Glass, { Transparency = 0.1 })
			Build.cylinder(model, shelf * CFrame.new(-4.5 + i * 1.8, 3.1 + row * 2.2, 0), 0.4, 0.35, col, Enum.Material.Glass)
		end
	end
	Build.part(model, at(plot, -21, -18, 1.2) * CFrame.Angles(0, 0.3, 0), Vector3.new(2.4, 2.4, 2.4), Color3.fromRGB(150, 105, 65), Enum.Material.WoodPlanks)
	Build.part(model, at(plot, -21.5, -18, 3.2) * CFrame.Angles(0, -0.2, 0), Vector3.new(1.8, 1.6, 1.8), Color3.fromRGB(150, 105, 65), Enum.Material.WoodPlanks)

	-- Coin chest
	local _, lid = Props.CoinChest(model, at(plot, 15, -14) * CFrame.Angles(0, math.rad(180), 0))
	local collect = WorldBuilder.Prompt(lid, "Collect", "Coins", 10)
	collect.Name = "CollectPrompt"
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 46)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 120
	gui.Parent = lid
	local pending = Instance.new("TextLabel")
	pending.Size = UDim2.fromScale(1, 1)
	pending.BackgroundTransparency = 1
	pending.Font = Enum.Font.FredokaOne
	pending.TextScaled = true
	pending.TextColor3 = Color3.fromRGB(255, 225, 110)
	pending.TextStrokeTransparency = 0.2
	pending.Text = ""
	pending.Parent = gui
	plot.PendingLabel = pending

	-- Display pedestals: 4 x 3 in the back half
	for row = 0, 2 do
		for col = 0, 3 do
			local cf = at(plot, -16.5 + col * 11, 2 + row * 9.5)
			local _, top = Props.Pedestal(model, cf, Color3.fromRGB(150, 140, 170))
			table.insert(plot.Pedestals, { CFrame = cf, Top = top })
		end
	end

	-- Flowers along the back fence
	for i = -2, 2 do
		Props.FlowerPatch(model, at(plot, i * 10, half - 4, 0.1), 2.5)
	end

	plot.Displays.Name = "Displays"
	plot.Displays.Parent = model
	model.PrimaryPart = plot.Floor

	plot.BrewPrompt = prompt
	plot.CollectPrompt = collect

	return plot :: Plot
end

local function hookPrompts(plot)
	plot.BrewPrompt.Triggered:Connect(function(player)
		if plot.Owner ~= player then
			Remotes.Notify:FireClient(player, "That's someone else's cauldron. Use yours, or the big one in the hub.", "error")
			return
		end
		Remotes.OpenUI:FireClient(player, "Brew")
	end)

	plot.CollectPrompt.Triggered:Connect(function(player)
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
end

----------------------------------------------------------------------
-- Displays
----------------------------------------------------------------------
local function showGuardians(plot: Plot, entries: { any })
	plot.Displays:ClearAllChildren()
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		return Config.GuardianIncome(a) > Config.GuardianIncome(b)
	end)
	for i = 1, math.min(#list, #plot.Pedestals) do
		local entry = list[i]
		local def = Config.Guardians[entry.Id]
		if def then
			local slot = plot.Pedestals[i]
			local mutation = Config.Mutations[entry.Mutation or 0]
			local height = def.Size * (if mutation then mutation.Scale else 1)
			local model = GuardianModels.Build(entry.Id, entry.Mutation)
			model:PivotTo(slot.CFrame * CFrame.new(0, slot.Top + def.Size / 2, 0)) -- faces the gate
			GuardianModels.SitOnGround(model, slot.CFrame.Position.Y + slot.Top)
			model:SetAttribute("PlotGuardian", true)
			model:SetAttribute("DisplayName", Config.GuardianDisplayName(entry))
			model:SetAttribute("Income", Config.GuardianIncome(entry))

			-- glowing ring in the guardian's rarity colour
			local ring = Instance.new("Model")
			ring.Name = "RarityRing"
			Build.ring(ring, slot.CFrame * CFrame.new(0, slot.Top + 0.05, 0), 3.1, 0.3, 16, RARITY_COLORS[def.Rarity], Enum.Material.Neon)
			ring.Parent = model

			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(180, 40)
			gui.StudsOffsetWorldSpace = Vector3.new(0, height * 0.75 + 2, 0)
			gui.MaxDistance = 60
			gui.Adornee = model.PrimaryPart
			gui.Parent = model
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = RARITY_COLORS[def.Rarity]
			label.TextStrokeTransparency = 0.3
			label.Text = string.format("%s\n+%d/s", Config.GuardianDisplayName(entry), math.floor(Config.GuardianIncome(entry)))
			label.Parent = gui

			model.Parent = plot.Displays
		end
	end
end

function Plots.Refresh(player: Player)
	local plot = byPlayer[player]
	local data = PlayerData.Get(player)
	if plot and data then
		showGuardians(plot, data.Guardians)
	end
end

-- Used by the offline preview renderer: fills a plot with one of each guardian.
function Plots.PreviewFill(index: number)
	local plot = plots[index]
	local entries = {}
	for i, id in Config.GuardianOrder do
		table.insert(entries, { Id = id, Mutation = if i == 1 then 2 else 0 })
	end
	plot.SetOwnerText("Builderman's Plot")
	showGuardians(plot, entries)
end

----------------------------------------------------------------------
-- Ownership, spawning, brewing helpers
----------------------------------------------------------------------
function Plots.Get(player: Player): Plot?
	return byPlayer[player]
end

function Plots.SpawnCFrame(player: Player): CFrame?
	local plot = byPlayer[player]
	if not plot then
		return nil
	end
	local pos = (plot.Frame * CFrame.new(-4, 4, -18)).Position
	local look = (plot.Frame * CFrame.new(-14, 4, -12)).Position
	return CFrame.lookAt(pos, look)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The cauldron a player is standing at: their own, or the public one.
function Plots.NearbyBrew(player: Player, range: number): BasePart?
	local root = rootOf(player)
	if not root then
		return nil
	end
	local plot = byPlayer[player]
	if plot and (root.Position - plot.Brew.Position).Magnitude <= range then
		return plot.Brew
	end
	local public = WorldBuilder.PublicBrew
	if public and (root.Position - public.Position).Magnitude <= range + 8 then
		return public
	end
	return nil
end

function Plots.BrewEffect(brew: BasePart, color: Color3)
	local original = brew:GetAttribute("BaseColor") or brew.Color
	brew:SetAttribute("BaseColor", original)
	brew.Color = color
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(color)
	burst.LightEmission = 1
	burst.Speed = NumberRange.new(10, 18)
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Size = NumberSequence.new(1, 0)
	burst.SpreadAngle = Vector2.new(35, 35)
	burst.EmissionDirection = Enum.NormalId.Right
	burst.Rate = 0
	burst.Parent = brew
	burst:Emit(60)
	task.delay(2, function()
		burst:Destroy()
		TweenService:Create(brew, TweenInfo.new(1), { Color = original }):Play()
	end)
end

local function assign(player: Player)
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			byPlayer[player] = plot
			plot.SetOwnerText(player.DisplayName .. "'s Plot")
			plot.Floor.Color = GRASS_OWNED
			Plots.Refresh(player)
			return plot
		end
	end
	Remotes.Notify:FireClient(player, "All plots are taken. You can still brew at the hub cauldron!", "error")
	return nil
end

local function release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	plot.Owner = nil
	byPlayer[player] = nil
	plot.SetOwnerText("Empty plot")
	plot.PendingLabel.Text = ""
	plot.Floor.Color = GRASS
	plot.Displays:ClearAllChildren()
end

local function onCharacter(player: Player, character: Model)
	task.wait(0.2)
	local cf = Plots.SpawnCFrame(player)
	if cf and character.Parent then
		character:PivotTo(cf)
	end
end

function Plots.Build()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace
	for i = 1, Config.PlotCount do
		table.insert(plots, buildPlot(i, folder))
	end
end

function Plots.Start()
	Plots.Build()
	for _, plot in plots do
		hookPrompts(plot)
	end

	PlayerData.Loaded:Connect(function(player)
		assign(player)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end)
	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
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
