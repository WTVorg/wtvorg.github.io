-- Reusable scenery: cauldrons, fences, lanterns, trees, rocks, crystals,
-- gates, stalls, pedestals and ingredient plants. Every builder takes a
-- ground CFrame (y = floor level, facing -Z) and returns a Model.

local Build = require(script.Parent.Build)

local Props = {}

local IRON = Color3.fromRGB(46, 44, 54)
local IRON_LIGHT = Color3.fromRGB(78, 74, 88)
local WOOD = Color3.fromRGB(124, 86, 56)
local WOOD_DARK = Color3.fromRGB(92, 62, 40)
local STONE = Color3.fromRGB(150, 146, 140)
local STONE_DARK = Color3.fromRGB(110, 106, 102)

local rng = Random.new(77)
local function jitter(a: number, b: number): number
	return rng:NextNumber(a, b)
end

----------------------------------------------------------------------
-- Cauldron: round iron belly, rim, glowing brew, legs and a fire below.
-- Returns model, brewPart (for colour changes / effects), promptPart.
----------------------------------------------------------------------
function Props.Cauldron(parent: Instance, ground: CFrame, r: number, brewColor: Color3): (Model, BasePart, BasePart)
	local m = Build.model("Cauldron", parent)
	local lift = r * 0.55 -- room for the fire underneath
	local c = ground * CFrame.new(0, lift + r * 0.7, 0)

	-- legs
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2
		local legCf = ground * CFrame.Angles(0, a, 0) * CFrame.new(r * 0.62, lift * 0.55, 0) * CFrame.Angles(0, 0, math.rad(-12))
		Build.cylinder(m, legCf, lift * 1.2, r * 0.18, IRON, Enum.Material.Metal)
		Build.ellipsoid(m, ground * CFrame.Angles(0, a, 0) * CFrame.new(r * 0.72, r * 0.06, 0), Vector3.new(r * 0.3, r * 0.12, r * 0.3), IRON, Enum.Material.Metal)
	end

	-- fire: crossed logs, embers, flame
	for i = 0, 2 do
		local log = Build.cylinder(m, ground * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, r * 0.1, 0) * CFrame.Angles(math.rad(90), 0, 0), r * 1.0, r * 0.18, WOOD_DARK, Enum.Material.Wood)
		log.CanCollide = false
	end
	local ember = Build.ellipsoid(m, ground * CFrame.new(0, r * 0.18, 0), Vector3.new(r * 0.55, r * 0.25, r * 0.55), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, { CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = r * 1.6
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = ember
	Build.light(ember, Color3.fromRGB(255, 150, 60), r * 4, 1.5)

	-- belly
	local belly = Build.ellipsoid(m, c, Vector3.new(r * 2, r * 1.5, r * 2), IRON, Enum.Material.Metal)
	-- neck, brew surface and thick rolled rim
	Build.cylinder(m, c * CFrame.new(0, r * 0.6, 0), r * 0.2, r * 1.66, IRON, Enum.Material.Metal)
	local brew = Build.cylinder(m, c * CFrame.new(0, r * 0.7, 0), 0.1, r * 1.5, brewColor, Enum.Material.Neon, { CanCollide = false })
	brew.Name = "Brew"
	Build.ring(m, c * CFrame.new(0, r * 0.72, 0), r * 0.84, r * 0.22, 20, IRON_LIGHT, Enum.Material.Metal)
	-- bubbles sitting on the surface
	for i = 1, 4 do
		local a = jitter(0, math.pi * 2)
		local d = jitter(0.1, 0.5) * r
		local s = jitter(0.12, 0.26) * r
		Build.ellipsoid(m, c * CFrame.new(math.cos(a) * d, r * 0.74, math.sin(a) * d), Vector3.new(s, s * 0.7, s), brewColor:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Neon, { CanCollide = false })
	end
	-- handles
	for _, side in { -1, 1 } do
		Build.ring(m, c * CFrame.new(side * r * 1.0, r * 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), r * 0.22, r * 0.07, 10, IRON_LIGHT, Enum.Material.Metal)
	end

	Build.light(brew, brewColor, r * 5, 1.2)
	local bubbles = Build.sparkles(brew, brewColor:Lerp(Color3.new(1, 1, 1), 0.4), 8, r * 0.18)
	bubbles.Name = "Bubbles"
	bubbles.EmissionDirection = Enum.NormalId.Right -- cylinder's top face
	bubbles.Speed = NumberRange.new(r * 0.6, r * 1.2)
	bubbles.SpreadAngle = Vector2.new(25, 25)

	m.PrimaryPart = belly
	return m, brew, belly
end

----------------------------------------------------------------------
-- Fences, lanterns, benches, signs
----------------------------------------------------------------------
function Props.FenceRun(parent: Instance, a: Vector3, b: Vector3, y: number, postEvery: number?)
	local m = Build.model("Fence", parent)
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local count = math.max(1, math.floor(length / (postEvery or 6)))
	for i = 0, count do
		local p = a:Lerp(b, i / count)
		Build.cylinder(m, CFrame.new(p.X, y + 2, p.Z), 4, 0.8, WOOD_DARK, Enum.Material.Wood)
		Build.ellipsoid(m, CFrame.new(p.X, y + 4.1, p.Z), Vector3.new(0.95, 0.6, 0.95), WOOD, Enum.Material.Wood)
	end
	local mid = (a + b) / 2
	for _, h in { 1.5, 3 } do
		Build.part(m, CFrame.lookAt(Vector3.new(mid.X, y + h, mid.Z), Vector3.new(mid.X, y + h, mid.Z) + dir), Vector3.new(0.3, 0.5, length), WOOD, Enum.Material.WoodPlanks)
	end
	return m
end

function Props.Lantern(parent: Instance, ground: CFrame, height: number?, color: Color3?)
	local h = height or 9
	local m = Build.model("Lantern", parent)
	Build.cylinder(m, ground * CFrame.new(0, 0.3, 0), 0.6, 1.8, STONE_DARK, Enum.Material.Slate)
	Build.cylinder(m, ground * CFrame.new(0, h / 2, 0), h, 0.45, IRON, Enum.Material.Metal)
	Build.part(m, ground * CFrame.new(0.9, h - 0.2, 0), Vector3.new(1.8, 0.25, 0.25), IRON, Enum.Material.Metal)
	local glow = Build.part(m, ground * CFrame.new(1.6, h - 1.2, 0), Vector3.new(0.9, 1.2, 0.9), color or Color3.fromRGB(255, 210, 120), Enum.Material.Neon, { CanCollide = false })
	Build.part(m, ground * CFrame.new(1.6, h - 0.5, 0), Vector3.new(1.2, 0.25, 1.2), IRON, Enum.Material.Metal)
	Build.part(m, ground * CFrame.new(1.6, h - 1.9, 0), Vector3.new(1.1, 0.2, 1.1), IRON, Enum.Material.Metal)
	Build.light(glow, color or Color3.fromRGB(255, 200, 120), 18, 1.4)
	return m
end

function Props.Bench(parent: Instance, ground: CFrame)
	local m = Build.model("Bench", parent)
	Build.part(m, ground * CFrame.new(0, 1.6, 0), Vector3.new(6, 0.35, 1.8), WOOD, Enum.Material.WoodPlanks)
	Build.part(m, ground * CFrame.new(0, 2.8, 0.8) * CFrame.Angles(math.rad(-10), 0, 0), Vector3.new(6, 1.2, 0.3), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -2.5, 2.5 } do
		Build.part(m, ground * CFrame.new(x, 0.8, 0), Vector3.new(0.4, 1.6, 1.6), IRON, Enum.Material.Metal)
	end
	return m
end

-- Two posts and a board with text on both sides. Returns the model and a
-- function that changes the text.
function Props.SignBoard(parent: Instance, ground: CFrame, text: string, width: number?, boardColor: Color3?): (Model, (string) -> ())
	local w = width or 10
	local m = Build.model("SignBoard", parent)
	for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
		Build.cylinder(m, ground * CFrame.new(x, 3, 0), 6, 0.6, WOOD_DARK, Enum.Material.Wood)
	end
	local board = Build.part(m, ground * CFrame.new(0, 5, 0), Vector3.new(w, 2.6, 0.4), boardColor or WOOD, Enum.Material.WoodPlanks)
	Build.part(m, ground * CFrame.new(0, 6.45, 0), Vector3.new(w + 0.6, 0.3, 0.7), WOOD_DARK, Enum.Material.Wood)
	local front = Build.surfaceText(board, Enum.NormalId.Front, text, Color3.fromRGB(255, 245, 225))
	local back = Build.surfaceText(board, Enum.NormalId.Back, text, Color3.fromRGB(255, 245, 225))
	return m, function(newText: string)
		front.Text = newText
		back.Text = newText
	end
end

----------------------------------------------------------------------
-- Nature
----------------------------------------------------------------------
function Props.Tree(parent: Instance, ground: CFrame, style: string)
	local m = Build.model("Tree", parent)
	local h = jitter(10, 16)
	if style == "Pine" or style == "SnowPine" then
		Build.cylinder(m, ground * CFrame.new(0, h * 0.35, 0), h * 0.7, 1.4, WOOD_DARK, Enum.Material.Wood)
		local green = if style == "SnowPine" then Color3.fromRGB(70, 110, 95) else Color3.fromRGB(52, 120, 70)
		for i = 0, 3 do
			local w = (4 - i) * 2.6
			local y = h * 0.3 + i * h * 0.17
			Build.ellipsoid(m, ground * CFrame.new(0, y, 0), Vector3.new(w, h * 0.22, w), green, Enum.Material.Grass)
			if style == "SnowPine" then
				Build.ellipsoid(m, ground * CFrame.new(0, y + h * 0.06, 0), Vector3.new(w * 0.8, h * 0.12, w * 0.8), Color3.fromRGB(240, 248, 255), Enum.Material.Snow)
			end
		end
	elseif style == "Dead" then
		Build.cylinder(m, ground * CFrame.new(0, h * 0.35, 0) * CFrame.Angles(0, 0, math.rad(jitter(-6, 6))), h * 0.7, 1.3, Color3.fromRGB(40, 32, 30), Enum.Material.Wood)
		for i = 1, 3 do
			local a = jitter(0, math.pi * 2)
			Build.cylinder(m, ground * CFrame.new(0, h * jitter(0.4, 0.65), 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.rad(-50)) * CFrame.new(0, 2, 0), 4, 0.6, Color3.fromRGB(40, 32, 30), Enum.Material.Wood)
			local _ = i
		end
	else -- round leafy tree
		Build.cylinder(m, ground * CFrame.new(0, h * 0.35, 0), h * 0.7, 1.8, WOOD, Enum.Material.Wood)
		local greens = { Color3.fromRGB(80, 160, 80), Color3.fromRGB(100, 180, 85), Color3.fromRGB(65, 140, 70) }
		Build.ellipsoid(m, ground * CFrame.new(0, h * 0.8, 0), Vector3.new(10, 8, 10), greens[1], Enum.Material.Grass)
		for i = 1, 3 do
			local a = (i / 3) * math.pi * 2 + jitter(0, 1)
			Build.ellipsoid(m, ground * CFrame.new(math.cos(a) * 3.5, h * 0.72 + jitter(-1, 1.5), math.sin(a) * 3.5), Vector3.new(7, 6, 7), greens[i], Enum.Material.Grass)
		end
	end
	return m
end

function Props.Rocks(parent: Instance, ground: CFrame, size: number, color: Color3?, material: Enum.Material?)
	local m = Build.model("Rocks", parent)
	local col = color or STONE
	for i = 1, 3 do
		local s = size * (1 - i * 0.22)
		local off = if i == 1 then Vector3.zero else Vector3.new(jitter(-1, 1), 0, jitter(-1, 1)).Unit * size * 0.55
		Build.part(m, ground * CFrame.new(off + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(jitter(-0.4, 0.4), jitter(0, 6), jitter(-0.4, 0.4)), Vector3.new(s, s * 0.75, s * 0.9), col:Lerp(Color3.new(0, 0, 0), i * 0.06), material or Enum.Material.Slate)
	end
	return m
end

function Props.Crystals(parent: Instance, ground: CFrame, size: number, color: Color3, glow: boolean?)
	local m = Build.model("Crystals", parent)
	for i = 1, 5 do
		local h = size * jitter(0.6, 1.3) * (if i == 1 then 1.4 else 1)
		local w = size * 0.22
		local tilt = if i == 1 then CFrame.identity else CFrame.Angles(jitter(-0.5, 0.5), jitter(0, 6), jitter(-0.5, 0.5))
		local base = ground * CFrame.new(jitter(-1, 1) * size * 0.3, 0, jitter(-1, 1) * size * 0.3) * tilt
		local mat = if glow and i == 1 then Enum.Material.Neon else Enum.Material.Glass
		Build.part(m, base * CFrame.new(0, h / 2, 0), Vector3.new(w, h, w), color, mat, { Transparency = if mat == Enum.Material.Glass then 0.15 else 0 })
		Build.tent(m, base * CFrame.new(0, h, 0), w * 1.2, w, color, mat)
	end
	return m
end

function Props.FlowerPatch(parent: Instance, ground: CFrame, radius: number)
	local m = Build.model("Flowers", parent)
	local colors = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(170, 130, 255), Color3.fromRGB(255, 255, 255) }
	for i = 1, 7 do
		local a = jitter(0, math.pi * 2)
		local d = jitter(0, radius)
		local p = ground * CFrame.new(math.cos(a) * d, 0, math.sin(a) * d)
		Build.cylinder(m, p * CFrame.new(0, 0.5, 0), 1, 0.15, Color3.fromRGB(70, 140, 60), nil, { CanCollide = false })
		Build.ellipsoid(m, p * CFrame.new(0, 1.05, 0), Vector3.new(0.7, 0.35, 0.7), colors[(i % #colors) + 1], nil, { CanCollide = false })
	end
	return m
end

function Props.GrassTuft(parent: Instance, ground: CFrame, color: Color3)
	local m = Build.model("Tuft", parent)
	for i = 1, 3 do
		Build.wedge(m, ground * CFrame.Angles(0, i * 2.1, jitter(-0.2, 0.2)) * CFrame.new(0, 0.6, 0), Vector3.new(0.2, 1.2, 0.5), color, Enum.Material.Grass, { CanCollide = false, CastShadow = false })
	end
	return m
end

----------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------
function Props.Gate(parent: Instance, ground: CFrame, width: number, text: string, accent: Color3)
	local m = Build.model("Gate", parent)
	local h = 16
	for _, x in { -width / 2, width / 2 } do
		Build.part(m, ground * CFrame.new(x, 0.6, 0), Vector3.new(4, 1.2, 4), STONE_DARK, Enum.Material.Cobblestone)
		Build.part(m, ground * CFrame.new(x, h / 2, 0), Vector3.new(3, h, 3), STONE, Enum.Material.Cobblestone)
		Build.part(m, ground * CFrame.new(x, h + 0.4, 0), Vector3.new(3.8, 0.8, 3.8), STONE_DARK, Enum.Material.Cobblestone)
		local orb = Build.ellipsoid(m, ground * CFrame.new(x, h + 1.6, 0), Vector3.new(1.8, 1.8, 1.8), accent, Enum.Material.Neon)
		Build.light(orb, accent, 16, 1.5)
	end
	Build.part(m, ground * CFrame.new(0, h - 1, 0), Vector3.new(width + 3, 1.6, 2.2), WOOD_DARK, Enum.Material.Wood)
	local banner = Build.part(m, ground * CFrame.new(0, h - 3.6, 0), Vector3.new(width * 0.7, 3.2, 0.3), accent:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Fabric)
	Build.surfaceText(banner, Enum.NormalId.Front, text, Color3.new(1, 1, 1))
	Build.surfaceText(banner, Enum.NormalId.Back, text, Color3.new(1, 1, 1))
	return m
end

-- Market stall with a striped awning and a shelf of flasks.
function Props.Stall(parent: Instance, ground: CFrame, stripeA: Color3, stripeB: Color3): (Model, BasePart)
	local m = Build.model("Stall", parent)
	local counter = Build.part(m, ground * CFrame.new(0, 2, 0), Vector3.new(14, 4, 4), WOOD, Enum.Material.WoodPlanks)
	Build.part(m, ground * CFrame.new(0, 4.15, 0), Vector3.new(14.6, 0.3, 4.6), WOOD_DARK, Enum.Material.Wood)
	for _, x in { -6.6, 6.6 } do
		for _, z in { -2, 3.5 } do
			Build.cylinder(m, ground * CFrame.new(x, 5, z), 10, 0.6, WOOD_DARK, Enum.Material.Wood)
		end
	end
	-- awning stripes
	for i = 0, 6 do
		Build.wedge(m, ground * CFrame.new(-6.8 + i * 2.27 + 1.13, 10.6, 0.5) * CFrame.Angles(0, math.pi, 0), Vector3.new(2.27, 1.6, 7), if i % 2 == 0 then stripeA else stripeB, Enum.Material.Fabric)
	end
	-- shelf of flasks behind the counter
	Build.part(m, ground * CFrame.new(0, 6.5, 3.5), Vector3.new(12, 0.3, 1.4), WOOD, Enum.Material.WoodPlanks)
	local colors = { Color3.fromRGB(196, 132, 92), Color3.fromRGB(140, 220, 255), Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 240, 150) }
	for i = 1, 8 do
		local col = colors[(i % 4) + 1]
		Build.ellipsoid(m, ground * CFrame.new(-5.2 + i * 1.3, 7.2, 3.5), Vector3.new(1, 1.1, 1), col, Enum.Material.Glass, { Transparency = 0.1 })
		Build.cylinder(m, ground * CFrame.new(-5.2 + i * 1.3, 7.9, 3.5), 0.4, 0.35, col, Enum.Material.Glass)
	end
	-- vials on the counter
	for i = 1, 5 do
		Build.cylinder(m, ground * CFrame.new(-4 + i * 1.4, 4.9, -0.6), 1.2, 0.5, Color3.fromRGB(200, 235, 255), Enum.Material.Glass, { Transparency = 0.3 })
	end
	return m, counter
end

function Props.Pedestal(parent: Instance, ground: CFrame, accent: Color3): (Model, number)
	local m = Build.model("Pedestal", parent)
	Build.cylinder(m, ground * CFrame.new(0, 0.4, 0), 0.8, 7.2, STONE_DARK, Enum.Material.Slate)
	Build.cylinder(m, ground * CFrame.new(0, 1.2, 0), 0.8, 6.4, STONE, Enum.Material.Slate)
	Build.ring(m, ground * CFrame.new(0, 1.62, 0), 3.1, 0.25, 16, accent, Enum.Material.Neon)
	return m, 1.6 -- height of the top surface
end

-- Treasure chest overflowing with coins. Returns model, the lid part.
function Props.CoinChest(parent: Instance, ground: CFrame): (Model, BasePart)
	local m = Build.model("CoinChest", parent)
	local gold = Color3.fromRGB(255, 200, 60)
	Build.cylinder(m, ground * CFrame.new(0, 0.2, 0), 0.4, 9, Color3.fromRGB(200, 150, 40), Enum.Material.Neon, { CanCollide = false })
	local box = Build.part(m, ground * CFrame.new(0, 1.6, 0), Vector3.new(5, 2.8, 3.4), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -2.2, 2.2 } do
		Build.part(m, ground * CFrame.new(x, 1.6, 0), Vector3.new(0.4, 2.9, 3.5), gold, Enum.Material.Metal)
	end
	local lid = Build.cylinder(m, ground * CFrame.new(0, 3.0, 0.9) * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.Angles(0, 0, math.rad(90)), 5, 3.4, WOOD, Enum.Material.WoodPlanks)
	for i = 1, 9 do
		Build.cylinder(m, ground * CFrame.new(jitter(-1.8, 1.8), 3.0 + jitter(0, 0.6), jitter(-1.1, 0.8)) * CFrame.Angles(jitter(-0.5, 0.5), 0, jitter(-0.5, 0.5)), 0.2, 0.9, gold, Enum.Material.Metal)
		local _ = i
	end
	Build.ellipsoid(m, ground * CFrame.new(0, 3.0, -0.2), Vector3.new(3.8, 1.2, 2.4), gold, Enum.Material.Metal)
	Build.light(box, gold, 10, 1)
	return m, lid
end

----------------------------------------------------------------------
-- Ingredient plants (one look per ingredient style)
----------------------------------------------------------------------
function Props.Plant(parent: Instance, ground: CFrame, style: string, color: Color3, tier: number): (Model, BasePart)
	local m = Build.model("Plant", parent)
	local stemColor = Color3.fromRGB(70, 140, 60)
	local focus: BasePart
	local noCollide = { CanCollide = false }

	if style == "Flower" then
		Build.cylinder(m, ground * CFrame.new(0, 1.2, 0), 2.4, 0.25, stemColor, nil, noCollide)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			Build.ellipsoid(m, ground * CFrame.new(math.cos(a) * 0.75, 2.5, math.sin(a) * 0.75) * CFrame.Angles(0, -a, 0), Vector3.new(1.2, 0.25, 0.7), color, nil, noCollide)
		end
		focus = Build.ellipsoid(m, ground * CFrame.new(0, 2.6, 0), Vector3.new(0.8, 0.4, 0.8), Color3.fromRGB(180, 110, 40), nil, noCollide)
		for _, side in { -1, 1 } do
			Build.ellipsoid(m, ground * CFrame.new(side * 0.5, 0.9, 0) * CFrame.Angles(0, 0, side * math.rad(-30)), Vector3.new(1, 0.2, 0.5), stemColor, Enum.Material.Grass, noCollide)
		end
	elseif style == "Leaf" then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			Build.ellipsoid(m, ground * CFrame.Angles(0, a, 0) * CFrame.new(0.8, 0.9, 0) * CFrame.Angles(0, 0, math.rad(35)), Vector3.new(2.2, 0.25, 1.1), color, Enum.Material.Grass, noCollide)
		end
		focus = Build.ellipsoid(m, ground * CFrame.new(0, 1.5, 0), Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(190, 240, 255), Enum.Material.Glass, noCollide)
	elseif style == "Root" then
		focus = Build.ellipsoid(m, ground * CFrame.new(0, 0.6, 0), Vector3.new(1.6, 1.4, 1.6), color, nil, noCollide)
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2
			Build.ellipsoid(m, ground * CFrame.new(math.cos(a) * 0.3, 1.8, math.sin(a) * 0.3) * CFrame.Angles(math.cos(a) * 0.4, 0, math.sin(a) * 0.4), Vector3.new(0.3, 1.8, 0.6), stemColor, Enum.Material.Grass, noCollide)
		end
	elseif style == "Pepper" then
		Build.ellipsoid(m, ground * CFrame.new(0, 1, 0), Vector3.new(2.6, 1.6, 2.6), Color3.fromRGB(60, 110, 50), Enum.Material.Grass, noCollide)
		for i = 1, 3 do
			local a = i / 3 * math.pi * 2
			local p = Build.ellipsoid(m, ground * CFrame.new(math.cos(a) * 0.9, 1.2, math.sin(a) * 0.9), Vector3.new(0.5, 1.2, 0.5), color, Enum.Material.Neon, noCollide)
			if i == 1 then
				focus = p
			end
		end
	elseif style == "Mushroom" then
		Build.cylinder(m, ground * CFrame.new(0, 0.8, 0), 1.6, 0.6, Color3.fromRGB(235, 225, 210), nil, noCollide)
		focus = Build.ellipsoid(m, ground * CFrame.new(0, 1.7, 0), Vector3.new(2.2, 1.1, 2.2), color, nil, noCollide)
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2
			Build.ellipsoid(m, ground * CFrame.new(math.cos(a) * 0.6, 2.05, math.sin(a) * 0.6), Vector3.new(0.35, 0.2, 0.35), Color3.new(1, 1, 1), nil, noCollide)
		end
		Build.cylinder(m, ground * CFrame.new(1, 0.4, 0.4), 0.8, 0.35, Color3.fromRGB(235, 225, 210), nil, noCollide)
		Build.ellipsoid(m, ground * CFrame.new(1, 0.9, 0.4), Vector3.new(1, 0.5, 1), color, nil, noCollide)
	elseif style == "Berry" then
		Build.ellipsoid(m, ground * CFrame.new(0, 1.1, 0), Vector3.new(3, 2.2, 3), Color3.fromRGB(50, 90, 80), Enum.Material.Grass, noCollide)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local b = Build.ellipsoid(m, ground * CFrame.new(math.cos(a) * 1.3, 1.3 + (i % 2) * 0.5, math.sin(a) * 1.3), Vector3.new(0.55, 0.55, 0.55), color, Enum.Material.Neon, noCollide)
			if i == 1 then
				focus = b
			end
		end
	else -- Nectar: a glowing crystal flower
		Build.cylinder(m, ground * CFrame.new(0, 1.4, 0), 2.8, 0.25, Color3.fromRGB(200, 230, 255), Enum.Material.Glass, noCollide)
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			Build.ellipsoid(m, ground * CFrame.new(math.cos(a) * 0.6, 3.0, math.sin(a) * 0.6) * CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6), Vector3.new(0.5, 1.6, 0.5), Color3.fromRGB(255, 230, 255), Enum.Material.Glass, noCollide)
		end
		focus = Build.ellipsoid(m, ground * CFrame.new(0, 3.1, 0), Vector3.new(0.8, 0.8, 0.8), color, Enum.Material.Neon, noCollide)
	end

	Build.light(focus, color, 6 + tier * 2, 0.8)
	local sparkle = Build.sparkles(focus, color, tier * 2, 0.3)
	sparkle.Name = "Sparkle"
	m.PrimaryPart = focus
	return m, focus
end

return Props
