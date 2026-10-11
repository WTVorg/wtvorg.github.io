-- Resolves a sound slot ("Throw", "Lock", ...) to a SoundId. Imported art
-- pack sounds win: any Sound named "BG_<Slot>" in SoundService, Workspace or
-- ReplicatedStorage (that's how Asset Manager names them). Otherwise the id
-- in Config.Sounds is used.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(script.Parent.Config)

local Sounds = {}

local found: { [string]: string } = {}
local scanned = false

local function consider(inst: Instance)
	if inst:IsA("Sound") and string.sub(inst.Name, 1, 3) == "BG_" and inst.SoundId ~= "" then
		found[string.sub(inst.Name, 4)] = inst.SoundId
	end
end

local function scan()
	scanned = true
	for _, root in { SoundService, workspace, ReplicatedStorage } do
		for _, d in root:GetDescendants() do
			consider(d)
		end
		root.DescendantAdded:Connect(consider)
	end
end

function Sounds.Get(slot: string): string?
	if not scanned then
		scan()
	end
	local id = found[slot] or Config.Sounds[slot]
	if id and id ~= "" then
		return id
	end
	return nil
end

return Sounds
