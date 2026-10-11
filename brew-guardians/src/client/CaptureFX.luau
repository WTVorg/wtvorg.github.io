-- The throw arc and the shake moment. The server decides the outcome up
-- front and sends how many shakes pass; this plays it back with rising
-- tension: each shake wobbles harder, sounds higher and fills one more dot,
-- then the flask either locks with a flash or shatters.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local CaptureFX = {}

local fxFolder: Folder

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function sound(id: string, parent: Instance, speed: number?, volume: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed or 1
	s.Volume = volume or 0.7
	s.RollOffMaxDistance = 150
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 4)
end

local function newPart(props): Part
	local p = Instance.new(props.ClassName or "Part") :: Part
	props.ClassName = nil
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = props.Parent or fxFolder
	return p
end

local function sparkles(parent: Instance, color: Color3, amount: number, speed: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(0.6, 0)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.Lifetime = NumberRange.new(0.5, 1)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.LightEmission = 1
	e.Parent = parent
	e:Emit(amount)
	Debris:AddItem(e, 2)
end

local function ring(position: Vector3, color: Color3, size: number)
	local p = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 1, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	local t = TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, size, size),
		Transparency = 1,
	})
	t:Play()
	Debris:AddItem(p, 0.5)
end

local function cameraShake(intensity: number, duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		local t = 0
		while t < duration do
			local fade = 1 - t / duration
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * intensity * fade,
				(math.random() - 0.5) * intensity * fade,
				0
			)
			t += RunService.RenderStepped:Wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- A little flask: round body, neck and cork.
local function buildFlask(color: Color3, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Flask"
	local bodyPart = newPart({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2 * scale,
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = model,
	})
	newPart({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.3 * scale,
		Color = color,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	newPart({
		Name = "Neck",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.9 * scale, 0.7 * scale, 0.7 * scale),
		CFrame = CFrame.new(0, 1.2 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = model,
	})
	newPart({
		Name = "Cork",
		Size = Vector3.new(0.6, 0.4, 0.6) * scale,
		CFrame = CFrame.new(0, 1.75 * scale, 0),
		Color = Color3.fromRGB(150, 105, 60),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 2
	light.Parent = bodyPart
	model.PrimaryPart = bodyPart
	model.Parent = fxFolder
	return model
end

-- Pivot a flask so the bottom of the body touches `ground`, tilted by `tilt`.
-- Rocks around the bottom of the flask, not its centre.
local function placeFlask(flask: Model, ground: Vector3, tilt: number, scale: number)
	flask:PivotTo(CFrame.new(ground) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, scale, 0))
end

local function flaskColor(flaskId: string): Color3
	local f = Config.GetFlask(flaskId)
	return f and f.Color or Color3.new(1, 1, 1)
end

----------------------------------------------------------------------
-- Throw arc
----------------------------------------------------------------------
local function onThrowVisual(from: Vector3, target: Instance?, color: Color3, flight: number)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return
	end
	local model = target :: Model
	local flask = buildFlask(color, 0.6)
	sound(Config.Sounds.Throw, flask.PrimaryPart :: BasePart, 1.1, 0.6)
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.4, 0)
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.4, 0)
	a0.Parent = flask.PrimaryPart
	a1.Parent = flask.PrimaryPart
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.3
	trail.LightEmission = 1
	trail.Parent = flask.PrimaryPart

	local t = 0
	local last = model:GetPivot().Position
	while t < flight do
		t += RunService.RenderStepped:Wait()
		local alpha = math.min(t / flight, 1)
		if model.Parent then
			last = model:GetPivot().Position
		end
		local height = math.max((from - last).Magnitude * 0.25, 4)
		local pos = from:Lerp(last, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * height, 0)
		flask:PivotTo(CFrame.new(pos) * CFrame.Angles(alpha * 12, alpha * 6, 0))
	end
	flask:Destroy()
end

----------------------------------------------------------------------
-- The shake sequence
----------------------------------------------------------------------
local function dotsGui(adornee: BasePart): (BillboardGui, { Frame })
	local gui = UI.make("BillboardGui", {
		Adornee = adornee,
		Size = UDim2.fromOffset(150, 44),
		StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0),
		AlwaysOnTop = true,
		MaxDistance = 160,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local holder = UI.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local layout = UI.list(holder, 10, true)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local dots = {}
	for i = 1, CatchMath.Shakes do
		table.insert(dots, UI.make("Frame", {
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = Color3.fromRGB(40, 35, 55),
			Corner = 14,
			Stroke = Color3.new(1, 1, 1),
			LayoutOrder = i,
			Parent = holder,
		}))
	end
	return gui, dots
end

local function wobble(flask: Model, ground: Vector3, scale: number, amplitude: number, duration: number)
	-- Three half-swings that settle back to upright.
	local t = 0
	while t < duration do
		t += RunService.RenderStepped:Wait()
		local alpha = math.min(t / duration, 1)
		local tilt = math.sin(alpha * math.pi * 3) * amplitude * (1 - alpha * 0.4)
		placeFlask(flask, ground, tilt, scale)
	end
	placeFlask(flask, ground, 0, scale)
end

local function shatter(flask: Model, color: Color3)
	local center = flask:GetPivot().Position
	for _, part in flask:GetDescendants() do
		if part:IsA("BasePart") then
			part:Destroy()
		end
	end
	for _ = 1, 10 do
		local shard = newPart({
			ClassName = "WedgePart",
			Size = Vector3.new(0.2, math.random() * 0.6 + 0.3, math.random() * 0.6 + 0.3),
			CFrame = CFrame.new(center) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
		shard.Anchored = false
		shard.CanCollide = true
		shard.AssemblyLinearVelocity = Vector3.new(math.random(-25, 25), math.random(15, 35), math.random(-25, 25))
		shard.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
		Debris:AddItem(shard, 2.5)
	end
end

local function onCaptureSequence(info)
	local ground: Vector3 = info.Position
	local shakes: number = info.Shakes
	local isMine = info.ThrowerUserId == player.UserId
	local def = Config.Guardians[info.GuardianId]
	local color = flaskColor(info.FlaskId)
	local accent = def and def.Accent or Color3.new(1, 1, 1)
	local scale = 1.1

	-- Only the thrower and people nearby need the full show.
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not isMine and (not root or (root.Position - ground).Magnitude > 200) then
		return
	end

	local flask = buildFlask(color, scale)
	local body = flask.PrimaryPart :: BasePart

	-- 1) Swallow: a bright sphere the size of the guardian collapses into the flask.
	local size = def and def.Size * 1.3 or 5
	local orb = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = CFrame.new(ground + Vector3.new(0, size / 2, 0)),
		Color = accent,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	TweenService:Create(orb, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.one * 0.5,
		CFrame = CFrame.new(ground + Vector3.new(0, scale, 0)),
		Transparency = 0.6,
	}):Play()
	Debris:AddItem(orb, 0.4)

	-- Flask drops in with a little bounce.
	local dropStart = os.clock()
	while os.clock() - dropStart < 0.3 do
		local a = (os.clock() - dropStart) / 0.3
		local bounce = math.abs(math.sin(a * math.pi * 1.5)) * (1 - a) * 3
		flask:PivotTo(CFrame.new(ground + Vector3.new(0, scale + bounce + (1 - a) * 4, 0)))
		RunService.RenderStepped:Wait()
	end
	placeFlask(flask, ground, 0, scale)
	ring(ground + Vector3.new(0, 0.3, 0), color, 10)
	sparkles(body, accent, 25, 10)
	if isMine then
		cameraShake(0.4, 0.2)
	end

	local gui, dots = dotsGui(body)
	task.wait(math.max(CatchMath.LandTime - 0.3, 0))

	-- 2) Shakes. A burst happens partway through shake number shakes + 1.
	for i = 1, CatchMath.Shakes do
		local amplitude = math.rad(14 + i * 9)
		local pitch = 0.9 + i * 0.18
		sound(Config.Sounds.Shake, body, pitch, 0.6 + i * 0.15)
		if i > shakes then
			-- Breaking free: a violent half-wobble, then glass everywhere.
			wobble(flask, ground, scale, amplitude * 1.6, CatchMath.ShakeInterval * 0.35)
			local nearMiss = i == CatchMath.Shakes
			dots[i].BackgroundColor3 = Color3.fromRGB(255, 70, 70)
			sound(Config.Sounds.Burst, body, 0.8, 1)
			ring(ground + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 80, 60), 18)
			shatter(flask, color)
			local burstAnchor = newPart({ Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(ground + Vector3.new(0, 2, 0)) })
			sparkles(burstAnchor, Color3.fromRGB(255, 90, 70), 50, 25)
			Debris:AddItem(burstAnchor, 2)
			if isMine then
				cameraShake(if nearMiss then 1.6 else 1, 0.45)
				Hud.Flash(Color3.fromRGB(255, 60, 60), if nearMiss then 0.45 else 0.3)
				Hud.BigText(if nearMiss then "SO CLOSE!" else "It broke free!", Color3.fromRGB(255, 110, 90))
			end
			task.wait(0.6)
			gui:Destroy()
			flask:Destroy()
			return
		end

		wobble(flask, ground, scale, amplitude, CatchMath.ShakeInterval * 0.55)
		-- Shake survived: light up a dot and pulse.
		local dot = dots[i]
		dot.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
		TweenService:Create(dot, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(34, 34) }):Play()
		ring(ground + Vector3.new(0, 0.3, 0), accent, 6 + i * 4)
		sparkles(body, accent, 8 * i, 6 + i * 3)
		if isMine then
			cameraShake(0.25 + i * 0.25, 0.2)
		end
		task.wait(CatchMath.ShakeInterval * 0.45)
	end

	-- 3) Click. Locked.
	sound(Config.Sounds.Lock, body, 1.2, 1)
	for _, d in dots do
		d.BackgroundColor3 = Color3.fromRGB(120, 255, 140)
	end
	ring(ground + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 240, 150), 24)
	sparkles(body, Color3.fromRGB(255, 230, 120), 80, 22)
	local core = flask:FindFirstChild("Core") :: BasePart?
	if core then
		core.Color = Color3.new(1, 1, 1)
	end
	if isMine then
		Hud.Flash(Color3.new(1, 1, 1), 0.65)
		Hud.BigText("GOTCHA!", Color3.fromRGB(255, 225, 90), 1.8)
		cameraShake(0.6, 0.3)
	end
	task.wait(CatchMath.ResultTime)
	gui:Destroy()

	-- Flask zips off toward the thrower's plot (upwards and away).
	for _, part in flask:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = part.Size * 0.05,
				Position = part.Position + Vector3.new(0, 12, 0),
			}):Play()
		end
	end
	Debris:AddItem(flask, 0.6)
end

----------------------------------------------------------------------
-- Plot guardians idle-bob locally so displays feel alive.
----------------------------------------------------------------------
local function bobPlotGuardians()
	local plots = workspace:WaitForChild("Plots", 30)
	if not plots then
		return
	end
	local base: { [Model]: CFrame } = {}
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, plot in plots:GetChildren() do
			local displays = plot:FindFirstChild("Displays")
			if displays then
				for i, model in displays:GetChildren() do
					if model:IsA("Model") and model.PrimaryPart then
						if not base[model] then
							base[model] = model:GetPivot()
							model.Destroying:Once(function()
								base[model] = nil
							end)
						end
						local offset = math.abs(math.sin(t * 2 + i)) * 0.6
						model:PivotTo(base[model] * CFrame.new(0, offset, 0))
					end
				end
			end
		end
	end)
end

function CaptureFX.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LocalFX"
	fxFolder.Parent = workspace

	Remotes.ThrowVisual.OnClientEvent:Connect(function(...)
		task.spawn(onThrowVisual, ...)
	end)
	Remotes.CaptureSequence.OnClientEvent:Connect(function(info)
		task.spawn(onCaptureSequence, info)
	end)
	task.spawn(bobPlotGuardians)
end

return CaptureFX
