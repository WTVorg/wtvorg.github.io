-- Pop-up windows: Brew (flasks, draughts, fusion), Shop, Journal,
-- Collection and Help. Only one is open at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local T = UI.Theme

local Menus = {}

local gui: ScreenGui
local window: Frame
local windowScale: UIScale
local titleLabel: TextLabel
local header: Frame
local body: Frame
local current: string? = nil
local renderers: { [string]: (Frame) -> () } = {}

local TITLES = {
	Brew = { "Cauldron", Color3.fromRGB(90, 200, 120) },
	Shop = { "Shop", Color3.fromRGB(240, 110, 130) },
	Journal = { "Guardian Journal", Color3.fromRGB(80, 160, 255) },
	Collection = { "Your Guardians", Color3.fromRGB(255, 150, 60) },
	Help = { "How to Play", Color3.fromRGB(120, 200, 110) },
}

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
	local info = TITLES[name] or { name, T.Accent }
	titleLabel.Text = info[1]
	local top = header:FindFirstChildOfClass("UIGradient")
	local bottom = header:FindFirstChild("HeaderBottom")
	local bottomGradient = bottom and bottom:FindFirstChildOfClass("UIGradient")
	if top and bottomGradient then
		top.Color = ColorSequence.new(UI.lighten(info[2], 0.15), UI.darken(info[2], 0.15))
		bottomGradient.Color = ColorSequence.new(UI.darken(info[2], 0.1), UI.darken(info[2], 0.15))
	end
	releaseConfirm = nil
	if not window.Visible then
		window.Visible = true
		windowScale.Scale = 0.85
		TweenService:Create(windowScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	rerender()
end

function Menus.Close()
	current = nil
	window.Visible = false
	slots = {}
	fuseUid = nil
end

----------------------------------------------------------------------
-- Layout helpers
----------------------------------------------------------------------
local function section(parent: Instance, text: string, order: number)
	return UI.text({
		Text = text,
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function row(parent: Instance, height: number, order: number, align: Enum.HorizontalAlignment?): Frame
	local f = UI.make("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local layout = UI.list(f, 10, true)
	layout.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
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
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = f,
	})
	return f
end

local function card(parent: Instance, height: number, order: number, accent: Color3?): Frame
	local c = UI.panel({
		Size = UDim2.new(1, 0, 0, height),
		Color = T.PanelLight,
		Corner = 12,
		LayoutOrder = order,
		Parent = parent,
	})
	if accent then
		-- UIPadding applies to every child, so pull the stripe back into the margin
		UI.make("Frame", {
			Size = UDim2.new(0, 6, 1, 0),
			Position = UDim2.fromOffset(-14, 0),
			BackgroundColor3 = accent,
			Corner = 3,
			Parent = c,
		})
	end
	UI.make("UIPadding", { PaddingLeft = UDim.new(0, if accent then 20 else 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = c })
	return c
end

local function stars(tier: number): string
	return string.rep("★", tier) .. string.rep("☆", 4 - tier)
end

----------------------------------------------------------------------
-- Brew
----------------------------------------------------------------------
local function autoFill()
	-- Best ingredients first, respecting what you own.
	local data = State.Data
	local order = table.clone(Config.IngredientOrder)
	table.sort(order, function(a, b)
		return Config.Ingredients[a].Tier > Config.Ingredients[b].Tier
	end)
	slots = {}
	for _, id in order do
		local owned = data.Ingredients[id] or 0
		while owned > 0 and #slots < slotCount() do
			table.insert(slots, id)
			owned -= 1
		end
	end
	rerender()
end

local function ingredientPicker(parent: Instance, order: number)
	local data = State.Data
	section(parent, "Your ingredients - tap to add", order)
	local g = grid(parent, Vector2.new(196, 58), order + 1)
	local any = false
	for i, id in Config.IngredientOrder do
		local def = Config.Ingredients[id]
		local owned = data.Ingredients[id] or 0
		local free = owned - usedCount(id)
		if owned > 0 then
			any = true
			local b = UI.button({ Text = "", LayoutOrder = i, Color = if free > 0 then T.Slot else T.PanelDark, Corner = 12 }, function()
				if free > 0 and #slots < slotCount() then
					table.insert(slots, id)
					rerender()
				end
			end)
			UI.orbIcon(b, def.Color, 38, { Position = UDim2.fromOffset(0, 3) })
			UI.text({ Text = def.Name, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -46, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
			UI.text({ Text = stars(def.Tier), Position = UDim2.fromOffset(46, 24), Size = UDim2.new(1, -90, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Gold, Parent = b })
			UI.text({ Text = "x" .. free, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 24), Size = UDim2.fromOffset(44, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = b })
			b.Parent = g
		end
	end
	if not any then
		UI.text({ Text = "Nothing yet! Harvest glowing plants in the zones.", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order + 2, Parent = parent })
	end
end

local function slotRow(parent: Instance, order: number)
	local r = row(parent, 92, order, Enum.HorizontalAlignment.Center)
	for i = 1, slotCount() do
		local id = slots[i]
		local def = id and Config.Ingredients[id]
		local b = UI.button({ Text = "", LayoutOrder = i * 2, Size = UDim2.fromOffset(120, 88), Color = if def then T.Slot else T.PanelDark, Corner = 16 }, function()
			if slots[i] then
				table.remove(slots, i)
				rerender()
			end
		end)
		if def then
			UI.orbIcon(b, def.Color, 44, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0) })
			UI.text({ Text = def.Name, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 22), Parent = b })
		else
			UI.text({ Text = "+", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), TextColor3 = T.Muted, Parent = b })
		end
		b.Parent = r
		if i < slotCount() then
			UI.text({ Text = "+", LayoutOrder = i * 2 + 1, Size = UDim2.fromOffset(20, 30), TextColor3 = T.Muted, Parent = r })
		end
	end
end

local function renderBrew(parent: Frame)
	local data = State.Data
	if not data then
		return
	end

	local tabs = row(parent, 46, 1, Enum.HorizontalAlignment.Center)
	for i, mode in { "Flask", "Draught", "Fuse" } do
		local label = if mode == "Flask" then "Capture Flask" elseif mode == "Draught" then "Weakening Draught" else "Grow Guardian"
		UI.button({
			Text = label,
			LayoutOrder = i,
			Size = UDim2.fromOffset(200, 42),
			Color = if brewMode == mode then T.Accent else T.PanelLight,
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
		local list = grid(parent, Vector2.new(200, 46), 3)
		if #data.Guardians == 0 then
			UI.text({ Text = "Catch a guardian first!", Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 3, Parent = parent })
		end
		for i, entry in data.Guardians do
			local maxed = (entry.Mutation or 0) >= #Config.Mutations
			UI.button({
				Text = Config.GuardianDisplayName(entry) .. (if maxed then " (max)" else ""),
				LayoutOrder = i,
				Color = if fuseUid == entry.Uid then T.Accent elseif maxed then T.PanelDark else T.Slot,
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
		section(parent, "2. Add 3 ingredients - higher quality grows it bigger", 4)
		slotRow(parent, 5)
		local nextMutation = selected and Config.Mutations[(selected.Mutation or 0) + 1]
		local problem = if not selected
			then "Pick a guardian above"
			elseif not nextMutation then "Already at its biggest form"
			elseif #slots < Config.FlaskIngredientCount then string.format("Add %d more ingredient%s", Config.FlaskIngredientCount - #slots, if Config.FlaskIngredientCount - #slots == 1 then "" else "s")
			elseif quality < nextMutation.MinQuality then string.format("Quality %d - needs %d. Use better ingredients", quality, nextMutation.MinQuality)
			else nil
		local actions = row(parent, 56, 6, Enum.HorizontalAlignment.Center)
		UI.button({ Text = "Auto-fill", Size = UDim2.fromOffset(140, 50), Color = T.Blue }, autoFill).Parent = actions
		UI.button({
			Text = if problem then problem else string.format("Grow into %s!", nextMutation.Prefix),
			Size = UDim2.fromOffset(380, 50),
			Color = if problem then T.PanelLight else T.Pink,
		}, function()
			if not problem then
				Remotes.Fuse:FireServer(fuseUid, slots)
				slots = {}
			end
		end).Parent = actions
		ingredientPicker(parent, 8)
		return
	end

	local needed = slotCount()
	local isFlask = brewMode == "Flask"
	section(parent, string.format("Quality = ingredient stars added up%s", if potBonus > 0 then string.format(" (+%d from your cauldron)", potBonus) else ""), 2)
	slotRow(parent, 3)

	-- Result preview
	local result = if isFlask then Config.FlaskForQuality(quality) else Config.DraughtForQuality(quality)
	local list = if isFlask then Config.Flasks else Config.Draughts
	local nextTier = nil
	for _, entry in list do
		if entry.MinQuality > quality then
			nextTier = entry
			break
		end
	end
	local preview = card(parent, 76, 4, result.Color)
	UI.flaskIcon(preview, result.Color, 56, { Position = UDim2.fromOffset(0, 2) })
	UI.text({ Text = if #slots > 0 then result.Name else "Result", Position = UDim2.fromOffset(66, 2), Size = UDim2.new(1, -66, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.lighten(result.Color, 0.3), Parent = preview })
	local detail = if isFlask
		then string.format("Quality %d · catch power x%g", quality, result.Mult)
		else string.format("Quality %d · -%d resistance and slows it", quality, result.Power)
	if nextTier then
		detail ..= string.format("   (quality %d makes a %s)", nextTier.MinQuality, nextTier.Name)
	end
	UI.text({ Text = detail, Position = UDim2.fromOffset(66, 32), Size = UDim2.new(1, -66, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, Font = T.Body, Parent = preview })

	local problem = if #slots < needed
		then string.format("Add %d more ingredient%s", needed - #slots, if needed - #slots == 1 then "" else "s")
		elseif data.Vials <= 0 then "No vials! Buy them at the Shop"
		else nil
	local actions = row(parent, 56, 5, Enum.HorizontalAlignment.Center)
	UI.button({ Text = "Auto-fill", Size = UDim2.fromOffset(140, 50), Color = T.Blue }, autoFill).Parent = actions
	UI.button({
		Text = problem or "Brew it!",
		Size = UDim2.fromOffset(300, 50),
		Color = if problem then T.PanelLight else T.Good,
	}, function()
		if not problem then
			Remotes.Brew:FireServer(brewMode, slots)
			slots = {}
		end
	end).Parent = actions
	local vialInfo = UI.text({ Text = string.format("1 vial  (%d left)", data.Vials), Size = UDim2.fromOffset(150, 30), TextColor3 = if data.Vials > 0 then T.Muted else T.Bad, Parent = actions })
	vialInfo.LayoutOrder = 3

	ingredientPicker(parent, 6)
end

----------------------------------------------------------------------
-- Shop
----------------------------------------------------------------------
local function renderShop(parent: Frame)
	local data = State.Data
	if not data then
		return
	end
	section(parent, "Flasks can't be bought - brew them at a cauldron!", 0)
	for i, item in Config.Shop do
		local owned = item.PotLevel and data.PotLevel >= item.PotLevel
		local locked = item.PotLevel and data.PotLevel < item.PotLevel - 1
		local c = card(parent, 76, i, if item.PotLevel then T.Accent else T.Blue)
		if item.PotLevel then
			UI.orbIcon(c, Color3.fromRGB(70, 70, 90), 52, { Position = UDim2.fromOffset(0, 4) })
		else
			UI.vialIcon(c, 56, { Position = UDim2.fromOffset(0, 2) })
		end
		UI.text({ Text = item.Name, Position = UDim2.fromOffset(66, 4), Size = UDim2.new(1, -240, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
		UI.text({ Text = item.Description, Position = UDim2.fromOffset(66, 34), Size = UDim2.new(1, -240, 0, 20), TextColor3 = T.Muted, Font = T.Body, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
		local affordable = data.Coins >= item.Price
		local b = UI.button({
			Text = if owned then "Owned" elseif locked then "Locked" else UI.formatNumber(item.Price),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(160, 48),
			Color = if owned or locked or not affordable then T.PanelDark else T.Gold,
			Parent = c,
		}, function()
			if not owned and not locked then
				Remotes.Buy:FireServer(item.Id)
			end
		end)
		if not owned and not locked then
			UI.coinIcon(b, 26, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5) })
		end
	end

	if Config.Monetization.LuckBoostProductId ~= 0 then
		local c = card(parent, 76, 100, Color3.fromRGB(120, 255, 160))
		UI.text({ Text = string.format("Lucky Brew (%d min)", Config.Monetization.LuckBoostMinutes), Size = UDim2.new(1, -180, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
		UI.text({ Text = string.format("All catch odds x%g while it lasts.", Config.Monetization.LuckBoostMultiplier), Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, -180, 0, 20), TextColor3 = T.Muted, Font = T.Body, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
		UI.button({ Text = "Robux", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(160, 48), Color = T.Good, Parent = c }, function()
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
	section(parent, string.format("Seen %d / %d     Caught %d / %d", seenCount, #Config.GuardianOrder, caughtCount, #Config.GuardianOrder), 0)

	for i, id in Config.GuardianOrder do
		local def = Config.Guardians[id]
		local j = data.Journal[id]
		local rarity = Config.Rarities[def.Rarity]
		local c = card(parent, if j then 118 else 64, i, if j then rarity.Color else T.Slot)
		if not j then
			UI.text({ Text = "???", Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, Parent = c })
			UI.text({ Text = "Not seen yet. Look in " .. Config.Zones[def.Zone].Name .. ".", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 20), TextColor3 = T.Muted, Font = T.Body, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
			continue
		end
		UI.orbIcon(c, def.Color, 48, { Position = UDim2.fromOffset(0, 0) })
		UI.text({ Text = def.Name, Position = UDim2.fromOffset(58, 0), Size = UDim2.new(0.5, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rarity.Color, Parent = c })
		UI.text({ Text = string.format("%s · %s", def.Rarity, def.Element), Position = UDim2.fromOffset(58, 28), Size = UDim2.new(0.5, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, Parent = c })
		UI.text({
			Text = string.format("Caught %d", j.Caught or 0),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(140, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if (j.Caught or 0) > 0 then T.Good else T.Muted,
			Parent = c,
		})
		local favorite = if j.FavoriteKnown then "♥ Loves " .. Config.Ingredients[def.Favorite].Name else "♥ Favorite: ??? (feed it to find out)"
		local tried = {}
		for ingredientId in j.Tried or {} do
			if ingredientId ~= def.Favorite and Config.Ingredients[ingredientId] then
				table.insert(tried, Config.Ingredients[ingredientId].Name)
			end
		end
		if #tried > 0 and not j.FavoriteKnown then
			favorite ..= "   Not: " .. table.concat(tried, ", ")
		end
		UI.text({ Text = "Hint: " .. def.Hint, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Font = T.Body, Parent = c })
		UI.text({ Text = favorite, Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Font = T.Body, TextColor3 = if j.FavoriteKnown then T.Pink else T.Muted, Parent = c })
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
	section(parent, string.format("%d guardians · %s coins per second · your best %d live on your plot", #data.Guardians, UI.formatNumber(total), Config.MaxPlotDisplays), 0)

	local list = table.clone(data.Guardians)
	table.sort(list, function(a, b)
		return Config.GuardianIncome(a) > Config.GuardianIncome(b)
	end)
	for i, entry in list do
		local def = Config.Guardians[entry.Id]
		if not def then
			continue
		end
		local rarity = Config.Rarities[def.Rarity]
		local c = card(parent, 64, i, rarity.Color)
		UI.orbIcon(c, def.Color, 44, { Position = UDim2.fromOffset(0, 2) })
		UI.text({ Text = Config.GuardianDisplayName(entry), Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -250, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rarity.Color, Parent = c })
		UI.text({ Text = string.format("%s · +%s coins/s", def.Rarity, UI.formatNumber(Config.GuardianIncome(entry))), Position = UDim2.fromOffset(54, 26), Size = UDim2.new(1, -250, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, Parent = c })
		local value = math.floor(Config.GuardianIncome(entry) * Config.ReleaseValueSeconds)
		local confirming = releaseConfirm == entry.Uid
		UI.button({
			Text = if confirming then "Tap again to release" else "Release +" .. UI.formatNumber(value),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(190, 42),
			Color = if confirming then T.Bad else T.PanelDark,
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
		UI.text({ Text = "No guardians yet. Go catch one!", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = parent })
	end
end

----------------------------------------------------------------------
-- Help
----------------------------------------------------------------------
local HELP = {
	{ "Harvest", "Pick glowing plants in the three zones to get ingredients.", Color3.fromRGB(120, 220, 120) },
	{ "Brew", "At a cauldron (your plot or the big one in the hub), mix 3 ingredients into a Capture Flask. More stars = stronger flask. Each brew uses an Empty Vial from the Shop.", Color3.fromRGB(150, 110, 255) },
	{ "Weaken", "Dodge the red attack zones, lure guardians into brambles, lava or ice spikes, or throw a Weakening Draught. Lower resistance = better odds.", Color3.fromRGB(255, 150, 70) },
	{ "Feed", "Every guardian loves one ingredient. Pick Feed and tap it. Guess right and your odds double!", T.Pink },
	{ "Catch", "Pick a flask and tap the guardian (or press F). Three shakes... then GOTCHA, or it bursts out furious.", T.Gold },
	{ "Earn & Grow", "Caught guardians earn coins on your plot - collect them at the chest. Feed them ingredients at a cauldron to grow giant versions.", Color3.fromRGB(80, 170, 255) },
}

local function renderHelp(parent: Frame)
	for i, step in HELP do
		local c = card(parent, 82, i, step[3])
		UI.text({ Text = string.format("%d. %s", i, step[1]), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.lighten(step[3], 0.2), Parent = c })
		UI.text({
			Text = step[2],
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 38),
			TextScaled = false,
			TextSize = 16,
			TextWrapped = true,
			Font = T.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = c,
		})
	end
end

----------------------------------------------------------------------
function Menus.Init()
	gui = UI.screen()
	window = UI.panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(720, 580),
		Corner = 20,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	windowScale = UI.make("UIScale", { Parent = window })

	header = UI.make("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Gradient = { T.Accent, UI.darken(T.Accent, 0.2) },
		Corner = 20,
		Parent = window,
	})
	-- square off the header's bottom corners
	UI.make("Frame", {
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Gradient = { UI.darken(T.Accent, 0.15), UI.darken(T.Accent, 0.2) },
		Name = "HeaderBottom",
		Parent = header,
	})
	titleLabel = UI.text({ Text = "", Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -90, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = header })
	UI.button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(42, 42),
		Color = T.Bad,
		Corner = UDim.new(0.5, 0),
		ZIndex = 2,
		Parent = header,
	}, Menus.Close)

	local scroll = UI.make("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 70),
		Size = UDim2.new(1, -28, 1, -84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = T.Slot,
		Parent = window,
	})
	body = UI.make("Frame", {
		Size = UDim2.new(1, -14, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = scroll,
	})
	UI.make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = body })
	local layout = UI.list(body, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	renderers.Brew = renderBrew
	renderers.Shop = renderShop
	renderers.Journal = renderJournal
	renderers.Collection = renderCollection
	renderers.Help = renderHelp

	State.Changed:Connect(function()
		-- Drop slot picks the player no longer owns.
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
