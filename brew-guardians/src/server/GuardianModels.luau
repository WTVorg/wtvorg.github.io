-- Builds a guardian body. Uses ServerStorage.GuardianModels[id] when it
-- exists, otherwise a hand-built creature made of parts.
--
-- Builders work in "body units": 1 unit = the guardian's Size in studs.
-- The root sits at the body centre, the ground is at y = -0.5, front is -Z.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Art = require(script.Parent.Art)
local Build = require(script.Parent.Build)

local GuardianModels = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(20, 18, 26)
local BLUSH = Color3.fromRGB(255, 140, 170)

type Kit = {
	s: number,
	P: (x: number, y: number, z: number) -> CFrame,
	e: (cf: CFrame, x: number, y: number, z: number, color: Color3, material: Enum.Material?, name: string?) -> Part,
	cyl: (cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?) -> Part,
	spike: (cf: CFrame, height: number, width: number, color: Color3, material: Enum.Material?) -> (),
	eyes: (y: number, z: number, spread: number, size: number, iris: Color3?) -> (),
	legs: (positions: { Vector3 }, length: number, thickness: number, color: Color3, paw: Color3?) -> (),
}

local function newKit(model: Model, root: BasePart, s: number): Kit
	local kit = {} :: any
	kit.s = s
	function kit.P(x, y, z)
		return CFrame.new(x * s, y * s, z * s)
	end
	function kit.e(cf, x, y, z, color, material, name)
		local p = Build.ellipsoid(model, root.CFrame * cf, Vector3.new(x, y, z) * s, color, material)
		p.Name = name or "Body"
		return p
	end
	function kit.cyl(cf, height, diameter, color, material)
		local p = Build.cylinder(model, root.CFrame * cf, height * s, diameter * s, color, material)
		p.Name = "Body"
		return p
	end
	function kit.spike(cf, height, width, color, material)
		Build.spike(model, root.CFrame * cf, height * s, width * s, color, material)
	end
	-- Big cartoon eyes: white, dark pupil, sparkle.
	function kit.eyes(y, z, spread, size, iris)
		for _, side in { -1, 1 } do
			local base = kit.P(side * spread, y, z)
			kit.e(base, size, size * 1.15, size * 0.55, WHITE, nil, "Eye")
			kit.e(base * kit.P(0, -size * 0.08, -size * 0.2), size * 0.62, size * 0.78, size * 0.3, iris or BLACK, nil, "Pupil")
			kit.e(base * kit.P(side * size * 0.12, size * 0.18, -size * 0.32), size * 0.24, size * 0.24, size * 0.1, WHITE, Enum.Material.Neon, "Sparkle")
		end
	end
	-- Legs from a hip position straight down to the ground, with paws.
	function kit.legs(positions, length, thickness, color, paw)
		for _, hip in positions do
			kit.cyl(kit.P(hip.X, hip.Y - length / 2, hip.Z), length, thickness, color)
			kit.e(kit.P(hip.X, -0.5 + thickness * 0.3, hip.Z - thickness * 0.15), thickness * 1.25, thickness * 0.6, thickness * 1.5, paw or color)
		end
	end
	return kit :: Kit
end

----------------------------------------------------------------------
-- Species
----------------------------------------------------------------------
local Species = {}

function Species.Mossling(k: Kit, def)
	local green, sun = def.Color, def.Accent
	k.e(k.P(0, -0.06, 0), 1, 0.86, 0.95, green)
	k.e(k.P(0, -0.12, -0.12), 0.72, 0.6, 0.72, green:Lerp(WHITE, 0.25)) -- lighter belly
	k.eyes(0.06, -0.4, 0.18, 0.24)
	for _, side in { -1, 1 } do
		k.e(k.P(side * 0.32, -0.1, -0.36), 0.16, 0.1, 0.06, BLUSH, nil, "Accent")
		k.e(k.P(side * 0.3, -0.42, -0.18), 0.28, 0.16, 0.36, green:Lerp(BLACK, 0.2)) -- feet
		k.e(k.P(side * 0.3, -0.42, 0.22), 0.26, 0.15, 0.3, green:Lerp(BLACK, 0.2))
		k.e(k.P(side * 0.48, -0.12, -0.05) * CFrame.Angles(0, 0, side * math.rad(-30)), 0.14, 0.3, 0.14, green) -- arms
	end
	k.e(k.P(0, -0.08, -0.47), 0.12, 0.05, 0.04, BLACK, nil, "Mouth")
	-- sprout
	k.cyl(k.P(0, 0.5, 0), 0.22, 0.06, Color3.fromRGB(70, 130, 50))
	for _, side in { -1, 1 } do
		k.e(k.P(side * 0.14, 0.6, 0) * CFrame.Angles(0, 0, side * math.rad(-35)), 0.32, 0.08, 0.16, Color3.fromRGB(110, 200, 80), Enum.Material.Grass)
	end
	k.e(k.P(0, 0.64, 0), 0.14, 0.14, 0.14, sun, Enum.Material.Neon, "Accent")
	-- moss tufts on the back
	for i = 1, 5 do
		local a = i / 5 * math.pi * 1.2 - 0.6
		k.e(k.P(math.sin(a) * 0.3, 0.3, 0.2 + math.cos(a) * 0.12), 0.26, 0.18, 0.26, green:Lerp(Color3.fromRGB(40, 90, 40), 0.5), Enum.Material.Grass)
	end
end

function Species.Thornback(k: Kit, def)
	local hide, thorn = def.Color, def.Accent
	k.e(k.P(0, -0.05, 0.05), 0.85, 0.6, 1.2, hide)
	for i = -1, 1 do
		k.e(k.P(0, 0.02, 0.05 + i * 0.32), 0.9, 0.55, 0.3, hide:Lerp(BLACK, 0.25)) -- armour bands
	end
	for row = -1, 1 do
		for i = 0, 3 do
			local z = -0.3 + i * 0.25
			k.spike(k.P(row * 0.25, 0.18 - math.abs(row) * 0.08, z) * CFrame.Angles(0, 0, row * math.rad(-30)), 0.32, 0.1, thorn, nil)
		end
	end
	-- head and snout
	k.e(k.P(0, -0.02, -0.6), 0.5, 0.42, 0.45, hide:Lerp(WHITE, 0.08))
	k.e(k.P(0, -0.1, -0.84), 0.28, 0.22, 0.2, Color3.fromRGB(150, 110, 90), nil, "Snout")
	for _, side in { -1, 1 } do
		k.e(k.P(side * 0.06, -0.08, -0.94), 0.05, 0.06, 0.03, BLACK)
		k.spike(k.P(side * 0.15, -0.16, -0.82) * CFrame.Angles(math.rad(-60), 0, side * math.rad(-20)), 0.16, 0.05, Color3.fromRGB(245, 240, 225), nil)
		k.e(k.P(side * 0.2, 0.18, -0.55) * CFrame.Angles(0, 0, side * math.rad(-30)), 0.08, 0.16, 0.06, hide:Lerp(BLACK, 0.2))
	end
	k.eyes(0.06, -0.78, 0.12, 0.12, Color3.fromRGB(60, 30, 20))
	k.legs({ Vector3.new(-0.28, -0.2, -0.35), Vector3.new(0.28, -0.2, -0.35), Vector3.new(-0.28, -0.2, 0.4), Vector3.new(0.28, -0.2, 0.4) }, 0.3, 0.16, hide:Lerp(BLACK, 0.3))
	k.e(k.P(0, 0, 0.66), 0.1, 0.1, 0.18, hide)
end

function Species.Cinderpup(k: Kit, def)
	local fur, flame = def.Color, def.Accent
	k.e(k.P(0, -0.12, 0.08), 0.55, 0.5, 0.85, fur)
	k.e(k.P(0, -0.15, -0.18), 0.42, 0.38, 0.35, fur:Lerp(WHITE, 0.5)) -- chest
	k.e(k.P(0, 0.2, -0.38), 0.62, 0.56, 0.55, fur)
	k.e(k.P(0, 0.08, -0.66), 0.32, 0.24, 0.28, fur:Lerp(WHITE, 0.55), nil, "Snout")
	k.e(k.P(0, 0.14, -0.8), 0.1, 0.08, 0.06, BLACK)
	k.eyes(0.28, -0.6, 0.15, 0.17)
	for _, side in { -1, 1 } do
		k.e(k.P(side * 0.3, 0.22, -0.3) * CFrame.Angles(0, 0, side * math.rad(25)), 0.14, 0.38, 0.22, fur:Lerp(BLACK, 0.25)) -- floppy ears
	end
	-- flame tuft and tail
	k.e(k.P(0, 0.52, -0.36), 0.22, 0.26, 0.22, flame, Enum.Material.Neon, "Accent")
	k.e(k.P(0, 0.62, -0.32), 0.12, 0.18, 0.12, Color3.fromRGB(255, 250, 200), Enum.Material.Neon, "Accent")
	local tail = { { 0.05, 0.5, 0.2 }, { 0.2, 0.62, 0.16 }, { 0.36, 0.7, 0.12 } }
	for i, t in tail do
		k.e(k.P(0, -0.05 + t[1], 0.5 + i * 0.08), t[3] * 2, t[3] * 2.4, t[3] * 2, if i == 3 then Color3.fromRGB(255, 250, 200) else flame, Enum.Material.Neon, "Accent")
	end
	k.legs({ Vector3.new(-0.16, -0.25, -0.14), Vector3.new(0.16, -0.25, -0.14), Vector3.new(-0.16, -0.25, 0.3), Vector3.new(0.16, -0.25, 0.3) }, 0.25, 0.13, fur, fur:Lerp(WHITE, 0.5))
end

function Species.Magmaw(k: Kit, def)
	local rock, lava = def.Color, def.Accent
	k.e(k.P(0, -0.08, 0.1), 1, 0.66, 1.15, rock)
	-- lava cracks along the back
	for i = 0, 4 do
		k.e(k.P(math.sin(i) * 0.15, 0.24, -0.25 + i * 0.16) * CFrame.Angles(0, i * 0.7, 0), 0.4, 0.04, 0.06, lava, Enum.Material.Neon, "Accent")
	end
	for _, side in { -1, 1 } do
		k.e(k.P(side * 0.35, 0.05, 0.1), 0.06, 0.04, 0.5, lava, Enum.Material.Neon, "Accent")
	end
	-- head with a huge jaw
	k.e(k.P(0, 0.02, -0.5), 0.78, 0.36, 0.5, rock:Lerp(WHITE, 0.05))
	k.e(k.P(0, -0.17, -0.5), 0.74, 0.12, 0.46, lava, Enum.Material.Neon, "Accent") -- glowing mouth
	k.e(k.P(0, -0.27, -0.48), 0.76, 0.16, 0.48, rock:Lerp(BLACK, 0.2))
	for _, side in { -1, 1 } do
		k.spike(k.P(side * 0.26, 0.15, -0.5) * CFrame.Angles(math.rad(25), 0, side * math.rad(-25)), 0.3, 0.1, rock:Lerp(BLACK, 0.4), Enum.Material.Basalt)
		for i = 0, 2 do
			k.spike(k.P(side * (0.12 + i * 0.1), -0.2, -0.72 + i * 0.03) * CFrame.Angles(math.rad(180), 0, 0), 0.07, 0.04, WHITE, nil)
		end
	end
	k.eyes(0.16, -0.68, 0.2, 0.1, lava)
	k.legs({ Vector3.new(-0.4, -0.22, -0.25), Vector3.new(0.4, -0.22, -0.25), Vector3.new(-0.4, -0.22, 0.42), Vector3.new(0.4, -0.22, 0.42) }, 0.28, 0.22, rock:Lerp(BLACK, 0.2))
	k.e(k.P(0, -0.15, 0.72), 0.3, 0.22, 0.45, rock)
	k.e(k.P(0, -0.25, 1.0), 0.16, 0.12, 0.34, rock)
	k.e(k.P(0, -0.3, 1.18), 0.08, 0.08, 0.14, lava, Enum.Material.Neon, "Accent")
end

function Species.Glimmerfox(k: Kit, def)
	local fur, gem = def.Color, def.Accent
	k.e(k.P(0, -0.02, 0.05), 0.42, 0.42, 0.85, fur)
	k.e(k.P(0, 0.05, -0.3), 0.36, 0.42, 0.3, WHITE) -- chest ruff
	k.e(k.P(0, 0.3, -0.45), 0.42, 0.4, 0.4, fur)
	k.e(k.P(0, 0.22, -0.7), 0.2, 0.16, 0.32, WHITE, nil, "Snout")
	k.e(k.P(0, 0.25, -0.86), 0.07, 0.06, 0.05, BLACK)
	k.eyes(0.36, -0.6, 0.12, 0.13, Color3.fromRGB(90, 50, 160))
	for _, side in { -1, 1 } do
		k.spike(k.P(side * 0.14, 0.44, -0.42) * CFrame.Angles(0, 0, side * math.rad(-12)), 0.32, 0.14, fur)
		k.spike(k.P(side * 0.15, 0.62, -0.42) * CFrame.Angles(0, 0, side * math.rad(-12)), 0.14, 0.07, gem, Enum.Material.Neon)
	end
	-- crystal mane
	for i = 0, 3 do
		k.spike(k.P(0, 0.18, -0.15 + i * 0.13) * CFrame.Angles(math.rad(15), 0, 0), 0.18 - i * 0.03, 0.08, gem, Enum.Material.Glass)
	end
	-- huge fluffy tail curling up
	k.e(k.P(0, 0.05, 0.55) * CFrame.Angles(math.rad(-30), 0, 0), 0.34, 0.34, 0.55, fur)
	k.e(k.P(0, 0.3, 0.78) * CFrame.Angles(math.rad(-60), 0, 0), 0.32, 0.32, 0.45, fur)
	k.e(k.P(0, 0.52, 0.82), 0.24, 0.24, 0.24, WHITE)
	k.e(k.P(0, 0.64, 0.82), 0.14, 0.2, 0.14, gem, Enum.Material.Neon, "Accent")
	k.legs({ Vector3.new(-0.12, -0.15, -0.22), Vector3.new(0.12, -0.15, -0.22), Vector3.new(-0.12, -0.15, 0.3), Vector3.new(0.12, -0.15, 0.3) }, 0.35, 0.09, fur, WHITE)
end

function Species.Aurorath(k: Kit, def)
	local body, glow = def.Color, def.Accent
	local deep = body:Lerp(Color3.fromRGB(20, 40, 70), 0.55)
	k.e(k.P(0, 0.05, 0.05), 0.44, 0.4, 0.8, deep)
	k.e(k.P(0, 0.08, -0.17), 0.38, 0.34, 0.34, body:Lerp(WHITE, 0.4))
	k.e(k.P(0, 0.28, -0.32) * CFrame.Angles(math.rad(-40), 0, 0), 0.16, 0.36, 0.16, deep) -- neck
	k.e(k.P(0, 0.44, -0.44), 0.2, 0.18, 0.28, deep)
	k.e(k.P(0, 0.4, -0.58), 0.12, 0.1, 0.16, body:Lerp(WHITE, 0.3), nil, "Snout")
	k.eyes(0.47, -0.52, 0.07, 0.07, glow)
	-- crystal antlers
	for _, side in { -1, 1 } do
		local base = k.P(side * 0.06, 0.54, -0.42)
		k.cyl(base * CFrame.Angles(0, 0, side * math.rad(-25)) * k.P(0, 0.12, 0), 0.24, 0.025, glow, Enum.Material.Neon)
		k.cyl(base * k.P(side * 0.1, 0.22, 0) * CFrame.Angles(0, 0, side * math.rad(-60)) * k.P(0, 0.06, 0), 0.12, 0.02, glow, Enum.Material.Neon)
		k.cyl(base * k.P(side * 0.06, 0.16, 0.04) * CFrame.Angles(math.rad(40), 0, side * math.rad(10)) * k.P(0, 0.06, 0), 0.12, 0.02, body, Enum.Material.Neon)
		k.e(base * k.P(side * 0.12, 0.26, 0), 0.04, 0.04, 0.04, WHITE, Enum.Material.Neon, "Accent")
	end
	-- flowing aurora mane and tail
	for i = 0, 4 do
		local t = i / 4
		k.e(k.P(0, 0.42 - t * 0.2, -0.36 + t * 0.4), 0.05, 0.16, 0.12, if i % 2 == 0 then glow else body, Enum.Material.Neon, "Accent")
	end
	for i = 0, 3 do
		k.e(k.P(0, 0.1 - i * 0.06, 0.45 + i * 0.12) * CFrame.Angles(math.rad(-20 - i * 10), 0, 0), 0.06, 0.08, 0.16, if i % 2 == 0 then body else glow, Enum.Material.Neon, "Accent")
	end
	k.legs({ Vector3.new(-0.12, -0.08, -0.15), Vector3.new(0.12, -0.08, -0.15), Vector3.new(-0.12, -0.08, 0.28), Vector3.new(0.12, -0.08, 0.28) }, 0.42, 0.08, deep, glow)
	for _, z in { -0.15, 0.28 } do
		for _, side in { -1, 1 } do
			k.e(k.P(side * 0.12, -0.1, z), 0.12, 0.18, 0.14, deep) -- thighs blend legs into the body
		end
	end
	-- spirit orbs drifting around it
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		k.e(k.P(math.cos(a) * 0.45, 0.3 + i * 0.06, math.sin(a) * 0.45), 0.06, 0.06, 0.06, if i == 2 then glow else body, Enum.Material.Neon, "Accent")
	end
end

----------------------------------------------------------------------
local function buildBuiltIn(id: string): Model
	local def = Config.Guardians[id]
	local s = def.Size
	local model = Instance.new("Model")

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(s * 0.8, s * 0.8, s * 0.8)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.CFrame = CFrame.new(0, s / 2, 0)
	root.Parent = model
	model.PrimaryPart = root

	local kit = newKit(model, root, s)
	local builder = Species[id]
	if builder then
		builder(kit, def)
	else
		-- Generic fallback for guardians added in Config without a builder.
		kit.e(kit.P(0, -0.05, 0), 0.9, 0.8, 0.9, def.Color)
		kit.eyes(0.1, -0.4, 0.17, 0.2)
		kit.e(kit.P(0, 0.45, 0), 0.25, 0.25, 0.25, def.Accent, Enum.Material.Neon, "Accent")
	end

	return model
end

-- Glow, sparkles and welds shared by the mesh and part-built bodies.
local function finishBody(model: Model, root: BasePart, def)
	local s = def.Size
	local light = Instance.new("PointLight")
	light.Color = def.Accent
	light.Range = s * 2
	light.Brightness = if def.Rarity == "Legendary" then 2.5 else 0.8
	light.Parent = root

	if def.Rarity == "Legendary" or def.Rarity == "Rare" then
		local aura = Build.sparkles(root, def.Accent, if def.Rarity == "Legendary" then 18 else 6, s * 0.08)
		aura.Name = "Aura"
	end

	-- One rigid body: everything welded to the anchored root, so moving the
	-- root moves the creature and only one part needs replicating.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
end

-- The imported Blender mesh, when the art pack is in the place.
local function buildFromArt(id: string): Model?
	local def = Config.Guardians[id]
	local s = def.Size
	if not Art.Has(id) then
		return nil
	end
	local model = Art.SpawnScaled(id, CFrame.new(), s) :: Model -- 1 Blender unit = Size studs
	Art.SetGlow(model, def.Accent)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(s * 0.8, s * 0.8, s * 0.8)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.CFrame = CFrame.new(0, s / 2, 0)
	root.Parent = model
	model.PrimaryPart = root
	return model
end

-- Returns a model whose PrimaryPart sits at the body centre.
function GuardianModels.Build(id: string, mutation: number?): Model
	local custom = ServerStorage:FindFirstChild("GuardianModels")
	local template = custom and custom:FindFirstChild(id)
	local model: Model
	if template and template:IsA("Model") and template.PrimaryPart then
		model = template:Clone()
		-- Everything anchored: the server moves the whole model with PivotTo.
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
	else
		model = buildFromArt(id) or buildBuiltIn(id)
		finishBody(model, model.PrimaryPart :: BasePart, Config.Guardians[id])
	end
	model.Name = id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local m = Config.Mutations[mutation or 0]
	if m then
		model:ScaleTo(model:GetScale() * m.Scale)
		-- Mutated forms get a shifted, glowing accent colour.
		local tint = ({ Color3.fromRGB(255, 120, 220), Color3.fromRGB(150, 90, 255), Color3.fromRGB(255, 60, 90) })[mutation :: number]
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Accent" or d.Name == "Glow") then
				d.Color = tint
				d.Material = Enum.Material.Neon
			end
		end
		if model.PrimaryPart then
			local aura = Build.sparkles(model.PrimaryPart, tint, 4 + (mutation :: number) * 4, 0.6)
			aura.Name = "MutationAura"
		end
	end
	return model
end

-- Moves the model up or down so its lowest point sits at groundY.
function GuardianModels.SitOnGround(model: Model, groundY: number)
	Build.sitOnGround(model, groundY)
end

return GuardianModels
