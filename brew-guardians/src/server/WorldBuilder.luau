-- Builds the whole map out of parts at server start, so the place runs with
-- no uploaded assets. Replace any of it with hand-built models later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

WorldBuilder.Hazards = {} :: { { Position: Vector3, Radius: number, Zone: string, Name: string, Part: BasePart } }
WorldBuilder.IngredientNodes = {} :: { Model }
WorldBuilder.Folder = nil :: Folder?
WorldBuilder.ShopPrompt = nil :: ProximityPrompt?

local rng = Random.new(20261011)

-- props.ClassName picks the class (defaults to Part).
local function part(props): Part
	local p = Instance.new(props.ClassName or "Part") :: Part
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

WorldBuilder.Part = part

local function disc(name, center: Vector3, radius: number, height: number, color: Color3, material, parent)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

WorldBuilder.Disc = disc

local function sign(parent: Instance, position: Vector3, text: string, color: Color3)
	local post = part({
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 4, 0)),
		Color = Color3.fromRGB(110, 80, 50),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.MaxDistance = 250
	gui.AlwaysOnTop = false
	gui.Parent = post
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return post
end

WorldBuilder.Sign = sign

-- Random point in a zone that keeps clear of the given points.
local function scatter(center: Vector3, radius: number, avoid: { Vector3 }, minGap: number): Vector3
	local best = center
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * radius
		local candidate = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = true
		for _, p in avoid do
			if (p - candidate).Magnitude < minGap then
				ok = false
				break
			end
		end
		best = candidate
		if ok then
			break
		end
	end
	return best
end

local function buildDecor(kind: string, position: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = kind
	if kind == "Tree" then
		local h = rng:NextNumber(10, 18)
		part({
			Size = Vector3.new(2.5, h, 2.5),
			CFrame = CFrame.new(position + Vector3.new(0, h / 2, 0)),
			Color = Color3.fromRGB(105, 75, 50),
			Material = Enum.Material.Wood,
			Parent = model,
		})
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(9, 13),
			CFrame = CFrame.new(position + Vector3.new(0, h + 2, 0)),
			Color = Color3.fromRGB(70, 150, 70),
			Material = Enum.Material.Grass,
			Parent = model,
		})
	elseif kind == "Rock" then
		local s = rng:NextNumber(5, 12)
		part({
			Size = Vector3.new(s, s * 0.8, s * 1.1),
			CFrame = CFrame.new(position + Vector3.new(0, s * 0.3, 0))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
			Color = Color3.fromRGB(55, 45, 45),
			Material = Enum.Material.Basalt,
			Parent = model,
		})
	else
		local h = rng:NextNumber(6, 14)
		part({
			Size = Vector3.new(2.5, h, 2.5),
			CFrame = CFrame.new(position + Vector3.new(0, h / 2 - 0.5, 0))
				* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6), rng:NextNumber(-0.35, 0.35)),
			Color = Color3.fromRGB(170, 220, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Parent = model,
		})
	end
	model.Parent = parent
	return model
end

local function buildHazard(zoneId: string, zone, position: Vector3, parent: Instance)
	local r = Config.HazardRadius
	local base = disc(zone.HazardName, position + Vector3.new(0, 0.15, 0), r, 0.4, zone.HazardColor, nil, parent)
	base.CanCollide = false
	base:SetAttribute("Hazard", true)
	base:SetAttribute("Zone", zoneId)

	if zoneId == "Caldera" then
		base.Material = Enum.Material.Neon
		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 12
		fire.Parent = base
	else
		for i = 1, 7 do
			local a = (i / 7) * math.pi * 2
			local d = rng:NextNumber(1, r - 1.5)
			local spikePos = position + Vector3.new(math.cos(a) * d, 1.5, math.sin(a) * d)
			local spike = part({
				Name = "Spike",
				ClassName = "WedgePart",
				Size = Vector3.new(1.2, 3, 1.2),
				CFrame = CFrame.new(spikePos) * CFrame.Angles(0, a, 0),
				Color = zone.HazardColor,
				Material = if zoneId == "Frost" then Enum.Material.Ice else Enum.Material.Grass,
				CanCollide = false,
				Parent = base,
			})
			spike.CastShadow = false
		end
	end

	table.insert(WorldBuilder.Hazards, {
		Position = position,
		Radius = r,
		Zone = zoneId,
		Name = zone.HazardName,
		Part = base,
	})
end

local function buildIngredientNode(ingredientId: string, position: Vector3, parent: Instance)
	local def = Config.Ingredients[ingredientId]
	local model = Instance.new("Model")
	model.Name = "Node_" .. ingredientId
	model:SetAttribute("IngredientId", ingredientId)

	local stem = part({
		Name = "Stem",
		Size = Vector3.new(0.4, 2.2, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 1.1, 0)),
		Color = Color3.fromRGB(70, 130, 60),
		CanCollide = false,
		Parent = model,
	})
	local bloom = part({
		Name = "Bloom",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (1.4 + def.Tier * 0.35),
		CFrame = CFrame.new(position + Vector3.new(0, 2.6, 0)),
		Color = def.Color,
		Material = if def.Tier >= 3 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = stem

	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = 6 + def.Tier * 2
	light.Brightness = 0.8
	light.Parent = bloom

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(def.Color)
	sparkle.Size = NumberSequence.new(0.3, 0)
	sparkle.Lifetime = NumberRange.new(0.6, 1.2)
	sparkle.Rate = def.Tier * 2
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = bloom

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HarvestPrompt"
	prompt.ActionText = "Harvest"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0.3 + def.Tier * 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = bloom

	model.Parent = parent
	table.insert(WorldBuilder.IngredientNodes, model)
end

local function buildZone(zoneId: string, folder: Folder)
	local zone = Config.Zones[zoneId]
	local center = Config.ZoneCenter(zoneId)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneId
	zoneFolder.Parent = folder

	local floorMaterial = if zoneId == "Frost"
		then Enum.Material.Snow
		elseif zoneId == "Caldera" then Enum.Material.Slate
		else Enum.Material.Grass
	disc("Floor", center + Vector3.new(0, 0.05, 0), zone.Radius + 10, 0.3, zone.Floor, floorMaterial, zoneFolder)

	local inward = (Vector3.zero - center).Unit
	local side = Vector3.new(-inward.Z, 0, inward.X)
	sign(zoneFolder, center + inward * (zone.Radius + 4) + side * 14, zone.Name, Color3.fromRGB(255, 255, 255))

	-- Decor ring around the edge so the zone reads as a place.
	for i = 1, 26 do
		local a = (i / 26) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local r = zone.Radius + rng:NextNumber(2, 14)
		local pos = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		-- leave a gap where the path comes in
		local toHub = (Vector3.zero - center).Unit
		local dir = (pos - center).Unit
		if dir:Dot(toHub) < 0.93 then
			buildDecor(zone.DecorKind, pos, zoneFolder)
		end
	end

	local taken = {}
	local hazardFolder = Instance.new("Folder")
	hazardFolder.Name = "Hazards"
	hazardFolder.Parent = zoneFolder
	for _ = 1, zone.Hazards do
		local pos = scatter(center, zone.Radius - 15, taken, 30)
		table.insert(taken, pos)
		buildHazard(zoneId, zone, pos, hazardFolder)
	end

	local nodeFolder = Instance.new("Folder")
	nodeFolder.Name = "Ingredients"
	nodeFolder.Parent = zoneFolder
	for _, ingredientId in Config.IngredientOrder do
		local count = Config.Ingredients[ingredientId].Zones[zoneId]
		for _ = 1, count or 0 do
			local pos = scatter(center, zone.Radius - 6, taken, 14)
			table.insert(taken, pos)
			buildIngredientNode(ingredientId, pos, nodeFolder)
		end
	end
end

local function buildPath(fromRadius: number, angleDeg: number, toDistance: number, folder: Folder)
	local a = math.rad(angleDeg)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local length = toDistance - fromRadius
	local mid = dir * (fromRadius + length / 2)
	part({
		Name = "Path",
		Size = Vector3.new(18, 0.3, length + 4),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.1, 0), mid + dir + Vector3.new(0, 0.1, 0)),
		Color = Color3.fromRGB(200, 180, 140),
		Material = Enum.Material.Pebble,
		Parent = folder,
	})
end

local function buildHub(folder: Folder)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = folder

	disc("HubFloor", Vector3.new(0, 0.1, 0), Config.HubRadius, 0.4, Color3.fromRGB(220, 205, 175), Enum.Material.Cobblestone, hub)

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 20)
	spawn.Color = Color3.fromRGB(180, 140, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Duration = 0
	spawn.Parent = hub

	-- Giant decorative cauldron in the middle.
	disc("Cauldron", Vector3.new(0, 4, 0), 9, 8, Color3.fromRGB(40, 40, 50), Enum.Material.Metal, hub)
	local brew = disc("Brew", Vector3.new(0, 8.1, 0), 8, 0.3, Color3.fromRGB(150, 90, 255), Enum.Material.Neon, hub)
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(200, 150, 255))
	bubbles.Rate = 15
	bubbles.Lifetime = NumberRange.new(1, 2)
	bubbles.Speed = NumberRange.new(3, 6)
	bubbles.Size = NumberSequence.new(0.8, 0)
	bubbles.EmitterDirection = Enum.NormalId.Right
	bubbles.Parent = brew

	-- Shop stall
	local stall = Instance.new("Model")
	stall.Name = "ShopStall"
	local counter = part({
		Name = "Counter",
		Size = Vector3.new(14, 4, 4),
		CFrame = CFrame.new(0, 2, -40),
		Color = Color3.fromRGB(150, 100, 60),
		Material = Enum.Material.WoodPlanks,
		Parent = stall,
	})
	part({
		Name = "Awning",
		Size = Vector3.new(16, 0.6, 8),
		CFrame = CFrame.new(0, 10, -41) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = Color3.fromRGB(200, 70, 90),
		Parent = stall,
	})
	for _, x in { -7, 7 } do
		part({
			Size = Vector3.new(0.8, 10, 0.8),
			CFrame = CFrame.new(x, 5, -42),
			Color = Color3.fromRGB(110, 80, 50),
			Material = Enum.Material.Wood,
			Parent = stall,
		})
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Vials & Cauldrons"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	stall.Parent = hub
	WorldBuilder.ShopPrompt = prompt
	sign(hub, Vector3.new(10, 0, -38), "Shop", Color3.fromRGB(255, 220, 120))

	for _, zoneId in Config.ZoneOrder do
		local zone = Config.Zones[zoneId]
		local a = math.rad(zone.Angle)
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * (Config.HubRadius - 6)
		sign(hub, pos + Vector3.new(math.sin(a), 0, -math.cos(a)) * 12, "→ " .. zone.Name, Color3.fromRGB(255, 255, 255))
	end
end

function WorldBuilder.Build()
	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = workspace
	WorldBuilder.Folder = folder

	local ground = part({
		Name = "Ground",
		Size = Vector3.new(2048, 4, 2048),
		CFrame = CFrame.new(0, -2, 0),
		Color = Color3.fromRGB(120, 175, 95),
		Material = Enum.Material.Grass,
		Parent = folder,
	})
	ground.Locked = true

	buildHub(folder)
	for _, zoneId in Config.ZoneOrder do
		local zone = Config.Zones[zoneId]
		buildPath(Config.HubRadius - 2, zone.Angle, zone.Distance - zone.Radius, folder)
		buildZone(zoneId, folder)
	end

	return folder
end

return WorldBuilder
