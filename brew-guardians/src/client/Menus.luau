-- Pop-up windows: Brew (flasks, draughts, fusion), Shop, Journal,
-- Collection and Help. Only one is open at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local T = UI.Theme

local Menus = {}

local gui: ScreenGui
local window: Frame
local titleLabel: TextLabel
local body: Frame
local current: string? = nil
local renderers: { [string]: (Frame) -> () } = {}

-- Brew window state
local brewMode = "Flask" -- "Flask" | "Draught" | "Fuse"
local slots: { string } = {}
local fuseUid: string? = nil
local releaseConfirm: string? = nil

local function slotCount(): number
	return if brewMode == "Draught" then Config.DraughtIngredientCount else Config.FlaskIngredientCount
end

local function usedCount(id: string): number
	local n = 0
	for _, s in slots do
		if s == id then
			n += 1
		end
	end
	return n
end

local function rerender()
	if current and renderers[current] then
		UI.clear(body)
		renderers[current](body)
	end
end

function Menus.Open(name: string)
	if current == name and window.Visible then
		Menus.Close()
		return
	end
	current = name
	titleLabel.Text = name
	window.Visible = true
	releaseConfirm = nil
	rerender()
end

function Menus.Close()
	current = nil
	window.Visible = false
	slots = {}
	fuseUid = nil
end

----------------------------------------------------------------------
-- Shared bits
----------------------------------------------------------------------
local function section(parent: Instance, text: string, order: number)
	return UI.text({
		Text = text,
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function row(parent: Instance, height: number, order: number): Frame
	local f = UI.make("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local layout = UI.list(f, 6, true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

local function grid(parent: Instance, cell: Vector2, order: number): Frame
	local f = UI.make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = f,
	})
	return f
end

local function card(parent: Instance, height: number, order: number, stroke: Color3?): Frame
	local f = UI.make("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = T.PanelLight,
		Corner = 8,
		LayoutOrder = order,
		Parent = parent,
	})
	if stroke then
		UI.make("UIStroke", { Color = stroke, Thickness = 2, Parent = f })
	end
	UI.padding(f, 8)
	return f
end

----------------------------------------------------------------------
-- Brew
----------------------------------------------------------------------
local function ingredientPicker(parent: Instance, order: number)
	local data = State.Data
	section(parent, "Your ingredients (tap to add)", order)
	local g = grid(parent, Vector2.new(150, 44), order + 1)
	local any = false
	for i, id in Config.IngredientOrder do
		local def = Config.Ingredients[id]
		local owned = data.Ingredients[id] or 0
		local free = owned - usedCount(id)
		if owned > 0 then
			any = true
			UI.button({
				Text = string.format("%s  T%d  x%d", def.Name, def.Tier, free),
				LayoutOrder = i,
				BackgroundColor3 = def.Color:Lerp(T.Panel, 0.45),
				BackgroundTransparency = if free > 0 then 0 else 0.6,
				Font = T.Body,
			}, function()
				if free > 0 and #slots < slotCount() then
					table.insert(slots, id)
					rerender()
				end
			end).Parent = g
		end
	end
	if not any then
		UI.text({ Text = "Nothing yet. Harvest glowing plants in the zones.", Size = UDim2.new(1, 0, 0, 28), Font = T.Body, LayoutOrder = order + 2, Parent = parent })
	end
end

local function slotRow(parent: Instance, order: number)
	local r = row(parent, 56, order)
	for i = 1, slotCount() do
		local id = slots[i]
		local def = id and Config.Ingredients[id]
		UI.button({
			Text = if def then def.Name else "empty",
			LayoutOrder = i,
			Size = UDim2.fromOffset(130, 50),
			BackgroundColor3 = if def then def.Color:Lerp(T.Panel, 0.3) else T.Slot,
			TextColor3 = if def then T.Text else T.Muted,
		}, function()
			if slots[i] then
				table.remove(slots, i)
				rerender()
			end
		end).Parent = r
	end
end

local function renderBrew(parent: Frame)
	local data = State.Data
	if not data then
		return
	end

	local tabs = row(parent, 40, 1)
	for i, mode in { "Flask", "Draught", "Fuse" } do
		UI.button({
			Text = if mode == "Flask" then "Capture Flask" elseif mode == "Draught" then "Weakening Draught" else "Fuse Guardian",
			LayoutOrder = i,
			Size = UDim2.fromOffset(170, 36),
			BackgroundColor3 = if brewMode == mode then T.Accent else T.Slot,
		}, function()
			brewMode = mode
			slots = {}
			rerender()
		end).Parent = tabs
	end

	local quality = Config.QualityOf(slots, data.PotLevel)
	local potBonus = data.PotLevel - 1

	if brewMode == "Fuse" then
		section(parent, "1. Pick a guardian to grow", 2)
		local list = grid(parent, Vector2.new(190, 44), 3)
		if #data.Guardians == 0 then
			UI.text({ Text = "Catch a guardian first!", Size = UDim2.new(1, 0, 0, 28), Font = T.Body, LayoutOrder = 3, Parent = parent })
		end
		for i, entry in data.Guardians do
			local maxed = (entry.Mutation or 0) >= #Config.Mutations
			UI.button({
				Text = Config.GuardianDisplayName(entry) .. (if maxed then " (max)" else ""),
				LayoutOrder = i,
				BackgroundColor3 = if fuseUid == entry.Uid then T.Accent else T.Slot,
				Font = T.Body,
			}, function()
				if not maxed then
					fuseUid = entry.Uid
					rerender()
				end
			end).Parent = list
		end

		local selected = nil
		for _, entry in data.Guardians do
			if entry.Uid == fuseUid then
				selected = entry
			end
		end
		section(parent, "2. Add 3 ingredients (quality decides if it grows)", 4)
		slotRow(parent, 5)
		local nextMutation = selected and Config.Mutations[(selected.Mutation or 0) + 1]
		local info = if not selected
			then "Select a guardian above."
			elseif not nextMutation then "Already at its biggest form."
			else string.format(
				"Quality %d / %d needed → %s (income x%g)",
				quality,
				nextMutation.MinQuality,
				nextMutation.Prefix,
				nextMutation.IncomeMult
			)
		UI.text({ Text = info, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 6, Font = T.Body, Parent = parent })
		local ready = selected and nextMutation and #slots == Config.FlaskIngredientCount and quality >= nextMutation.MinQuality
		local actions = row(parent, 46, 7)
		UI.button({
			Text = "Fuse!",
			Size = UDim2.fromOffset(160, 42),
			BackgroundColor3 = if ready then Color3.fromRGB(230, 80, 180) else T.Slot,
		}, function()
			if ready then
				Remotes.Fuse:FireServer(fuseUid, slots)
				slots = {}
			end
		end).Parent = actions
		ingredientPicker(parent, 8)
		return
	end

	local needed = slotCount()
	local isFlask = brewMode == "Flask"
	section(
		parent,
		string.format("Add %d ingredients. Quality = sum of tiers%s.", needed, if potBonus > 0 then string.format(" +%d cauldron", potBonus) else ""),
		2
	)
	slotRow(parent, 3)

	local result = if isFlask then Config.FlaskForQuality(quality) else Config.DraughtForQuality(quality)
	local list = if isFlask then Config.Flasks else Config.Draughts
	local nextTier = nil
	for _, entry in list do
		if entry.MinQuality > quality then
			nextTier = entry
			break
		end
	end
	local resultText = if isFlask
		then string.format("Quality %d → %s (catch x%g)", quality, result.Name, result.Mult)
		else string.format("Quality %d → %s (-%d resistance, slows)", quality, result.Name, result.Power)
	UI.text({ Text = resultText, Size = UDim2.new(1, 0, 0, 30), TextColor3 = result.Color, LayoutOrder = 4, Parent = parent })
	if nextTier then
		UI.text({
			Text = string.format("Reach quality %d for a %s", nextTier.MinQuality, nextTier.Name),
			Size = UDim2.new(1, 0, 0, 22),
			TextColor3 = T.Muted,
			Font = T.Body,
			LayoutOrder = 5,
			Parent = parent,
		})
	end

	local actions = row(parent, 46, 6)
	local ready = #slots == needed and data.Vials > 0
	UI.button({
		Text = "Brew!",
		Size = UDim2.fromOffset(160, 42),
		BackgroundColor3 = if ready then T.Good else T.Slot,
	}, function()
		if ready then
			Remotes.Brew:FireServer(brewMode, slots)
			slots = {}
		end
	end).Parent = actions
	UI.text({
		Text = string.format("Uses 1 vial (you have %d)", data.Vials),
		Size = UDim2.fromOffset(240, 30),
		TextColor3 = if data.Vials > 0 then T.Muted else T.Bad,
		Font = T.Body,
		Parent = actions,
	})

	ingredientPicker(parent, 7)
end

----------------------------------------------------------------------
-- Shop
----------------------------------------------------------------------
local function renderShop(parent: Frame)
	local data = State.Data
	if not data then
		return
	end
	section(parent, "Flasks can't be bought. Brew them at your cauldron!", 0)
	for i, item in Config.Shop do
		local owned = item.PotLevel and data.PotLevel >= item.PotLevel
		local locked = item.PotLevel and data.PotLevel < item.PotLevel - 1
		local c = card(parent, 64, i)
		UI.text({ Text = item.Name, Size = UDim2.new(0.6, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
		UI.text({
			Text = item.Description,
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(0.65, 0, 0, 20),
			TextColor3 = T.Muted,
			Font = T.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = c,
		})
		local affordable = data.Coins >= item.Price
		UI.button({
			Text = if owned then "Owned" elseif locked then "Locked" else UI.formatNumber(item.Price) .. " coins",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(150, 40),
			BackgroundColor3 = if owned or locked or not affordable then T.Slot else T.Gold:Lerp(T.Panel, 0.2),
			Parent = c,
		}, function()
			if not owned and not locked then
				Remotes.Buy:FireServer(item.Id)
			end
		end)
	end

	if Config.Monetization.LuckBoostProductId ~= 0 then
		local c = card(parent, 64, 100, Color3.fromRGB(120, 255, 160))
		UI.text({
			Text = string.format("Lucky Brew (%d min)", Config.Monetization.LuckBoostMinutes),
			Size = UDim2.new(0.6, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = c,
		})
		UI.text({
			Text = string.format("All catch odds x%g while active.", Config.Monetization.LuckBoostMultiplier),
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(0.65, 0, 0, 20),
			TextColor3 = T.Muted,
			Font = T.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = c,
		})
		UI.button({
			Text = "Robux",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(150, 40),
			BackgroundColor3 = Color3.fromRGB(60, 170, 90),
			Parent = c,
		}, function()
			Remotes.BuyLuck:FireServer()
		end)
	end
end

----------------------------------------------------------------------
-- Journal
----------------------------------------------------------------------
local function renderJournal(parent: Frame)
	local data = State.Data
	if not data then
		return
	end
	local seenCount, caughtCount = 0, 0
	for _, id in Config.GuardianOrder do
		local j = data.Journal[id]
		if j then
			seenCount += 1
			if (j.Caught or 0) > 0 then
				caughtCount += 1
			end
		end
	end
	section(parent, string.format("Seen %d / %d   Caught %d / %d", seenCount, #Config.GuardianOrder, caughtCount, #Config.GuardianOrder), 0)

	for i, id in Config.GuardianOrder do
		local def = Config.Guardians[id]
		local j = data.Journal[id]
		local rarity = Config.Rarities[def.Rarity]
		local c = card(parent, if j then 116 else 70, i, if j then rarity.Color else T.Slot)
		if not j then
			UI.text({ Text = "???", Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, Parent = c })
			UI.text({
				Text = "Not seen yet. Somewhere in " .. Config.Zones[def.Zone].Name .. ".",
				Position = UDim2.fromOffset(0, 30),
				Size = UDim2.new(1, 0, 0, 20),
				TextColor3 = T.Muted,
				Font = T.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = c,
			})
			continue
		end
		UI.text({
			Text = string.format("%s   ·   %s %s", def.Name, def.Rarity, def.Element),
			Size = UDim2.new(1, 0, 0, 26),
			TextColor3 = rarity.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = c,
		})
		local favorite = if j.FavoriteKnown then Config.Ingredients[def.Favorite].Name else "Unknown. Feed it to find out!"
		local tried = {}
		for ingredientId in j.Tried or {} do
			if ingredientId ~= def.Favorite then
				table.insert(tried, Config.Ingredients[ingredientId] and Config.Ingredients[ingredientId].Name or ingredientId)
			end
		end
		local lines = {
			string.format("Hint: %s", def.Hint),
			string.format("Favorite: %s%s", favorite, if #tried > 0 then "   (not: " .. table.concat(tried, ", ") .. ")" else ""),
			string.format("Zone: %s   Caught: %d   Base catch rate: %d%%   Earns %d/s", Config.Zones[def.Zone].Name, j.Caught or 0, math.floor(def.BaseRate * 100), def.Income),
		}
		for k, line in lines do
			UI.text({
				Text = line,
				Position = UDim2.fromOffset(0, 6 + k * 22),
				Size = UDim2.new(1, 0, 0, 20),
				TextColor3 = if k == 2 and j.FavoriteKnown then Color3.fromRGB(255, 150, 215) else T.Text,
				Font = T.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = c,
			})
		end
	end
end

----------------------------------------------------------------------
-- Collection
----------------------------------------------------------------------
local function renderCollection(parent: Frame)
	local data = State.Data
	if not data then
		return
	end
	local total = 0
	for _, entry in data.Guardians do
		total += Config.GuardianIncome(entry)
	end
	section(
		parent,
		string.format("%d guardians · %s coins/s · the best %d live on your plot", #data.Guardians, UI.formatNumber(total), Config.MaxPlotDisplays),
		0
	)

	local list = table.clone(data.Guardians)
	table.sort(list, function(a, b)
		return Config.GuardianIncome(a) > Config.GuardianIncome(b)
	end)
	for i, entry in list do
		local def = Config.Guardians[entry.Id]
		if not def then
			continue
		end
		local c = card(parent, 54, i, Config.Rarities[def.Rarity].Color)
		UI.text({
			Text = Config.GuardianDisplayName(entry),
			Size = UDim2.new(0.5, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = c,
		})
		UI.text({
			Text = string.format("%s · %s coins/s", def.Rarity, UI.formatNumber(Config.GuardianIncome(entry))),
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(0.5, 0, 0, 18),
			TextColor3 = T.Muted,
			Font = T.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = c,
		})
		local value = math.floor(Config.GuardianIncome(entry) * Config.ReleaseValueSeconds)
		local confirming = releaseConfirm == entry.Uid
		UI.button({
			Text = if confirming then "Sure? Tap again" else "Release +" .. UI.formatNumber(value),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(170, 36),
			BackgroundColor3 = if confirming then T.Bad else T.Slot,
			Parent = c,
		}, function()
			if confirming then
				releaseConfirm = nil
				Remotes.Release:FireServer(entry.Uid)
			else
				releaseConfirm = entry.Uid
				rerender()
			end
		end)
	end
	if #list == 0 then
		UI.text({ Text = "No guardians yet. Go catch one!", Size = UDim2.new(1, 0, 0, 30), Font = T.Body, LayoutOrder = 1, Parent = parent })
	end
end

----------------------------------------------------------------------
-- Help
----------------------------------------------------------------------
local HELP = {
	"1. Harvest glowing plants in the three zones for ingredients.",
	"2. At the cauldron on your plot, brew 3 ingredients into a Capture Flask. Better ingredients make a stronger flask. Each brew needs an Empty Vial from the hub shop.",
	"3. Wear a guardian down before you throw: dodge its red attacks, lure it into hazards (brambles, lava, ice spikes), or hit it with a Weakening Draught.",
	"4. Every guardian loves one ingredient. Pick Feed on the action bar and tap it. If you guessed right, your odds double and it calms down.",
	"5. Select a flask and tap the guardian (or press F for the nearest one). Watch the shakes...",
	"6. Caught guardians live on your plot and earn coins. Collect them at the gold pad, and fuse guardians at your cauldron to grow giant mutated forms.",
}

local function renderHelp(parent: Frame)
	for i, line in HELP do
		UI.text({
			Text = line,
			Size = UDim2.new(1, 0, 0, 48),
			TextWrapped = true,
			TextScaled = false,
			TextSize = 18,
			Font = T.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
			Parent = parent,
		})
	end
end

----------------------------------------------------------------------
function Menus.Init()
	gui = UI.screen()
	window = UI.make("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(680, 540),
		BackgroundColor3 = T.Panel,
		Corner = 14,
		Stroke = T.Accent,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	titleLabel = UI.text({ Text = "", Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -80, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, Parent = window })
	UI.button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = T.Bad,
		Parent = window,
	}, Menus.Close)

	local scroll = UI.make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 54),
		Size = UDim2.new(1, -24, 1, -66),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = window,
	})
	body = UI.make("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = scroll,
	})
	local layout = UI.list(body, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	renderers.Brew = renderBrew
	renderers.Shop = renderShop
	renderers.Journal = renderJournal
	renderers.Collection = renderCollection
	renderers.Help = renderHelp

	State.Changed:Connect(function()
		-- Drop slot picks the player can no longer afford.
		local data = State.Data
		if data then
			local counts = {}
			local kept = {}
			for _, id in slots do
				counts[id] = (counts[id] or 0) + 1
				if counts[id] <= (data.Ingredients[id] or 0) then
					table.insert(kept, id)
				end
			end
			slots = kept
		end
		rerender()
	end)
end

return Menus
