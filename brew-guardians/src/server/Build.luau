-- Low-level part helpers shared by the world, plots and guardian builders.
-- Ellipsoids use a SpecialMesh sphere, which stretches to fill the part, so
-- bodies can be egg-shaped instead of perfect balls.

local Build = {}

local function apply(p: BasePart, color: Color3?, material: Enum.Material?, props: { [string]: any }?)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	if color then
		p.Color = color
	end
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
end

function Build.part(parent: Instance, cf: CFrame, size: Vector3, color: Color3?, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	apply(p, color, material, props)
	p.Parent = parent
	return p
end

function Build.ellipsoid(parent: Instance, cf: CFrame, size: Vector3, color: Color3?, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Build.part(parent, cf, size, color, material, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Cylinder standing along cf's up vector.
function Build.cylinder(parent: Instance, cf: CFrame, height: number, diameter: number, color: Color3?, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	apply(p, color, material, props)
	p.Parent = parent
	return p
end

function Build.wedge(parent: Instance, cf: CFrame, size: Vector3, color: Color3?, material: Enum.Material?, props: { [string]: any }?): WedgePart
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = cf
	apply(p, color, material, props)
	p.Parent = parent
	return p
end

-- A tapered horn pointing along cf's up vector (two stacked ellipsoids).
function Build.spike(parent: Instance, cf: CFrame, height: number, width: number, color: Color3?, material: Enum.Material?, props: { [string]: any }?)
	Build.ellipsoid(parent, cf * CFrame.new(0, height * 0.32, 0), Vector3.new(width, height * 0.7, width), color, material, props)
	Build.ellipsoid(parent, cf * CFrame.new(0, height * 0.68, 0), Vector3.new(width * 0.5, height * 0.62, width * 0.5), color, material, props)
end

-- A roof-like ridge along cf's up vector (two wedges back to back), for crystal tips.
function Build.tent(parent: Instance, cf: CFrame, height: number, width: number, color: Color3?, material: Enum.Material?, props: { [string]: any }?)
	local half = width / 2
	Build.wedge(parent, cf * CFrame.new(0, height / 2, -half / 2), Vector3.new(width, height, half), color, material, props)
	Build.wedge(parent, cf * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.pi, 0), Vector3.new(width, height, half), color, material, props)
end

-- Torus-like ring lying flat in cf's XZ plane.
function Build.ring(parent: Instance, cf: CFrame, radius: number, thickness: number, segments: number, color: Color3?, material: Enum.Material?, props: { [string]: any }?)
	local seg = 2 * math.pi * radius / segments * 1.08
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local at = cf * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(seg, thickness, thickness)
		-- cylinder axis is X; turn it to run tangent to the ring
		p.CFrame = at * CFrame.Angles(0, math.rad(90), 0)
		apply(p, color, material, props)
		p.Parent = parent
	end
end

-- Moves a model up or down so its lowest point sits at groundY.
function Build.sitOnGround(model: Model, groundY: number)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, groundY - bottom, 0))
end

function Build.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

function Build.light(parent: Instance, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = parent
	return l
end

function Build.sparkles(parent: Instance, color: Color3, rate: number, size: number?)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size or 0.4, 0)
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Rate = rate
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = parent
	return e
end

-- Big readable text on a part face.
function Build.surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.6
	label.Text = text
	label.Parent = gui
	return label
end

return Build
