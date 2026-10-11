-- Wild guardians: spawning, chase AI, attacks, hazards and resistance.
-- Guardians are anchored models moved by the server every frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuardianModels = require(script.Parent.GuardianModels)
local WorldBuilder = require(script.Parent.WorldBuilder)

local AGGRO_RANGE = 45
local DASH_SPEED = 75
local DODGE_CREDIT_RANGE = 16
local TELEGRAPH_COLOR = Color3.fromRGB(255, 50, 50)

local GuardianService = {}

local rng = Random.new()
local guardians: { [Model]: any } = {}
local folder: Folder
local effects: Folder
local hiddenFolder: Folder
local lastNotify: { [Player]: number } = {}

----------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function notifyThrottled(player: Player, text: string, kind: string)
	local now = os.clock()
	if lastNotify[player] and now - lastNotify[player] < 0.6 then
		return
	end
	lastNotify[player] = now
	Remotes.Notify:FireClient(player, text, kind)
end

local function playersNear(position: Vector3, radius: number): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and (flat(root.Position) - flat(position)).Magnitude <= radius then
			table.insert(out, player)
		end
	end
	return out
end

local function damagePlayer(player: Player, amount: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(amount)
	end
end

local function telegraphDisc(position: Vector3, radius: number, windup: number): Part
	local p = WorldBuilder.Disc("Telegraph", position + Vector3.new(0, 0.35, 0), radius * 0.25, 0.2, TELEGRAPH_COLOR, Enum.Material.Neon, effects)
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 0.45
	TweenService:Create(p, TweenInfo.new(windup, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
	}):Play()
	return p
end

local function shockwave(position: Vector3, radius: number, color: Color3)
	local p = WorldBuilder.Disc("Shockwave", position + Vector3.new(0, 0.5, 0), radius * 0.5, 0.6, color, Enum.Material.Neon, effects)
	p.CanCollide = false
	p.CanQuery = false
	local tween = TweenService:Create(p, TweenInfo.new(0.35), {
		Size = Vector3.new(0.6, radius * 2.3, radius * 2.3),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		p:Destroy()
	end)
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local function now()
	return os.clock()
end

local function isStunned(g)
	return now() < g.StunUntil
end
local function isSlowed(g)
	return now() < g.SlowUntil
end
local function isEnraged(g)
	return now() < g.EnragedUntil
end
local function isCalm(g)
	return now() < g.CalmUntil
end

local function syncAttributes(g)
	local model = g.Model
	local function set(name, value)
		if model:GetAttribute(name) ~= value then
			model:SetAttribute(name, value)
		end
	end
	set("Resistance", math.floor(g.Resistance + 0.5))
	set("FedFavorite", g.FedFavorite)
	set("Stunned", isStunned(g))
	set("Slowed", isSlowed(g))
	set("Enraged", isEnraged(g))
	set("Calm", isCalm(g))
end

local function canAct(g)
	return g.Alive and not g.Capturing
end

function GuardianService.Weaken(g, amount: number, player: Player?, reason: string?)
	if not canAct(g) then
		return
	end
	local before = g.Resistance
	g.Resistance = math.max(0, g.Resistance - amount)
	if player and reason and before > g.Resistance then
		notifyThrottled(
			player,
			string.format("%s! %s resistance -%d", reason, g.Def.Name, math.floor(before - g.Resistance + 0.5)),
			"weaken"
		)
	end
end

local function creditDodge(g, candidates: { Player })
	for _, player in candidates do
		GuardianService.Weaken(g, g.Def.DodgeDrop, player, "Dodged")
	end
end

----------------------------------------------------------------------
-- Attacks (each runs in its own thread and sets g.Busy)
----------------------------------------------------------------------
local function waitWindup(g, seconds: number): boolean
	local t = 0
	while t < seconds do
		t += task.wait()
		if not canAct(g) or isStunned(g) then
			return false
		end
	end
	return true
end

local function cooldown(g)
	local mult = if isEnraged(g) then 0.6 else 1
	g.NextAttack = now() + g.Def.Attack.Cooldown * mult * rng:NextNumber(0.85, 1.2)
end

local function slam(g)
	local atk = g.Def.Attack
	local center = g.Position
	local tele = telegraphDisc(center, atk.Radius, atk.Windup)
	local ok = waitWindup(g, atk.Windup)
	tele:Destroy()
	if ok then
		shockwave(center, atk.Radius, g.Def.Accent)
		local hit = playersNear(center, atk.Radius)
		for _, player in hit do
			damagePlayer(player, atk.Damage)
		end
		if #hit == 0 then
			creditDodge(g, playersNear(center, atk.Radius + DODGE_CREDIT_RANGE))
		end
	end
	cooldown(g)
end

local function charge(g, target: Player)
	local atk = g.Def.Attack
	local targetRoot = rootOf(target)
	if not targetRoot then
		return
	end
	local dir = flat(targetRoot.Position - g.Position)
	if dir.Magnitude < 0.1 then
		dir = g.Facing
	end
	dir = dir.Unit
	g.Facing = dir

	local start = g.Position
	local mid = start + dir * (atk.Length / 2)
	local tele = WorldBuilder.Part({
		Name = "Telegraph",
		Size = Vector3.new(atk.Width, 0.2, atk.Length),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.35, 0), mid + dir + Vector3.new(0, 0.35, 0)),
		Color = TELEGRAPH_COLOR,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
		CanQuery = false,
		Parent = effects,
	})
	local ok = waitWindup(g, atk.Windup)
	tele:Destroy()
	if not ok then
		cooldown(g)
		return
	end

	local travelled = 0
	local hitPlayers = {}
	g.Dashing = true
	while travelled < atk.Length and canAct(g) and not isStunned(g) do
		local dt = RunService.Heartbeat:Wait()
		local step = math.min(DASH_SPEED * dt, atk.Length - travelled)
		local nextPos = g.Position + dir * step
		local offset = nextPos - g.ZoneCenter
		if offset.Magnitude > g.ZoneRadius then
			break -- hit the edge of its territory
		end
		g.Position = nextPos
		travelled += step
		for _, player in playersNear(g.Position, atk.Width / 2 + g.Def.Size * 0.4) do
			if not hitPlayers[player] then
				hitPlayers[player] = true
				damagePlayer(player, atk.Damage)
			end
		end
	end
	g.Dashing = false

	if canAct(g) and not hitPlayers[target] then
		local root = rootOf(target)
		if root and (flat(root.Position) - start).Magnitude <= atk.Length + DODGE_CREDIT_RANGE then
			creditDodge(g, { target })
		end
	end
	cooldown(g)
end

local function orbs(g, target: Player)
	local atk = g.Def.Attack
	local targetRoot = rootOf(target)
	if not targetRoot then
		return
	end
	local spots = {}
	local base = flat(targetRoot.Position)
	for i = 1, atk.Orbs or 1 do
		local offset = if i == 1
			then Vector3.zero
			else Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * atk.Radius * 1.6
		table.insert(spots, base + offset)
	end
	local teles = {}
	for _, spot in spots do
		table.insert(teles, telegraphDisc(spot, atk.Radius, atk.Windup))
	end
	local ok = waitWindup(g, atk.Windup)
	for _, t in teles do
		t:Destroy()
	end
	if ok then
		local targetHit = false
		for _, spot in spots do
			shockwave(spot, atk.Radius, g.Def.Accent)
			for _, player in playersNear(spot, atk.Radius) do
				damagePlayer(player, atk.Damage)
				if player == target then
					targetHit = true
				end
			end
		end
		if not targetHit and rootOf(target) then
			creditDodge(g, { target })
		end
	end
	cooldown(g)
end

local function startAttack(g, kind: string, target: Player)
	g.Busy = true
	task.spawn(function()
		local ok, err = pcall(function()
			if kind == "Slam" then
				slam(g)
			elseif kind == "Charge" then
				charge(g, target)
			else
				orbs(g, target)
			end
		end)
		if not ok then
			warn("[Guardian] attack error:", err)
		end
		g.Busy = false
		g.Dashing = false
	end)
end

----------------------------------------------------------------------
-- Movement and AI
----------------------------------------------------------------------
local function inHazard(zoneId: string, position: Vector3, pad: number)
	for _, hazard in WorldBuilder.Hazards do
		if hazard.Zone == zoneId and (flat(hazard.Position) - flat(position)).Magnitude < hazard.Radius + pad then
			return hazard
		end
	end
	return nil
end

local function pickWanderTarget(g): Vector3
	for _ = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * (g.ZoneRadius - 8)
		local p = g.ZoneCenter + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if not inHazard(g.ZoneId, p, g.Def.Size + 3) then
			return p
		end
	end
	return g.ZoneCenter
end

local function nearestTarget(g): (Player?, number)
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local inZone = (flat(root.Position) - g.ZoneCenter).Magnitude <= g.ZoneRadius + 20
			local d = (flat(root.Position) - g.Position).Magnitude
			if inZone and d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	if bestDist > AGGRO_RANGE then
		return nil, bestDist
	end
	return best, bestDist
end

local function move(g, direction: Vector3, speed: number, dt: number): boolean
	if direction.Magnitude < 0.01 then
		return false
	end
	direction = flat(direction).Unit
	g.Facing = g.Facing:Lerp(direction, math.min(dt * 8, 1))
	if g.Facing.Magnitude > 0.01 then
		g.Facing = g.Facing.Unit
	end
	local nextPos = g.Position + direction * speed * dt
	local offset = nextPos - g.ZoneCenter
	local cornered = false
	if offset.Magnitude > g.ZoneRadius then
		nextPos = g.ZoneCenter + offset.Unit * g.ZoneRadius
		cornered = true
	end
	g.Position = nextPos
	g.Moving = true
	return cornered
end

local function think(g, dt: number)
	local def = g.Def
	local t = now()
	g.Moving = false

	if g.Busy or isStunned(g) then
		return
	end

	local speed = def.Speed * (if isSlowed(g) then 0.5 else 1) * (if isEnraged(g) then 1.4 else 1)
	local target, dist = nearestTarget(g)

	if target and not isCalm(g) then
		g.LastPlayerNear = t
		local root = rootOf(target) :: BasePart
		local toTarget = flat(root.Position) - g.Position
		local ready = t >= g.NextAttack
		local behavior = def.Behavior
		local atk = def.Attack

		if behavior == "Skittish" then
			local cornered = false
			if dist < 26 then
				cornered = move(g, -toTarget, speed, dt)
			end
			if ready and (dist < atk.Radius * 0.85 or (cornered and dist < atk.Radius * 1.5)) then
				startAttack(g, "Slam", target)
			end
		elseif behavior == "Charger" then
			if dist > atk.Length * 0.6 then
				move(g, toTarget, speed, dt)
			elseif ready then
				startAttack(g, "Charge", target)
			end
		elseif behavior == "Caster" then
			if dist < 18 then
				move(g, -toTarget, speed, dt)
			elseif dist > 34 then
				move(g, toTarget, speed, dt)
			end
			if ready then
				startAttack(g, "Orbs", target)
			end
		else -- Legendary: rotates through every attack
			if dist > 28 then
				move(g, toTarget, speed, dt)
			end
			if ready then
				g.AttackIndex = (g.AttackIndex % 3) + 1
				local kind = ({ "Slam", "Charge", "Orbs" })[g.AttackIndex]
				if kind == "Slam" and dist > atk.Radius * 1.2 then
					kind = "Orbs"
				end
				startAttack(g, kind, target)
			end
		end
		return
	end

	-- Nobody close (or calmed down): wander and slowly recover.
	if not target and t - g.LastPlayerNear > Config.Catch.RegenDelay then
		g.Resistance = math.min(100, g.Resistance + Config.Catch.RegenPerSecond * dt)
	end
	if t < g.PauseUntil then
		return
	end
	local toWander = g.WanderTarget - g.Position
	if toWander.Magnitude < 2 then
		g.WanderTarget = pickWanderTarget(g)
		g.PauseUntil = t + rng:NextNumber(1, 4)
		return
	end
	move(g, toWander, speed * 0.45, dt)
end

local function checkHazards(g)
	if now() < g.HazardCooldownUntil then
		return
	end
	local hazard = inHazard(g.ZoneId, g.Position, g.Def.Size * 0.3)
	if not hazard then
		return
	end
	g.HazardCooldownUntil = now() + 4
	g.StunUntil = now() + Config.Catch.StunSeconds
	local before = g.Resistance
	g.Resistance = math.max(0, g.Resistance - g.Def.HazardDrop)
	shockwave(g.Position, g.Def.Size, hazard.Part.Color)
	local text = string.format(
		"%s stumbled into the %s! Resistance -%d",
		g.Def.Name,
		hazard.Name,
		math.floor(before - g.Resistance + 0.5)
	)
	for _, player in playersNear(g.Position, 90) do
		notifyThrottled(player, text, "weaken")
	end
end

local function render(g)
	local bob = if g.Moving then math.abs(math.sin(now() * 10)) * 0.4 else math.sin(now() * 2) * 0.15
	if isStunned(g) then
		bob = 0
	end
	local pos = g.Position + Vector3.new(0, g.HalfHeight + bob, 0)
	local facing = if g.Facing.Magnitude > 0.01 then g.Facing else Vector3.new(0, 0, -1)
	local cf = CFrame.lookAt(pos, pos + facing)
	if isStunned(g) then
		cf *= CFrame.Angles(0, 0, math.sin(now() * 25) * 0.15)
	end
	g.Model:PivotTo(cf)
end

----------------------------------------------------------------------
-- Spawning
----------------------------------------------------------------------
local spawnGuardian

local function scheduleRespawn(id: string)
	task.delay(Config.Guardians[id].Respawn, function()
		spawnGuardian(id)
	end)
end

function spawnGuardian(id: string)
	local def = Config.Guardians[id]
	local zone = Config.Zones[def.Zone]
	local model = GuardianModels.Build(id)
	model:SetAttribute("GuardianId", id)

	local g = {
		Id = id,
		Def = def,
		Model = model,
		ZoneId = def.Zone,
		ZoneCenter = Config.ZoneCenter(def.Zone),
		ZoneRadius = zone.Radius - 6,
		Position = Vector3.zero,
		Facing = Vector3.new(0, 0, -1),
		HalfHeight = def.Size / 2,
		Resistance = 100,
		FedFavorite = false,
		StunUntil = 0,
		SlowUntil = 0,
		EnragedUntil = 0,
		CalmUntil = 0,
		NextAttack = 0,
		HazardCooldownUntil = 0,
		LastPlayerNear = 0,
		PauseUntil = 0,
		AttackIndex = 0,
		Busy = false,
		Dashing = false,
		Moving = false,
		Capturing = false,
		Alive = true,
	}
	g.Position = pickWanderTarget(g)
	g.WanderTarget = pickWanderTarget(g)
	guardians[model] = g
	syncAttributes(g)
	render(g)
	model.Parent = folder

	if def.Announce then
		Remotes.Announce:FireAllClients(string.format("A legendary %s has appeared in %s!", def.Name, zone.Name))
	end
	return g
end

----------------------------------------------------------------------
-- Public API used by the action handlers
----------------------------------------------------------------------
function GuardianService.FromModel(model: Instance?)
	if typeof(model) ~= "Instance" then
		return nil
	end
	local g = guardians[model :: Model]
	if g and canAct(g) then
		return g
	end
	return nil
end

function GuardianService.Chance(g, flaskMult: number, luck: number): number
	return CatchMath.Chance({
		BaseRate = g.Def.BaseRate,
		FlaskMult = flaskMult,
		Resistance = g.Resistance,
		FedFavorite = g.FedFavorite,
		Stunned = isStunned(g),
		Slowed = isSlowed(g),
		Luck = luck,
	})
end

function GuardianService.GroundPosition(g): Vector3
	return g.Position
end

-- Live, catchable guardians.
function GuardianService.All()
	local out = {}
	for _, g in guardians do
		if canAct(g) then
			table.insert(out, g)
		end
	end
	return out
end

function GuardianService.Celebrate(g, color: Color3)
	local root = g.Model.PrimaryPart
	if not root then
		return
	end
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(color)
	burst.Size = NumberSequence.new(0.8, 0)
	burst.Speed = NumberRange.new(4, 8)
	burst.Lifetime = NumberRange.new(0.8, 1.4)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = root
	burst:Emit(40)
	task.delay(2, function()
		burst:Destroy()
	end)
end

function GuardianService.BeginCapture(g)
	g.Capturing = true
	g.Busy = false
	g.Model.Parent = hiddenFolder
end

function GuardianService.EndCapture(g, caught: boolean)
	if caught then
		g.Alive = false
		guardians[g.Model] = nil
		g.Model:Destroy()
		scheduleRespawn(g.Id)
		return
	end
	-- Burst out, furious.
	g.Capturing = false
	g.FedFavorite = false
	g.CalmUntil = 0
	g.StunUntil = 0
	g.Resistance = math.min(100, g.Resistance + Config.Catch.BreakFreeResistance)
	g.EnragedUntil = now() + Config.Catch.EnragedSeconds
	g.NextAttack = now() + 0.8
	g.Model.Parent = folder
	syncAttributes(g)
	render(g)
end

function GuardianService.ApplyDraught(g, power: number, player: Player)
	GuardianService.Weaken(g, power, player, "Draught hit")
	g.SlowUntil = now() + Config.DraughtSlowSeconds
	shockwave(g.Position, g.Def.Size, Color3.fromRGB(140, 255, 160))
end

function GuardianService.Feed(g, isFavorite: boolean)
	if isFavorite then
		g.FedFavorite = true
		g.CalmUntil = now() + Config.Catch.CalmSeconds
		g.EnragedUntil = 0
	end
end

function GuardianService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace

	effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = workspace

	hiddenFolder = Instance.new("Folder")
	hiddenFolder.Name = "CapturingGuardians"
	hiddenFolder.Parent = ServerStorage

	for _, id in Config.GuardianOrder do
		for _ = 1, Config.Guardians[id].Count do
			spawnGuardian(id)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, g in guardians do
			if canAct(g) then
				think(g, dt)
				checkHazards(g)
				syncAttributes(g)
				render(g)
			end
		end
	end)

	-- Hazards hurt players too, so luring a guardian into one is a risk.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, hazard in WorldBuilder.Hazards do
				for _, player in playersNear(hazard.Position, hazard.Radius) do
					damagePlayer(player, Config.HazardPlayerDamage)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastNotify[player] = nil
	end)
end

return GuardianService
