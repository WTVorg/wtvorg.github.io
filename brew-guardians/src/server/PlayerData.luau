-- Loads, caches and saves each player's data with DataStoreService.
-- Every change goes through PlayerData.Update so the client always gets a
-- fresh snapshot.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STORE_NAME = "BrewGuardians_v1"
local AUTOSAVE_SECONDS = 120
local RETRIES = 4

local PlayerData = {}

local store: DataStore? = nil
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local cache: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}
local loadedSignal = Instance.new("BindableEvent")
PlayerData.Loaded = loadedSignal.Event -- (player, data)

local function deepCopy(t)
	local out = {}
	for k, v in t do
		out[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return out
end

local function template()
	local data = {
		Version = 1,
		Coins = Config.StartingData.Coins,
		Vials = Config.StartingData.Vials,
		PotLevel = 1,
		Flasks = {},
		Draughts = {},
		Ingredients = {},
		Guardians = {}, -- array of { Uid, Id, Mutation, CaughtAt }
		Journal = {}, -- [guardianId] = { Seen, Caught, FavoriteKnown, Tried = {} }
		PendingCoins = 0,
		LuckUntil = 0,
		Purchases = {},
		Stats = { Throws = 0, Catches = 0, NearMisses = 0, Brews = 0 },
	}
	for _, f in Config.Flasks do
		data.Flasks[f.Id] = Config.StartingData.Flasks[f.Id] or 0
	end
	for _, d in Config.Draughts do
		data.Draughts[d.Id] = 0
	end
	for _, id in Config.IngredientOrder do
		data.Ingredients[id] = Config.StartingData.Ingredients[id] or 0
	end
	return data
end

-- Fill in any keys a newer version of the game added.
local function reconcile(data, base)
	for k, v in base do
		if data[k] == nil then
			data[k] = if type(v) == "table" then deepCopy(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(data[k], v)
		end
	end
	return data
end

local function withRetries(fn)
	local lastErr
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		-- No point retrying when Studio simply has API access turned off.
		local message = tostring(result)
		if message:find("StudioAccessToApisNotAllowed") or message:find("403") then
			break
		end
		task.wait(attempt)
	end
	return false, lastErr
end

local function keyFor(player: Player)
	return "p_" .. player.UserId
end

function PlayerData.Push(player: Player)
	local data = cache[player]
	if data then
		Remotes.StateUpdate:FireClient(player, data)
	end
end

function PlayerData.Get(player: Player)
	return cache[player]
end

function PlayerData.WaitFor(player: Player)
	while player.Parent and not cache[player] do
		task.wait(0.1)
	end
	return cache[player]
end

-- fn mutates data in place. Return false from fn to signal "no change".
function PlayerData.Update(player: Player, fn: (any) -> boolean?)
	local data = cache[player]
	if not data then
		return false
	end
	local result = fn(data)
	if result ~= false then
		PlayerData.Push(player)
	end
	return result ~= false
end

function PlayerData.NewUid(): string
	return HttpService:GenerateGUID(false)
end

function PlayerData.Save(player: Player)
	local data = cache[player]
	local activeStore = store
	if not data or not canSave[player] or not activeStore then
		return
	end
	local ok, err = withRetries(function()
		activeStore:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[PlayerData] save failed for", player.Name, err)
	end
end

local function load(player: Player)
	local data
	local activeStore = store
	if activeStore then
		local ok, result = withRetries(function()
			return activeStore:GetAsync(keyFor(player))
		end)
		if ok then
			data = result
			canSave[player] = true
		else
			-- Never overwrite a save we failed to read.
			warn("[PlayerData] load failed, this session will not save:", result)
			canSave[player] = false
		end
	else
		canSave[player] = false
	end

	if not player.Parent then
		return
	end

	data = reconcile(data or template(), template())
	cache[player] = data

	if not canSave[player] and RunService:IsStudio() then
		Remotes.Notify:FireClient(
			player,
			"Studio: enable API access to DataStores (Game Settings > Security) to keep progress.",
			"info"
		)
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local caught = Instance.new("IntValue")
	caught.Name = "Caught"
	caught.Parent = leaderstats
	leaderstats.Parent = player

	PlayerData.Push(player)
	loadedSignal:Fire(player, data)
end

local function syncLeaderstats()
	for player, data in cache do
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			(stats :: any).Coins.Value = math.floor(data.Coins);
			(stats :: any).Caught.Value = #data.Guardians
		end
	end
end

function PlayerData.Start()
	if not storeOk then
		warn("[PlayerData] DataStoreService unavailable, progress will not save")
	end

	Remotes.RequestState.OnServerEvent:Connect(PlayerData.Push)

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerData.Save(player)
		cache[player] = nil
		canSave[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player in cache do
			pending += 1
			task.spawn(function()
				PlayerData.Save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in cache do
				task.spawn(PlayerData.Save, player)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			syncLeaderstats()
		end
	end)
end

return PlayerData
