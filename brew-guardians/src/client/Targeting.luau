-- Tap/click a guardian to use the selected flask, draught or ingredient.
-- Also draws each guardian's overhead panel with live catch odds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local T = UI.Theme
local player = Players.LocalPlayer

local Targeting = {}

local guardianFolder: Folder
local highlight: Highlight
local panels: { [Model]: { Gui: BillboardGui, Bar: Frame, Status: TextLabel, Odds: TextLabel } } = {}

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function guardianFrom(instance: Instance?): Model?
	while instance and instance ~= guardianFolder do
		if instance.Parent == guardianFolder and instance:IsA("Model") then
			return instance
		end
		instance = instance.Parent
	end
	return nil
end

local function raycastScreen(position: Vector2): Model?
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { guardianFolder }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if result then
		return guardianFrom(result.Instance)
	end
	-- Forgiving fallback for small targets on touch screens: nearest guardian
	-- whose screen position is close to the tap.
	local best, bestDist = nil, 70
	for _, model in guardianFolder:GetChildren() do
		if model:IsA("Model") then
			local screenPos, onScreen = camera:WorldToScreenPoint(model:GetPivot().Position)
			if onScreen then
				local d = (Vector2.new(screenPos.X, screenPos.Y) - position).Magnitude
				if d < bestDist then
					best, bestDist = model, d
				end
			end
		end
	end
	return best
end

local function nearestGuardian(): Model?
	local root = myRoot()
	if not root then
		return nil
	end
	local best, bestDist = nil, Config.Catch.ThrowRange
	for _, model in guardianFolder:GetChildren() do
		if model:IsA("Model") then
			local d = (model:GetPivot().Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = model, d
			end
		end
	end
	return best
end

local lastAct = 0
local function act(model: Model)
	if os.clock() - lastAct < 0.3 then
		return
	end
	lastAct = os.clock()
	local root = myRoot()
	if not root then
		return
	end
	local sel = State.Selected
	if State.SelectedCount() <= 0 then
		if sel.Kind == "Feed" then
			Hud.Toast("Pick an ingredient with the Feed button first.", "error")
		else
			Hud.Toast("You're out of that. Brew more at your cauldron!", "error")
		end
		return
	end
	local distance = (model:GetPivot().Position - root.Position).Magnitude
	if sel.Kind == "Feed" then
		Remotes.Feed:FireServer(model, sel.Id)
	else
		if distance > Config.Catch.ThrowRange then
			Hud.Toast("Too far away to throw.", "error")
			return
		end
		Remotes.Throw:FireServer(sel.Kind, sel.Id, model)
	end
end

----------------------------------------------------------------------
-- Overhead panels
----------------------------------------------------------------------
local function chanceFor(model: Model, flaskMult: number): number
	local def = Config.Guardians[model:GetAttribute("GuardianId") :: string]
	local data = State.Data
	local luck = if data and (data.LuckUntil or 0) > os.time() then Config.Monetization.LuckBoostMultiplier else 1
	return CatchMath.Chance({
		BaseRate = def.BaseRate,
		FlaskMult = flaskMult,
		Resistance = (model:GetAttribute("Resistance") :: number?) or 100,
		FedFavorite = model:GetAttribute("FedFavorite") == true,
		Stunned = model:GetAttribute("Stunned") == true,
		Slowed = model:GetAttribute("Slowed") == true,
		Luck = luck,
	})
end

local function addPanel(instance: Instance)
	if not instance:IsA("Model") or panels[instance :: Model] then
		return
	end
	local model = instance :: Model
	local id = model:GetAttribute("GuardianId") :: string?
	local def = id and Config.Guardians[id]
	if not def then
		return
	end
	local rarity = Config.Rarities[def.Rarity]
	local gui = UI.make("BillboardGui", {
		Name = "GuardianPanel",
		Adornee = model.PrimaryPart,
		Size = UDim2.fromOffset(200, 84),
		StudsOffsetWorldSpace = Vector3.new(0, def.Size * 0.9 + 2, 0),
		MaxDistance = 120,
		AlwaysOnTop = true,
		Parent = player:WaitForChild("PlayerGui"),
	})
	gui.Size = UDim2.fromOffset(220, 96)
	UI.text({
		Text = def.Name,
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = rarity.Color,
		TextStrokeTransparency = 0,
		Parent = gui,
	})
	local barBack = UI.make("Frame", {
		Position = UDim2.new(0.08, 0, 0, 30),
		Size = UDim2.new(0.84, 0, 0, 14),
		BackgroundColor3 = T.PanelDark,
		Corner = 7,
		Stroke = T.Outline,
		StrokeThickness = 2,
		Parent = gui,
	})
	local bar = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 110, 90),
		Corner = 7,
		Parent = barBack,
	})
	local status = UI.text({
		Text = "",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = T.Text,
		Parent = gui,
	})
	local oddsPill = UI.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.fromOffset(180, 26),
		Color = T.PanelDark,
		Corner = 13,
		StrokeThickness = 2,
		Parent = gui,
	})
	local odds = UI.text({
		Text = "",
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -16, 1, -6),
		TextColor3 = T.Gold,
		Parent = oddsPill,
	})
	panels[model] = { Gui = gui, Bar = bar, Status = status, Odds = odds }
end

local function removePanel(model: Instance)
	local panel = panels[model :: Model]
	if panel then
		panel.Gui:Destroy()
		panels[model :: Model] = nil
	end
end

local function updatePanels()
	local sel = State.Selected
	local data = State.Data
	for model, panel in panels do
		local resistance = (model:GetAttribute("Resistance") :: number?) or 100
		panel.Bar.Size = UDim2.fromScale(resistance / 100, 1)
		panel.Bar.BackgroundColor3 = Color3.fromRGB(110, 220, 120):Lerp(Color3.fromRGB(255, 90, 80), resistance / 100)

		local tags = {}
		if model:GetAttribute("FedFavorite") then
			table.insert(tags, "♥ Fed")
		end
		if model:GetAttribute("Stunned") then
			table.insert(tags, "✦ Stunned")
		elseif model:GetAttribute("Slowed") then
			table.insert(tags, "Slowed")
		end
		if model:GetAttribute("Enraged") then
			table.insert(tags, "FURIOUS")
		elseif model:GetAttribute("Calm") then
			table.insert(tags, "Calm")
		end
		panel.Status.Text = if #tags > 0 then table.concat(tags, "  ") else string.format("Resistance %d", resistance)

		local id = model:GetAttribute("GuardianId") :: string
		if sel.Kind == "Flask" then
			local flask = Config.GetFlask(sel.Id)
			if flask then
				panel.Odds.Text = string.format("%s: %d%%", flask.Name, math.floor(chanceFor(model, flask.Mult) * 100 + 0.5))
			end
		elseif sel.Kind == "Feed" then
			local j = data and data.Journal[id]
			local def = Config.Guardians[id]
			panel.Odds.Text = if j and j.FavoriteKnown
				then "Loves " .. Config.Ingredients[def.Favorite].Name
				else "Favorite: ???"
		else
			panel.Odds.Text = "Weaken it!"
		end
	end
end

----------------------------------------------------------------------
function Targeting.Init()
	guardianFolder = workspace:WaitForChild("Guardians") :: Folder

	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = T.Gold
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = workspace

	guardianFolder.ChildAdded:Connect(function(child)
		-- Attributes and PrimaryPart may replicate a frame later.
		task.wait()
		if child.Parent == guardianFolder then
			addPanel(child)
		end
	end)
	guardianFolder.ChildRemoved:Connect(removePanel)
	for _, child in guardianFolder:GetChildren() do
		addPanel(child)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local model = raycastScreen(Vector2.new(input.Position.X, input.Position.Y))
			if model then
				act(model)
			end
		elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
			local model = nearestGuardian()
			if model then
				act(model)
			else
				Hud.Toast("No guardian in range.", "error")
			end
		end
	end)

	local accum = 0
	RunService.RenderStepped:Connect(function(dt)
		if UserInputService.MouseEnabled then
			local mouse = UserInputService:GetMouseLocation()
			local camera = workspace.CurrentCamera
			local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { guardianFolder }
			local result = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
			highlight.Adornee = if result then guardianFrom(result.Instance) else nil
		end
		accum += dt
		if accum > 0.1 then
			accum = 0
			updatePanels()
		end
	end)
end

return Targeting
