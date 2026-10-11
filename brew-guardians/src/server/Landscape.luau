-- Terrain: the ground everything stands on. Uses Roblox's built-in terrain
-- materials (swaying grass, snow, glacier ice, glowing cracked lava, water),
-- so it looks rich without any uploaded textures.
--
-- Play areas (hub, plots, zones, paths) stay flat at y = 0 because guardians
-- walk on a flat plane; hills, mountains, the volcano, the lake and forests
-- fill everything around them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local Landscape = {}

local M = Enum.Material
local rng = Random.new(4242)

local LAKE_ANGLE, LAKE_DISTANCE, LAKE_RADIUS = 90, 400, 70
local VOLCANO_ANGLE, VOLCANO_DISTANCE = 30, 760

local function terrain(): Terrain
	return workspace:FindFirstChildOfClass("Terrain") :: Terrain
end

local function polar(angleDeg: number, radius: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function distToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

-- Which zone's look a spot should borrow (by angle around the hub).
local function regionOf(p: Vector3): string
	if p.Magnitude < Config.PlotRadius + 80 then
		return "Meadow"
	end
	local best, bestDot = "Meadow", -2
	for _, zoneId in Config.ZoneOrder do
		local d = flat(p).Unit:Dot(Config.ZoneCenter(zoneId).Unit)
		if d > bestDot then
			best, bestDot = zoneId, d
		end
	end
	return best
end
Landscape.RegionOf = regionOf

-- True when a point (plus margin) would intrude on somewhere people play.
function Landscape.IsPlayArea(p: Vector3, margin: number): boolean
	p = flat(p)
	if p.Magnitude < Config.HubRadius + margin then
		return true
	end
	for i = 1, Config.PlotCount do
		if (p - Config.PlotCenter(i)).Magnitude < Config.PlotSize * 0.75 + margin then
			return true
		end
		local dir = Config.PlotCenter(i).Unit
		if distToSegment(p, dir * Config.HubRadius, dir * Config.PlotRadius) < 8 + margin then
			return true
		end
	end
	for _, zoneId in Config.ZoneOrder do
		local zone = Config.Zones[zoneId]
		local center = Config.ZoneCenter(zoneId)
		if (p - center).Magnitude < zone.Radius + 24 + margin then
			return true
		end
		local dir = center.Unit
		if distToSegment(p, dir * Config.HubRadius, dir * (zone.Distance - zone.Radius)) < 12 + margin then
			return true
		end
	end
	if (p - polar(LAKE_ANGLE, LAKE_DISTANCE)).Magnitude < LAKE_RADIUS + 18 + margin then
		return true
	end
	return false
end

----------------------------------------------------------------------
-- Ground
----------------------------------------------------------------------
local function palette()
	local t = terrain()
	t:SetMaterialColor(M.Grass, Color3.fromRGB(104, 168, 74))
	t:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(92, 158, 66))
	t:SetMaterialColor(M.Ground, Color3.fromRGB(150, 116, 82))
	t:SetMaterialColor(M.Sand, Color3.fromRGB(226, 205, 158))
	t:SetMaterialColor(M.Mud, Color3.fromRGB(96, 80, 60))
	t:SetMaterialColor(M.Rock, Color3.fromRGB(118, 114, 112))
	t:SetMaterialColor(M.Basalt, Color3.fromRGB(46, 40, 40))
	t:SetMaterialColor(M.CrackedLava, Color3.fromRGB(232, 96, 40))
	t:SetMaterialColor(M.Snow, Color3.fromRGB(238, 245, 255))
	t:SetMaterialColor(M.Glacier, Color3.fromRGB(160, 214, 245))
	t:SetMaterialColor(M.Ice, Color3.fromRGB(176, 220, 245))
	t:SetMaterialColor(M.Slate, Color3.fromRGB(80, 74, 74))
	t:SetMaterialColor(M.Cobblestone, Color3.fromRGB(176, 164, 146))
	t:SetMaterialColor(M.Pavement, Color3.fromRGB(196, 186, 168))
	t.WaterColor = Color3.fromRGB(40, 140, 170)
	t.WaterTransparency = 0.35
	t.WaterReflectance = 0.6
	t.WaterWaveSize = 0.12
	t.WaterWaveSpeed = 8
	pcall(function()
		(t :: any).Decoration = true -- animated grass blades, where allowed
	end)
end

function Landscape.Base()
	local t = terrain()
	t:Clear()
	palette()
	-- Flat world floor, top surface at y = 0.
	t:FillBlock(CFrame.new(0, -10, 0), Vector3.new(2048, 20, 2048), M.Grass)
end

-- Dirt path from a to b (ground level), `width` studs wide.
function Landscape.Path(a: Vector3, b: Vector3, width: number)
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, -2, mid.Z), Vector3.new(b.X, -2, b.Z))
	terrain():FillBlock(cf, Vector3.new(width, 4, (b - a).Magnitude), M.Ground)
	terrain():FillBlock(cf, Vector3.new(width * 0.55, 4.2, (b - a).Magnitude), M.Pavement)
end

-- Paint a zone's floor and scatter material patches for variety.
function Landscape.Zone(zoneId: string)
	local zone = Config.Zones[zoneId]
	local center = Config.ZoneCenter(zoneId)
	local base, patchA, patchB = M.LeafyGrass, M.Grass, M.Mud
	if zoneId == "Caldera" then
		base, patchA, patchB = M.Basalt, M.Slate, M.CrackedLava
	elseif zoneId == "Frost" then
		base, patchA, patchB = M.Snow, M.Glacier, M.Ice
	end
	local t = terrain()
	t:FillCylinder(CFrame.new(center + Vector3.new(0, -2, 0)), 4, zone.Radius + 26, base)
	for i = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * (zone.Radius + 10)
		local p = center + Vector3.new(math.cos(a) * r, -2, math.sin(a) * r)
		local mat = if i % 4 == 0 then patchB else patchA
		local size = if mat == patchB then rng:NextNumber(5, 10) else rng:NextNumber(10, 22)
		t:FillCylinder(CFrame.new(p), 4.1, size, mat)
	end
end

-- Textured cobblestone plaza with paved rings.
function Landscape.Plaza(radius: number)
	local t = terrain()
	t:FillCylinder(CFrame.new(0, -2, 0), 4, radius, M.Cobblestone)
	t:FillCylinder(CFrame.new(0, -2, 0), 4.05, 34, M.Pavement)
	t:FillCylinder(CFrame.new(0, -2, 0), 4.1, 24, M.Cobblestone)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		t:FillCylinder(CFrame.new(math.cos(a) * 70, -2, math.sin(a) * 70), 4.1, 7, M.LeafyGrass)
	end
end

function Landscape.Hazard(zoneId: string, position: Vector3, radius: number)
	local mat = if zoneId == "Caldera" then M.CrackedLava elseif zoneId == "Frost" then M.Ice else M.Mud
	terrain():FillCylinder(CFrame.new(position + Vector3.new(0, -2, 0)), 4.2, radius + 2, mat)
end

----------------------------------------------------------------------
-- Scenery around the play areas
----------------------------------------------------------------------
local function hills()
	local t = terrain()
	local placed = 0
	for _ = 1, 400 do
		if placed >= 110 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(Config.HubRadius + 60, 940)
		local p = Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local r = rng:NextNumber(28, 95)
		if not Landscape.IsPlayArea(p, r * 0.75) then
			placed += 1
			local region = regionOf(p)
			local mat = if region == "Frost" then M.Snow elseif region == "Caldera" then M.Rock else M.Grass
			t:FillBall(p - Vector3.new(0, r * 0.62, 0), r, mat)
			if region == "Caldera" and rng:NextNumber() < 0.4 then
				t:FillBall(p + Vector3.new(0, r * 0.2, 0), r * 0.45, M.Basalt)
			end
		end
	end
end

local function mountains()
	local t = terrain()
	for i = 1, 30 do
		local ang = i / 30 * 360 + rng:NextNumber(-4, 4)
		local p = polar(ang, rng:NextNumber(930, 990))
		local r = rng:NextNumber(150, 230)
		local region = regionOf(p)
		t:FillBall(p - Vector3.new(0, r * 0.45, 0), r, if region == "Caldera" then M.Basalt else M.Rock)
		local peak = r * 0.55
		-- snow caps (thicker toward Frost Hollow)
		local capR = if region == "Frost" then r * 0.55 elseif region == "Caldera" then 0 else r * 0.35
		if capR > 0 then
			t:FillBall(p + Vector3.new(0, peak - capR * 0.9, 0), capR, M.Snow)
		end
	end
end

local function volcano(folder: Instance)
	local t = terrain()
	local base = polar(VOLCANO_ANGLE, VOLCANO_DISTANCE)
	-- 4-stud layers match the terrain grid, so the slope smooths into a cone
	local h = 0
	for k = 0, 41 do
		local r = 190 - k * 4.2
		t:FillCylinder(CFrame.new(base + Vector3.new(0, h + 2, 0)), 4, r, if (k // 6) % 3 == 0 then M.Slate else M.Basalt)
		h += 4
	end
	-- crater with a glowing lava lake
	t:FillCylinder(CFrame.new(base + Vector3.new(0, h - 6, 0)), 24, 22, M.Air)
	t:FillCylinder(CFrame.new(base + Vector3.new(0, h - 16, 0)), 6, 24, M.CrackedLava)
	local glow = Build.cylinder(folder, CFrame.new(base + Vector3.new(0, h - 13, 0)), 0.5, 40, Color3.fromRGB(255, 110, 30), Enum.Material.Neon, { CanCollide = false })
	glow.Name = "VolcanoLava"
	Build.light(glow, Color3.fromRGB(255, 120, 40), 60, 4)
	local smoke = Instance.new("Smoke")
	smoke.Size = 40
	smoke.RiseVelocity = 20
	smoke.Opacity = 0.18
	smoke.Color = Color3.fromRGB(80, 70, 70)
	smoke.Parent = glow
	-- lava streams down the slopes
	for i = 1, 4 do
		local ang = i / 4 * math.pi * 2 + 0.4
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		for s = 0, 26 do
			local d = 24 + s * 6
			-- surface height of the cone at distance d
			local y = math.floor((190 - d) / 4.2 + 1) * 4
			t:FillBall(base + dir * d + Vector3.new(0, math.max(y - 2, 2), 0), 6, M.CrackedLava)
		end
	end
end

local function lake(folder: Instance)
	local t = terrain()
	local c = polar(LAKE_ANGLE, LAKE_DISTANCE)
	t:FillCylinder(CFrame.new(c + Vector3.new(0, -2, 0)), 4, LAKE_RADIUS + 16, M.Sand)
	t:FillCylinder(CFrame.new(c + Vector3.new(0, -9, 0)), 18, LAKE_RADIUS, M.Air)
	t:FillCylinder(CFrame.new(c + Vector3.new(0, -19, 0)), 4, LAKE_RADIUS, M.Sand)
	-- gentle sandy shelf around the edge
	for i = 1, 24 do
		local a = i / 24 * math.pi * 2
		t:FillBall(c + Vector3.new(math.cos(a) * LAKE_RADIUS, -9, math.sin(a) * LAKE_RADIUS), 10, M.Sand)
	end
	t:FillCylinder(CFrame.new(c + Vector3.new(0, -9.5, 0)), 17, LAKE_RADIUS - 2, M.Water)
	-- lily pads
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, LAKE_RADIUS - 12)
		local p = c + Vector3.new(math.cos(a) * r, -0.9, math.sin(a) * r)
		Build.cylinder(folder, CFrame.new(p), 0.15, rng:NextNumber(3, 5), Color3.fromRGB(80, 160, 70), Enum.Material.Grass, { CanCollide = false })
		if rng:NextNumber() < 0.4 then
			Build.ellipsoid(folder, CFrame.new(p + Vector3.new(0.6, 0.3, 0)), Vector3.new(1.1, 0.6, 1.1), Color3.fromRGB(255, 170, 210), nil, { CanCollide = false })
		end
	end
end

-- Forest clusters, bushes and rocks between the play areas.
local function forests(folder: Instance)
	local clusters = 0
	for _ = 1, 600 do
		if clusters >= 34 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(Config.HubRadius + 50, 860)
		local center = Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if not Landscape.IsPlayArea(center, 30) then
			clusters += 1
			local region = regionOf(center)
			local count = rng:NextInteger(4, 9)
			for _ = 1, count do
				local ta = rng:NextNumber(0, math.pi * 2)
				local tr = rng:NextNumber(0, 30)
				local p = center + Vector3.new(math.cos(ta) * tr, 0, math.sin(ta) * tr)
				if not Landscape.IsPlayArea(p, 6) then
					local ground = CFrame.new(p)
					local roll = rng:NextNumber()
					if region == "Frost" then
						Props.Tree(folder, ground, "SnowPine")
					elseif region == "Caldera" then
						if roll < 0.6 then
							Props.Tree(folder, ground, "Dead")
						else
							Props.Rocks(folder, ground, rng:NextNumber(5, 9), Color3.fromRGB(50, 42, 40))
						end
					else
						Props.Tree(folder, ground, if roll < 0.6 then "Round" else "Pine")
					end
				end
			end
			-- undergrowth
			for _ = 1, rng:NextInteger(2, 5) do
				local ta = rng:NextNumber(0, math.pi * 2)
				local p = center + Vector3.new(math.cos(ta), 0, math.sin(ta)) * rng:NextNumber(10, 38)
				if not Landscape.IsPlayArea(p, 4) then
					if region == "Meadow" then
						if rng:NextNumber() < 0.6 then
							Props.Bush(folder, CFrame.new(p), rng:NextNumber(4, 7))
						else
							Props.FlowerPatch(folder, CFrame.new(p), 4)
						end
					elseif region == "Frost" then
						Props.Rocks(folder, CFrame.new(p), rng:NextNumber(3, 6), Color3.fromRGB(200, 215, 230))
					else
						Props.Rocks(folder, CFrame.new(p), rng:NextNumber(3, 6), Color3.fromRGB(70, 60, 58))
					end
				end
			end
		end
	end
end

function Landscape.Scenery(folder: Instance)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = folder
	hills()
	mountains()
	volcano(scenery)
	lake(scenery)
	forests(scenery)
end

return Landscape
