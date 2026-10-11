-- Finds the imported art pack (art/BrewGuardiansArt.fbx, brought in with
-- Studio's File > Import 3D) wherever it was dropped, fixes its orientation
-- and scale, and turns each asset into a reusable template.
--
-- The pack carries three marker meshes (ArtOrigin, ArtForward 5 units in
-- front, ArtUp 5 units above), so whatever axes or units the importer used,
-- the loader can recover them exactly. Without the pack every builder falls
-- back to the part-built versions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ArtManifest = require(ReplicatedStorage.Shared.ArtManifest)

local Art = {}

local templates: { [string]: Model } = {}
local loaded = false

local function findMarker(): BasePart?
	for _, root in { workspace, ServerStorage, ReplicatedStorage } do
		local found = root:FindFirstChild("ArtOrigin", true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return nil
end

-- Every BasePart belonging to an asset (the importer may wrap meshes in Models).
local function partsNamed(container: Instance, name: string): { BasePart }
	local out = {}
	for _, d in container:GetDescendants() do
		if d.Name == name or d.Name == name .. "_Glow" then
			if d:IsA("BasePart") then
				table.insert(out, d)
			elseif d:IsA("Model") then
				for _, p in d:GetDescendants() do
					if p:IsA("BasePart") then
						table.insert(out, p)
					end
				end
			end
		end
	end
	return out
end

local function isGlow(part: BasePart): boolean
	local node: Instance? = part
	while node do
		if string.sub(node.Name, -5) == "_Glow" then
			return true
		end
		node = node.Parent
	end
	return false
end

-- A saturated, bright version of a colour so Neon reads as glowing.
local function vivid(c: Color3): Color3
	local h, s, _ = c:ToHSV()
	return Color3.fromHSV(h, math.max(s, 0.7), 1)
end

function Art.Init()
	if loaded then
		return
	end
	loaded = true
	local origin = findMarker()
	if not origin then
		print("[Art] no imported art pack found, using built-in part models")
		return
	end
	-- climb to the top-level imported model (the importer may nest meshes)
	local services = { [workspace] = true, [ServerStorage] = true, [ReplicatedStorage] = true }
	local container: Instance = origin
	while container.Parent and not services[container.Parent] do
		container = container.Parent :: Instance
	end
	if container == origin then
		container = origin.Parent :: Instance -- meshes were dropped loose into a service
	end
	local forward = container:FindFirstChild("ArtForward", true) :: BasePart?
	local up = container:FindFirstChild("ArtUp", true) :: BasePart?
	if not forward or not up then
		warn("[Art] art pack is missing its ArtForward/ArtUp markers, re-import art/BrewGuardiansArt.fbx")
		return
	end

	local o = origin.CFrame.Position
	local f = forward.CFrame.Position - o
	local u = up.CFrame.Position - o
	local unit = f.Magnitude / 5 -- studs per Blender unit in this import
	local fN, uN = f.Unit, u.Unit
	-- The imported coordinate frame: its forward/up mapped onto Roblox's -Z/+Y.
	local importedFrame = CFrame.fromMatrix(o, fN:Cross(uN), uN, -fN)

	local folder = Instance.new("Folder")
	folder.Name = "ArtTemplates"
	folder.Parent = ServerStorage

	local count = 0
	for name, info in ArtManifest do
		local parts = partsNamed(container, name)
		if #parts > 0 then
			local model = Instance.new("Model")
			model.Name = name
			for _, src in parts do
				local p = src:Clone()
				for _, child in p:GetChildren() do
					if not child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				local rel = importedFrame:ToObjectSpace(src.CFrame)
				p.Size = src.Size / unit
				p.CFrame = CFrame.new(rel.Position / unit) * rel.Rotation
				p.Anchored = true
				p.CanCollide = false
				p.CastShadow = true
				if isGlow(src) then
					p.Name = "Glow"
					p.Material = Enum.Material.Neon
					p.Color = vivid(info.Glow or Color3.fromRGB(255, 200, 120))
					p.CastShadow = false
					local sa = p:FindFirstChildOfClass("SurfaceAppearance")
					if sa then
						sa:Destroy()
					end
					if p:IsA("MeshPart") then
						p.TextureID = ""
					end
				else
					p.Name = "Mesh"
				end
				p.Parent = model
			end
			-- pivot at the asset's ground centre (Blender origin)
			model.WorldPivot = CFrame.new()
			model.Parent = folder
			templates[name] = model
			count += 1
		end
	end

	-- Keep the raw import out of the world.
	if not services[container] then
		container.Parent = ServerStorage
	end
	print(string.format("[Art] loaded %d meshes from the art pack (%.2f studs per unit)", count, unit))
end

function Art.Has(name: string): boolean
	return templates[name] ~= nil
end

-- Clone an asset, scaled so its full height is `height` studs, with its
-- ground centre at `ground`. Returns nil when the pack isn't imported.
function Art.Spawn(name: string, ground: CFrame, height: number, parent: Instance?): Model?
	local template = templates[name]
	if not template then
		return nil
	end
	local model = template:Clone()
	local info = ArtManifest[name]
	model:ScaleTo(height / info.Height)
	model:PivotTo(ground)
	if parent then
		model.Parent = parent
	end
	return model
end

-- Same as Spawn but sized by uniform scale (1 Blender unit = `scale` studs).
function Art.SpawnScaled(name: string, ground: CFrame, scale: number, parent: Instance?): Model?
	local info = ArtManifest[name]
	if not info then
		return nil
	end
	return Art.Spawn(name, ground, info.Height * scale, parent)
end

-- Recolour an asset's glowing parts.
function Art.SetGlow(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Glow" then
			d.Color = vivid(color)
		end
	end
end

return Art
