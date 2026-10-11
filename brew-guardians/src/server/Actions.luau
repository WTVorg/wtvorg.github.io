-- Handles every request from the client. The client only asks; all checks,
-- rolls and inventory changes happen here.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuardianService = require(script.Parent.GuardianService)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local WorldBuilder = require(script.Parent.WorldBuilder)

local POT_RANGE = 16

local Actions = {}

local rng = Random.new()
local lastThrow: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function luckFor(data): number
	if data.LuckUntil and data.LuckUntil > os.time() then
		return Config.Monetization.LuckBoostMultiplier
	end
	return 1
end

local function journalEntry(data, guardianId: string)
	local entry = data.Journal[guardianId]
	if not entry then
		entry = { Seen = true, Caught = 0, FavoriteKnown = false, Tried = {} }
		data.Journal[guardianId] = entry
	end
	return entry
end

-- Validates a list of ingredient ids from the client and returns the counts
-- needed, or nil if the player does not own them.
local function ingredientCost(data, list: any, expected: number): { [string]: number }?
	if type(list) ~= "table" or #list ~= expected then
		return nil
	end
	local need = {}
	for i = 1, expected do
		local id = list[i]
		if type(id) ~= "string" or not Config.Ingredients[id] then
			return nil
		end
		need[id] = (need[id] or 0) + 1
	end
	for id, count in need do
		if (data.Ingredients[id] or 0) < count then
			return nil
		end
	end
	return need
end

local function spend(data, need: { [string]: number })
	for id, count in need do
		data.Ingredients[id] -= count
	end
end

local function findGuardianEntry(data, uid: any)
	if type(uid) ~= "string" then
		return nil, nil
	end
	for i, entry in data.Guardians do
		if entry.Uid == uid then
			return entry, i
		end
	end
	return nil, nil
end

----------------------------------------------------------------------
-- Throwing
----------------------------------------------------------------------
local function resolveFlask(player: Player, g, flask)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local chance = GuardianService.Chance(g, flask.Mult, luckFor(data))
	local shakes = CatchMath.Roll(chance, rng)
	local caught = shakes >= CatchMath.Shakes

	GuardianService.BeginCapture(g)
	Remotes.CaptureSequence:FireAllClients({
		Position = GuardianService.GroundPosition(g),
		Shakes = shakes,
		FlaskId = flask.Id,
		Color = flask.Color,
		GuardianId = g.Id,
		ThrowerUserId = player.UserId,
		Chance = chance,
	})

	task.wait(CatchMath.Duration(shakes))

	if caught and not player.Parent then
		caught = false -- thrower left mid-shake, let it go
	end
	GuardianService.EndCapture(g, caught)

	local pct = math.floor(chance * 100 + 0.5)
	if caught then
		local entry = { Uid = PlayerData.NewUid(), Id = g.Id, Mutation = 0, CaughtAt = os.time() }
		PlayerData.Update(player, function(d)
			table.insert(d.Guardians, entry)
			local j = journalEntry(d, g.Id)
			j.Caught += 1
			d.Stats.Catches += 1
			return true
		end)
		Plots.Refresh(player)
		notify(player, string.format("Gotcha! %s was caught! (%d%% chance)", g.Def.Name, pct), "catch")
		local rarity = Config.Rarities[g.Def.Rarity]
		if rarity.Order >= 3 then
			Remotes.Announce:FireAllClients(string.format("%s caught a %s %s!", player.DisplayName, g.Def.Rarity, g.Def.Name))
		end
	else
		if shakes == CatchMath.Shakes - 1 then
			PlayerData.Update(player, function(d)
				d.Stats.NearMisses += 1
				return true
			end)
			notify(player, string.format("Argh! It broke out on the last shake! (%d%% chance)", pct), "nearmiss")
		else
			notify(player, string.format("%s burst free and it's furious! (%d%% chance)", g.Def.Name, pct), "fail")
		end
	end
end

local function onThrow(player: Player, kind: any, tierId: any, model: any)
	if kind ~= "Flask" and kind ~= "Draught" then
		return
	end
	if type(tierId) ~= "string" then
		return
	end
	local item = if kind == "Flask" then Config.GetFlask(tierId) else Config.GetDraught(tierId)
	if not item then
		return
	end
	local data = PlayerData.Get(player)
	local root = rootOf(player)
	local g = GuardianService.FromModel(model)
	if not data or not root or not g then
		return
	end
	local t = os.clock()
	if lastThrow[player] and t - lastThrow[player] < Config.Catch.ThrowCooldown then
		return
	end
	if (root.Position - GuardianService.GroundPosition(g)).Magnitude > Config.Catch.ThrowRange then
		notify(player, "Too far away to throw.", "error")
		return
	end
	local bag = if kind == "Flask" then data.Flasks else data.Draughts
	if (bag[tierId] or 0) <= 0 then
		notify(player, "You don't have any " .. item.Name .. "s. Brew some at your cauldron!", "error")
		return
	end
	lastThrow[player] = t

	PlayerData.Update(player, function(d)
		bag[tierId] -= 1
		d.Stats.Throws += 1
		journalEntry(d, g.Id).Seen = true
		return true
	end)

	Remotes.ThrowVisual:FireAllClients(root.Position, model, item.Color, Config.Catch.FlightTime)
	task.wait(Config.Catch.FlightTime)

	g = GuardianService.FromModel(model)
	if not g then
		-- Someone else's flask got there first.
		PlayerData.Update(player, function()
			bag[tierId] += 1
			return true
		end)
		notify(player, "Missed! Your " .. item.Name .. " bounced back to you.", "info")
		return
	end

	if kind == "Draught" then
		GuardianService.ApplyDraught(g, item.Power, player)
	else
		resolveFlask(player, g, item)
	end
end

----------------------------------------------------------------------
-- Feeding
----------------------------------------------------------------------
local function onFeed(player: Player, model: any, ingredientId: any)
	if type(ingredientId) ~= "string" or not Config.Ingredients[ingredientId] then
		return
	end
	local data = PlayerData.Get(player)
	local root = rootOf(player)
	local g = GuardianService.FromModel(model)
	if not data or not root or not g then
		return
	end
	if (root.Position - GuardianService.GroundPosition(g)).Magnitude > Config.Catch.FeedRange + g.Def.Size then
		notify(player, "Get closer to feed it.", "error")
		return
	end
	if (data.Ingredients[ingredientId] or 0) <= 0 then
		notify(player, "You're out of " .. Config.Ingredients[ingredientId].Name .. ".", "error")
		return
	end
	if g.FedFavorite then
		notify(player, g.Def.Name .. " is already happily munching.", "info")
		return
	end

	local isFavorite = g.Def.Favorite == ingredientId
	PlayerData.Update(player, function(d)
		d.Ingredients[ingredientId] -= 1
		local j = journalEntry(d, g.Id)
		j.Tried[ingredientId] = true
		if isFavorite then
			j.FavoriteKnown = true
		end
		return true
	end)
	GuardianService.Feed(g, isFavorite)

	local ingredientName = Config.Ingredients[ingredientId].Name
	if isFavorite then
		GuardianService.Celebrate(g, Color3.fromRGB(255, 120, 200))
		notify(
			player,
			string.format("%s loves the %s! It calms down. Catch odds x%d!", g.Def.Name, ingredientName, Config.Catch.FavoriteMult),
			"favorite"
		)
	else
		notify(player, string.format("%s sniffs the %s and turns away.", g.Def.Name, ingredientName), "info")
	end
end

----------------------------------------------------------------------
-- Brewing and fusing
----------------------------------------------------------------------
local function onBrew(player: Player, mode: any, list: any)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if mode ~= "Flask" and mode ~= "Draught" then
		return
	end
	local brew = Plots.NearbyBrew(player, POT_RANGE)
	if not brew then
		notify(player, "Stand next to a cauldron to brew.", "error")
		return
	end
	local count = if mode == "Flask" then Config.FlaskIngredientCount else Config.DraughtIngredientCount
	local need = ingredientCost(data, list, count)
	if not need then
		notify(player, "You don't have those ingredients.", "error")
		return
	end
	if data.Vials <= 0 then
		notify(player, "You need an Empty Vial. Buy them at the shop in the hub.", "error")
		return
	end

	local quality = Config.QualityOf(list, data.PotLevel)
	local result = if mode == "Flask" then Config.FlaskForQuality(quality) else Config.DraughtForQuality(quality)
	PlayerData.Update(player, function(d)
		spend(d, need)
		d.Vials -= 1
		local bag = if mode == "Flask" then d.Flasks else d.Draughts
		bag[result.Id] = (bag[result.Id] or 0) + 1
		d.Stats.Brews += 1
		return true
	end)
	Plots.BrewEffect(brew, result.Color)
	notify(player, string.format("Brewed a %s! (quality %d)", result.Name, quality), "brew")
end

local function onFuse(player: Player, uid: any, list: any)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local brew = Plots.NearbyBrew(player, POT_RANGE)
	if not brew then
		notify(player, "Stand next to a cauldron to fuse.", "error")
		return
	end
	local entry = findGuardianEntry(data, uid)
	if not entry then
		return
	end
	local nextLevel = (entry.Mutation or 0) + 1
	local mutation = Config.Mutations[nextLevel]
	if not mutation then
		notify(player, "This guardian can't grow any bigger.", "error")
		return
	end
	local need = ingredientCost(data, list, Config.FlaskIngredientCount)
	if not need then
		notify(player, "You don't have those ingredients.", "error")
		return
	end
	local quality = Config.QualityOf(list, data.PotLevel)
	if quality < mutation.MinQuality then
		notify(player, string.format("Needs brew quality %d to become %s (you have %d).", mutation.MinQuality, mutation.Prefix, quality), "error")
		return
	end
	PlayerData.Update(player, function(d)
		spend(d, need)
		entry.Mutation = nextLevel
		return true
	end)
	Plots.Refresh(player)
	Plots.BrewEffect(brew, Color3.fromRGB(255, 80, 200))
	notify(player, string.format("It grew into a %s!", Config.GuardianDisplayName(entry)), "catch")
end

----------------------------------------------------------------------
-- Shop and collection
----------------------------------------------------------------------
local function onBuy(player: Player, itemId: any)
	if type(itemId) ~= "string" then
		return
	end
	local item = Config.GetShopItem(itemId)
	local data = PlayerData.Get(player)
	if not item or not data then
		return
	end
	if item.PotLevel and data.PotLevel ~= item.PotLevel - 1 then
		notify(player, if data.PotLevel >= item.PotLevel then "You already own that." else "Buy the previous cauldron first.", "error")
		return
	end
	if data.Coins < item.Price then
		notify(player, "Not enough coins.", "error")
		return
	end
	PlayerData.Update(player, function(d)
		d.Coins -= item.Price
		if item.PotLevel then
			d.PotLevel = item.PotLevel
		else
			d.Vials += item.Amount
		end
		return true
	end)
	notify(player, "Bought " .. item.Name .. "!", "coins")
end

local function onRelease(player: Player, uid: any)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local entry, index = findGuardianEntry(data, uid)
	if not entry or not index then
		return
	end
	local value = math.floor(Config.GuardianIncome(entry) * Config.ReleaseValueSeconds)
	PlayerData.Update(player, function(d)
		table.remove(d.Guardians, index)
		d.Coins += value
		return true
	end)
	Plots.Refresh(player)
	notify(player, string.format("Released %s. +%d coins", Config.GuardianDisplayName(entry), value), "coins")
end

----------------------------------------------------------------------
-- Robux luck boost (a boost, never a random item)
----------------------------------------------------------------------
local function onBuyLuck(player: Player)
	local id = Config.Monetization.LuckBoostProductId
	if id == 0 then
		notify(player, "Lucky Brew isn't on sale yet.", "info")
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and PlayerData.Get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if data.Purchases[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if receipt.ProductId ~= Config.Monetization.LuckBoostProductId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerData.Update(player, function(d)
		local start = math.max(d.LuckUntil or 0, os.time())
		d.LuckUntil = start + Config.Monetization.LuckBoostMinutes * 60
		d.Purchases[receipt.PurchaseId] = true
		return true
	end)
	PlayerData.Save(player)
	notify(player, "Lucky Brew active! Catch odds boosted.", "favorite")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

----------------------------------------------------------------------
-- Journal: mark guardians as seen when you get close
----------------------------------------------------------------------
local function seenLoop()
	while true do
		task.wait(2)
		local wild = GuardianService.All()
		for _, player in Players:GetPlayers() do
			local data = PlayerData.Get(player)
			local root = rootOf(player)
			if data and root then
				local changed = false
				for _, g in wild do
					if not data.Journal[g.Id] and (root.Position - g.Position).Magnitude < 50 then
						journalEntry(data, g.Id)
						changed = true
						notify(player, "New guardian spotted: " .. g.Def.Name .. "! (added to your Journal)", "info")
					end
				end
				if changed then
					PlayerData.Push(player)
				end
			end
		end
	end
end

function Actions.Start()
	Remotes.Throw.OnServerEvent:Connect(onThrow)
	Remotes.Feed.OnServerEvent:Connect(onFeed)
	Remotes.Brew.OnServerEvent:Connect(onBrew)
	Remotes.Fuse.OnServerEvent:Connect(onFuse)
	Remotes.Buy.OnServerEvent:Connect(onBuy)
	Remotes.Release.OnServerEvent:Connect(onRelease)
	Remotes.BuyLuck.OnServerEvent:Connect(onBuyLuck)
	MarketplaceService.ProcessReceipt = processReceipt

	local publicPrompt = WorldBuilder.PublicBrewPrompt
	if publicPrompt then
		publicPrompt.Triggered:Connect(function(player)
			Remotes.OpenUI:FireClient(player, "Brew")
		end)
	end

	local shopPrompt = WorldBuilder.ShopPrompt
	if shopPrompt then
		shopPrompt.Triggered:Connect(function(player)
			Remotes.OpenUI:FireClient(player, "Shop")
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)

	task.spawn(seenLoop)
end

return Actions
