-- Creates (server) or waits for (client) every RemoteEvent the game uses.

local RunService = game:GetService("RunService")

local NAMES = {
	-- server -> client
	"StateUpdate", -- (data snapshot)
	"Notify", -- (text, kind)
	"OpenUI", -- (screenName)
	"ThrowVisual", -- (fromPos, guardianModel, color, flightTime)
	"CaptureSequence", -- (info table)
	"Announce", -- (text) server-wide banner
	-- client -> server
	"Throw", -- (kind "Flask"|"Draught", tierId, guardianModel)
	"Feed", -- (guardianModel, ingredientId)
	"Brew", -- (mode "Flask"|"Draught", { ingredientIds })
	"Fuse", -- (guardianUid, { ingredientIds })
	"Buy", -- (shopItemId)
	"Release", -- (guardianUid)
	"BuyLuck", -- ()
	"RequestState", -- () client is ready for its first snapshot
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	local existing = script.Parent:FindFirstChild("RemoteEvents")
	if existing then
		folder = existing :: Folder
	else
		local created = Instance.new("Folder")
		created.Name = "RemoteEvents"
		created.Parent = script.Parent
		folder = created
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = script.Parent:WaitForChild("RemoteEvents") :: Folder
end

for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
