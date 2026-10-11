-- Builds a guardian body. Uses ServerStorage.GuardianModels[id] when it
-- exists, otherwise a placeholder creature made of parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GuardianModels = {}

local function weldTo(root: BasePart, p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
end

local function add(model: Model, root: BasePart, props): Part
	local p = Instance.new(props.ClassName or "Part") :: Part
	props.ClassName = nil
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local offset = props.Offset or CFrame.identity
	props.Offset = nil
	for k, v in props do
		(p :: any)[k] = v
	end
	p.CFrame = root.CFrame * offset
	p.Parent = model
	weldTo(root, p)
	return p
end

local function placeholder(id: string): Model
	local def = Config.Guardians[id]
	local s = def.Size
	local model = Instance.new("Model")

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(s, s, s)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.CFrame = CFrame.new(0, s / 2, 0)
	root.Parent = model
	model.PrimaryPart = root

	local body = add(model, root, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * s,
		Color = def.Color,
		Material = if def.Element == "Ice" then Enum.Material.Glass else Enum.Material.SmoothPlastic,
	})
	body.CastShadow = true

	local head = add(model, root, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * s * 0.65,
		Color = def.Color,
		Offset = CFrame.new(0, s * 0.35, -s * 0.45),
	})

	for _, side in { -1, 1 } do
		add(model, root, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s * 0.16,
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.Neon,
			Offset = CFrame.new(side * s * 0.14, s * 0.45, -s * 0.74),
		})
		add(model, root, {
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s * 0.08,
			Color = Color3.new(0.05, 0.05, 0.08),
			Offset = CFrame.new(side * s * 0.14, s * 0.45, -s * 0.81),
		})

		-- Element features
		if def.Element == "Nature" then
			add(model, root, {
				Name = "Leaf",
				Size = Vector3.new(s * 0.1, s * 0.5, s * 0.3),
				Color = def.Accent,
				Material = Enum.Material.Grass,
				Offset = CFrame.new(side * s * 0.2, s * 0.8, -s * 0.4) * CFrame.Angles(0, 0, side * math.rad(-25)),
			})
		elseif def.Element == "Fire" then
			add(model, root, {
				Name = "Horn",
				ClassName = "WedgePart",
				Size = Vector3.new(s * 0.12, s * 0.45, s * 0.2),
				Color = def.Accent,
				Material = Enum.Material.Neon,
				Offset = CFrame.new(side * s * 0.22, s * 0.78, -s * 0.38),
			})
		else
			add(model, root, {
				Name = "Ear",
				ClassName = "WedgePart",
				Size = Vector3.new(s * 0.08, s * 0.4, s * 0.25),
				Color = def.Accent,
				Material = Enum.Material.Neon,
				Offset = CFrame.new(side * s * 0.22, s * 0.78, -s * 0.42) * CFrame.Angles(0, math.rad(180), 0),
			})
		end

		-- Stubby feet
		for _, front in { -1, 1 } do
			add(model, root, {
				Name = "Foot",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * s * 0.3,
				Color = def.Accent,
				Offset = CFrame.new(side * s * 0.3, -s * 0.42, front * s * 0.25),
			})
		end
	end

	add(model, root, {
		Name = "Tail",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s * 0.3, s * 0.3, s * 0.6),
		Color = def.Accent,
		Material = Enum.Material.Neon,
		Offset = CFrame.new(0, s * 0.1, s * 0.55),
	})

	if def.Behavior == "Charger" then
		add(model, root, {
			Name = "Spines",
			ClassName = "WedgePart",
			Size = Vector3.new(s * 0.15, s * 0.45, s * 0.9),
			Color = def.Accent,
			Offset = CFrame.new(0, s * 0.55, s * 0.05),
		})
	end

	local light = Instance.new("PointLight")
	light.Color = def.Accent
	light.Range = s * 2
	light.Brightness = if def.Rarity == "Legendary" then 3 else 1
	light.Parent = head

	if def.Rarity == "Legendary" or def.Rarity == "Rare" then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(def.Accent, def.Color)
		aura.Size = NumberSequence.new(s * 0.15, 0)
		aura.Lifetime = NumberRange.new(1, 1.6)
		aura.Rate = if def.Rarity == "Legendary" then 25 else 8
		aura.Speed = NumberRange.new(1, 3)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = body
	end

	return model
end

-- Returns a model whose PrimaryPart pivot sits at ground level + half height.
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
		model = placeholder(id)
	end
	model.Name = id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local m = Config.Mutations[mutation or 0]
	if m then
		model:ScaleTo(m.Scale)
		-- Mutated forms glow a little.
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Tail" then
				d.Color = Color3.fromRGB(255, 80, 200)
			end
		end
	end
	return model
end

-- Moves the model up or down so its lowest point sits at groundY.
function GuardianModels.SitOnGround(model: Model, groundY: number)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, groundY - bottom, 0))
end

return GuardianModels
