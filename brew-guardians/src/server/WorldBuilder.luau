-- Builds the whole map out of parts at server start, so the place runs with
-- no uploaded assets. Replace any of it with hand-built models later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local Landscape = require(script.Parent.Landscape)
local Props = require(script.Parent.Props)

local WorldBuilder = {}

WorldBuilder.Hazards = {} :: { { Position: Vector3, Radius: number, Zone: string, Name: string, Part: BasePart } }
WorldBuilder.IngredientNodes = {} :: { Model }
WorldBuilder.Folder = nil :: Folder?
WorldBuilder.ShopPrompt = nil :: ProximityPrompt?
WorldBuilder.PublicBrew = nil :: BasePart? -- the big hub cauldron anyone can brew at
WorldBuilder.PublicBrewPrompt = nil :: ProximityPrompt?

local rng = Random.new(20261011)

local COBBLE = Color3.fromRGB(196, 186, 168)
local COBBLE_DARK = Color3.fromRGB(160, 150, 136)

-- Generic part helper kept for the telegraph effects in GuardianService.
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

-- Flat disc centred on `center` (cylinder lying on its side).
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

local function prompt(parent: Instance, action: string, object: string, distance: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end
WorldBuilder.Prompt = prompt

local function polar(angleDeg: number, radius: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end

-- Ground frame at `pos` facing toward `lookAt` (front = -Z).
local function facing(pos: Vector3, lookAt: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
end

-- Random point in a disc that keeps clear of the given points.
local function scatter(center: Vector3, radius: number, avoid: { Vector3 }, minGap: number): Vector3
	local best = center
	for _ = 1, 50 do
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

----------------------------------------------------------------------
-- Zones
----------------------------------------------------------------------
local ZONE_STYLE = {
	Meadow = { Floor = Enum.Material.Grass, Tree = "Round", Tree2 = "Pine", Rock = Color3.fromRGB(150, 150, 140), Accent = Color3.fromRGB(140, 230, 110) },
	Caldera = { Floor = Enum.Material.Slate, Tree = "Dead", Tree2 = "Dead", Rock = Color3.fromRGB(60, 48, 46), Accent = Color3.fromRGB(255, 120, 40) },
	Frost = { Floor = Enum.Material.Snow, Tree = "SnowPine", Tree2 = "SnowPine", Rock = Color3.fromRGB(190, 210, 225), Accent = Color3.fromRGB(150, 210, 255) },
}

local function buildHazard(zoneId: string, zone, position: Vector3, parent: Instance)
	local r = Config.HazardRadius
	local m = Build.model(zone.HazardName, parent)
	local ground = CFrame.new(position)
	local base: BasePart

	if zoneId == "Caldera" then
		base = Build.cylinder(m, ground * CFrame.new(0, 0.25, 0), 0.3, r * 1.6, Color3.fromRGB(255, 110, 30), Enum.Material.Neon, { CanCollide = false })
		Build.cylinder(m, ground * CFrame.new(0, 0.32, 0), 0.3, r * 0.9, Color3.fromRGB(255, 210, 90), Enum.Material.Neon, { CanCollide = false })
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			Props.Rocks(m, ground * CFrame.new(math.cos(a) * r * 0.95, 0, math.sin(a) * r * 0.95), rng:NextNumber(2.4, 3.6), Color3.fromRGB(45, 36, 34), Enum.Material.Basalt)
		end
		local fire = Instance.new("Fire")
		fire.Size = 10
		fire.Heat = 14
		fire.Parent = base
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(70, 60, 60)
		smoke.Opacity = 0.15
		smoke.RiseVelocity = 6
		smoke.Size = 6
		smoke.Parent = base
		Build.light(base, Color3.fromRGB(255, 120, 40), 22, 2)
	elseif zoneId == "Frost" then
		base = Build.cylinder(m, ground * CFrame.new(0, 0.22, 0), 0.25, r * 2, Color3.fromRGB(175, 225, 255), Enum.Material.Ice, { CanCollide = false })
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local d = if i == 1 then 0 else r * 0.55
			Props.Crystals(m, ground * CFrame.new(math.cos(a) * d, 0, math.sin(a) * d), rng:NextNumber(3, 4.5), Color3.fromRGB(170, 225, 255), false)
		end
	else
		base = Build.cylinder(m, ground * CFrame.new(0, 0.22, 0), 0.25, r * 2, Color3.fromRGB(70, 90, 45), Enum.Material.Grass, { CanCollide = false })
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2 + rng:NextNumber(0, 0.5)
			local d = if i == 1 then 0 else r * rng:NextNumber(0.4, 0.7)
			local s = rng:NextNumber(3.5, 5.5)
			local bush = CFrame.new(position + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
			Build.ellipsoid(m, bush * CFrame.new(0, s * 0.35, 0), Vector3.new(s, s * 0.7, s), Color3.fromRGB(46, 74, 40), Enum.Material.Grass, { CanCollide = false })
			for k = 1, 5 do
				local ta = k / 5 * math.pi * 2
				Build.spike(m, bush * CFrame.new(math.cos(ta) * s * 0.4, s * 0.35, math.sin(ta) * s * 0.4) * CFrame.Angles(math.sin(ta) * 1.2, 0, -math.cos(ta) * 1.2), 1.4, 0.4, Color3.fromRGB(150, 40, 50), nil, { CanCollide = false })
			end
		end
	end

	Landscape.Hazard(zoneId, position, r)
	base.Name = "HazardBase"
	base:SetAttribute("Hazard", true)
	base:SetAttribute("Zone", zoneId)
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
	local m, focus = Props.Plant(parent, CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), def.Style or "Flower", def.Color, def.Tier)
	m:ScaleTo(1.6)
	Build.sitOnGround(m, position.Y)
	m.Name = "Node_" .. ingredientId
	m:SetAttribute("IngredientId", ingredientId)
	local p = prompt(focus, "Harvest", def.Name, 10)
	p.Name = "HarvestPrompt"
	p.HoldDuration = 0.3 + def.Tier * 0.25
	table.insert(WorldBuilder.IngredientNodes, m)
end

local function buildZone(zoneId: string, folder: Folder)
	local zone = Config.Zones[zoneId]
	local style = ZONE_STYLE[zoneId]
	local center = Config.ZoneCenter(zoneId)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneId
	zoneFolder.Parent = folder

	local inward = (Vector3.zero - center).Unit
	Landscape.Zone(zoneId)

	-- Gate where the path arrives
	local gatePos = center + inward * (zone.Radius + 10)
	Props.Gate(zoneFolder, facing(gatePos + Vector3.new(0, 0.2, 0), Vector3.zero), 20, zone.Name, style.Accent)

	-- Dense border so the zone reads as a place
	for i = 1, 80 do
		local a = (i / 80) * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		if dir:Dot(inward) < 0.95 then
			local pos = center + dir * (zone.Radius + (if i % 2 == 0 then rng:NextNumber(2, 9) else rng:NextNumber(11, 22)))
			local ground = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
			local roll = rng:NextNumber()
			if roll < 0.55 then
				Props.Tree(zoneFolder, ground, if roll < 0.3 then style.Tree else style.Tree2)
			elseif zoneId == "Frost" and roll < 0.8 then
				Props.Crystals(zoneFolder, ground, rng:NextNumber(4, 7), Color3.fromRGB(170, 220, 255), rng:NextNumber() < 0.3)
			else
				Props.Rocks(zoneFolder, ground, rng:NextNumber(4, 8), style.Rock)
			end
		end
	end

	local taken = { gatePos }
	local hazardFolder = Instance.new("Folder")
	hazardFolder.Name = "Hazards"
	hazardFolder.Parent = zoneFolder
	for _ = 1, zone.Hazards do
		local pos = scatter(center, zone.Radius - 16, taken, 30)
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

	-- Inner scenery, kept clear of hazards, plants and each other
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = zoneFolder
	for i = 1, 28 do
		local pos = scatter(center, zone.Radius - 8, taken, 15)
		table.insert(taken, pos)
		local ground = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
		local roll = i % 4
		if zoneId == "Meadow" then
			if roll == 0 then
				Props.Tree(decor, ground, "Round")
			elseif roll == 1 then
				Props.FlowerPatch(decor, ground, 5)
			elseif roll == 2 then
				Props.Rocks(decor, ground, rng:NextNumber(2.5, 4.5), style.Rock)
			else
				-- fallen log with mushrooms
				Build.cylinder(decor, ground * CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(90), 0, 0), 9, 2, Color3.fromRGB(110, 78, 52), Enum.Material.Wood)
				Build.ellipsoid(decor, ground * CFrame.new(0.9, 2, 2), Vector3.new(1.4, 0.6, 1.4), Color3.fromRGB(220, 70, 60))
			end
		elseif zoneId == "Caldera" then
			if roll == 0 then
				Props.Rocks(decor, ground, rng:NextNumber(7, 11), Color3.fromRGB(46, 38, 36))
			elseif roll == 1 then
				-- glowing crack in the ground
				Build.part(decor, ground * CFrame.new(0, 0.28, 0), Vector3.new(1, 0.1, rng:NextNumber(12, 22)), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, { CanCollide = false })
			elseif roll == 2 then
				Props.Tree(decor, ground, "Dead")
			else
				Props.Rocks(decor, ground, rng:NextNumber(3, 6), style.Rock, Enum.Material.Basalt)
			end
		else
			if roll == 0 then
				Props.Tree(decor, ground, "SnowPine")
			elseif roll == 1 then
				Build.ellipsoid(decor, ground * CFrame.new(0, 0.6, 0), Vector3.new(rng:NextNumber(8, 14), 2.4, rng:NextNumber(6, 10)), Color3.fromRGB(245, 250, 255), Enum.Material.Snow, { CanCollide = false })
			elseif roll == 2 then
				Props.Crystals(decor, ground, rng:NextNumber(2.5, 4), Color3.fromRGB(190, 230, 255), true)
			else
				Build.cylinder(decor, ground * CFrame.new(0, 0.3, 0), 0.1, rng:NextNumber(10, 16), Color3.fromRGB(160, 215, 245), Enum.Material.Ice, { CanCollide = false })
			end
		end
	end
end

----------------------------------------------------------------------
-- Paths
----------------------------------------------------------------------
local function buildPath(from: Vector3, to: Vector3, width: number, folder: Instance)
	local dir = (to - from)
	local length = dir.Magnitude
	local mid = (from + to) / 2
	local cf = CFrame.lookAt(mid, mid + dir.Unit)
	Landscape.Path(from, to, width)
	-- edge stones
	local count = math.floor(length / 7)
	for i = 0, count do
		for _, side in { -1, 1 } do
			local z = -length / 2 + (i / math.max(count, 1)) * length
			Build.part(folder, cf * CFrame.new(side * (width / 2 + 0.5), 0.35, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Vector3.new(1.4, 0.7, 2.2), COBBLE_DARK, Enum.Material.Slate)
		end
	end
end

----------------------------------------------------------------------
-- Hub
----------------------------------------------------------------------
local function buildHub(folder: Folder)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = folder
	local R = Config.HubRadius

	-- Plaza: textured terrain cobbles with a stone kerb and a glowing ring
	Landscape.Plaza(R)
	Build.ring(hub, CFrame.new(0, 0.3, 0), R - 1, 1.2, 64, COBBLE_DARK, Enum.Material.Slate)
	Build.ring(hub, CFrame.new(0, 0.12, 0), 34, 0.8, 48, Color3.fromRGB(150, 110, 230), Enum.Material.Neon)

	for i = 0, 7 do
		local a = i * 45
		-- planter with a tree between the stripes
		local planter = polar(a + 22.5, 70)
		Build.cylinder(hub, CFrame.new(planter + Vector3.new(0, 0.8, 0)), 1.6, 8, COBBLE_DARK, Enum.Material.Slate)
		Props.Tree(hub, CFrame.new(planter + Vector3.new(0, 1.6, 0)), "Round")
	end

	-- Dais with the giant public cauldron
	for i, rad in { 22, 17, 12.5 } do
		Build.cylinder(hub, CFrame.new(0, 0.3 + i * 0.9 - 0.45, 0), 0.9, rad * 2, if i % 2 == 0 then COBBLE else COBBLE_DARK, Enum.Material.Slate)
	end
	local _, brew, belly = Props.Cauldron(hub, CFrame.new(0, 2.95, 0), 6, Color3.fromRGB(170, 110, 255))
	WorldBuilder.PublicBrew = brew
	WorldBuilder.PublicBrewPrompt = prompt(belly, "Brew", "Public Cauldron", 16)

	-- Lanterns, benches and flower beds around the plaza
	for i = 0, 7 do
		local a = i * 45 + 22.5
		Props.Lantern(hub, facing(polar(a, R - 8), Vector3.zero) * CFrame.Angles(0, math.pi, 0), 10)
		if i % 2 == 0 then
			Props.Bench(hub, facing(polar(a + 22.5, 42), Vector3.zero))
		else
			local bed = polar(a + 22.5, 44)
			Build.cylinder(hub, CFrame.new(bed + Vector3.new(0, 0.6, 0)), 1.2, 9, COBBLE_DARK, Enum.Material.Slate)
			Build.cylinder(hub, CFrame.new(bed + Vector3.new(0, 1.0, 0)), 0.6, 8, Color3.fromRGB(90, 62, 44), Enum.Material.Ground)
			Props.FlowerPatch(hub, CFrame.new(bed + Vector3.new(0, 1.3, 0)), 3)
		end
	end

	-- Shop stall, clear of the zone paths
	local stallPos = polar(210, 62) + Vector3.new(0, 0.3, 0)
	local _, counter = Props.Stall(hub, facing(stallPos, Vector3.zero), Color3.fromRGB(230, 80, 100), Color3.fromRGB(255, 240, 230))
	WorldBuilder.ShopPrompt = prompt(counter, "Shop", "Vials & Cauldrons", 12)
	-- two more stalls so the plaza reads as a market
	Props.Stall(hub, facing(polar(90, 64) + Vector3.new(0, 0.3, 0), Vector3.zero), Color3.fromRGB(80, 150, 230), Color3.fromRGB(240, 245, 255))
	Props.Stall(hub, facing(polar(330, 64) + Vector3.new(0, 0.3, 0), Vector3.zero), Color3.fromRGB(110, 190, 90), Color3.fromRGB(255, 240, 200))
	Props.SignBoard(hub, facing(stallPos, Vector3.zero) * CFrame.new(11, 0, -2), "SHOP", 8, Color3.fromRGB(150, 60, 80))

	-- Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 40)
	spawn.Color = Color3.fromRGB(170, 130, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub
end

function WorldBuilder.Build()
	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = workspace
	WorldBuilder.Folder = folder

	Landscape.Base()

	buildHub(folder)

	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = folder
	for _, zoneId in Config.ZoneOrder do
		local zone = Config.Zones[zoneId]
		local dir = polar(zone.Angle, 1)
		buildPath(dir * (Config.HubRadius - 2), dir * (zone.Distance - zone.Radius - 10), 16, paths)
		-- Gate where the path leaves the hub
		Props.Gate(folder, facing(dir * (Config.HubRadius + 4) + Vector3.new(0, 0.1, 0), dir * 1000), 20, "→ " .. zone.Name, ZONE_STYLE[zoneId].Accent)
		buildZone(zoneId, folder)
	end
	for i = 1, Config.PlotCount do
		local center = Config.PlotCenter(i)
		local dir = center.Unit
		buildPath(dir * (Config.HubRadius - 2), dir * (Config.PlotRadius - Config.PlotSize / 2), 10, paths)
	end

	Landscape.Scenery(folder)

	return folder
end

return WorldBuilder
