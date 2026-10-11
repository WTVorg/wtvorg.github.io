-- Always-on HUD: currency, menu buttons, the hotbar, toasts and banners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local T = UI.Theme

local Hud = {}
Hud.OpenMenu = nil :: ((name: string) -> ())?

local gui: ScreenGui
local coinsLabel: TextLabel
local vialsLabel: TextLabel
local luckPill: Frame
local luckLabel: TextLabel
local toastHolder: Frame
local hintLabel: TextLabel
local slotButtons: { { Kind: string, Id: string, Button: TextButton, Count: TextLabel, Name: TextLabel, Icon: Frame?, Color: Color3 } } = {}
local feedPicker: Frame

local KIND_COLORS = {
	item = Color3.fromRGB(120, 200, 255),
	coins = T.Gold,
	weaken = Color3.fromRGB(255, 160, 80),
	favorite = T.Pink,
	catch = T.Good,
	nearmiss = Color3.fromRGB(255, 130, 60),
	fail = T.Bad,
	error = T.Bad,
	brew = Color3.fromRGB(150, 255, 170),
	info = Color3.fromRGB(200, 180, 255),
}

----------------------------------------------------------------------
-- Toasts, banners, flashes
----------------------------------------------------------------------
local KIND_SOUNDS = { item = "Harvest", coins = "Coins", brew = "Brew" }

local function playSound(slot: string)
	local id = Sounds.Get(slot)
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.6
	s.Parent = gui
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end
Hud.PlaySound = playSound

function Hud.Toast(text: string, kind: string?)
	local soundSlot = KIND_SOUNDS[kind or ""]
	if soundSlot then
		playSound(soundSlot)
	end
	local color = KIND_COLORS[kind or "info"] or T.Text
	local toast = UI.panel({
		Size = UDim2.fromOffset(460, 40),
		Color = T.PanelDark,
		Corner = 20,
		BackgroundTransparency = 0.05,
		Parent = toastHolder,
	})
	UI.make("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = color,
		Corner = 10,
		Stroke = T.Outline,
		StrokeThickness = 2,
		Parent = toast,
	})
	local label = UI.text({
		Text = text,
		Position = UDim2.fromOffset(40, 6),
		Size = UDim2.new(1, -52, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35),
		Parent = toast,
	})
	local scale = UI.make("UIScale", { Scale = 0.6, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(3.5, function()
		TweenService:Create(toast, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		local stroke = toast:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
		task.wait(0.4)
		toast:Destroy()
	end)
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		toasts[1]:Destroy()
	end
end

function Hud.Announce(text: string)
	local banner = UI.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -90),
		Size = UDim2.fromOffset(640, 64),
		Color = Color3.fromRGB(120, 70, 20),
		Corner = 16,
		Parent = gui,
	})
	UI.make("UIStroke", { Color = T.Gold, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = banner })
	UI.text({ Text = "★  " .. text .. "  ★", Size = UDim2.new(1, -24, 1, -16), Position = UDim2.fromOffset(12, 8), TextColor3 = T.Gold, Parent = banner })
	TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 74) }):Play()
	task.delay(5, function()
		TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -90) }):Play()
		task.wait(0.35)
		banner:Destroy()
	end)
end

function Hud.Flash(color: Color3, strength: number)
	local flash = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - strength,
		ZIndex = 50,
		Parent = gui,
	})
	local tween = TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Once(function()
		flash:Destroy()
	end)
end

function Hud.BigText(text: string, color: Color3, hold: number?)
	local label = UI.text({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.34),
		Size = UDim2.fromOffset(700, 120),
		TextColor3 = color,
		TextStrokeTransparency = 0,
		ZIndex = 60,
		Parent = gui,
	})
	UI.make("UIStroke", { Color = T.Outline, Thickness = 4, Parent = label })
	local scale = UI.make("UIScale", { Scale = 0.2, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(hold or 1.4, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		task.wait(0.35)
		label:Destroy()
	end)
end

----------------------------------------------------------------------
-- Hotbar
----------------------------------------------------------------------
local function refreshSlots()
	local data = State.Data
	local sel = State.Selected
	for _, slot in slotButtons do
		local count = 0
		if data then
			if slot.Kind == "Flask" then
				count = data.Flasks[slot.Id] or 0
			elseif slot.Kind == "Draught" then
				count = data.Draughts[slot.Id] or 0
			end
		end
		local selected = sel.Kind == slot.Kind and (slot.Kind == "Feed" or sel.Id == slot.Id)
		if slot.Kind == "Feed" then
			local feedId = if sel.Kind == "Feed" then sel.Id else nil
			if feedId and data then
				count = data.Ingredients[feedId] or 0
				slot.Name.Text = Config.Ingredients[feedId].Name
			else
				slot.Name.Text = "Feed"
			end
			slot.Count.Visible = feedId ~= nil
			slot.Count.Text = "x" .. count
		else
			slot.Count.Text = "x" .. count
			slot.Count.BackgroundColor3 = if count > 0 then T.Gold else Color3.fromRGB(150, 140, 160)
		end
		local usable = count > 0 or slot.Kind == "Feed"
		if slot.Icon then
			for _, d in slot.Icon:GetDescendants() do
				if d:IsA("Frame") and d.BackgroundTransparency < 0.9 then
					d.BackgroundTransparency = if usable then 0 else 0.55
				end
			end
		end
		local stroke = slot.Button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if selected then T.Gold else T.Outline
			stroke.Thickness = if selected then 4 else 3
		end
		local target = if selected then UDim2.fromOffset(0, -8) else UDim2.fromOffset(0, 0)
		TweenService:Create(slot.Button, TweenInfo.new(0.15), { Position = target }):Play()
	end
end

local function showFeedPicker()
	UI.clear(feedPicker)
	local data = State.Data
	local any = false
	UI.text({ Text = "Feed which ingredient?", Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0, Parent = feedPicker })
	for i, id in Config.IngredientOrder do
		local count = data and data.Ingredients[id] or 0
		if count > 0 then
			any = true
			local def = Config.Ingredients[id]
			local b = UI.button({
				Text = "",
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 42),
				Color = T.Slot,
			}, function()
				State.Select("Feed", id)
				feedPicker.Visible = false
			end)
			UI.orbIcon(b, def.Color, 28, { Position = UDim2.fromOffset(0, 2) })
			UI.text({ Text = def.Name, Position = UDim2.fromOffset(38, 4), Size = UDim2.new(1, -90, 1, -8), TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
			UI.text({ Text = "x" .. count, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.new(0, 50, 1, -8), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Gold, Parent = b })
			b.Parent = feedPicker
		end
	end
	if not any then
		UI.text({ Text = "No ingredients yet. Harvest glowing plants in the zones!", Size = UDim2.new(1, 0, 0, 44), TextWrapped = true, Font = T.Body, LayoutOrder = 1, Parent = feedPicker })
	end
	feedPicker.Visible = true
end

local function buildHotbar()
	local bar = UI.panel({
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(0, 104),
		AutomaticSize = Enum.AutomaticSize.X,
		Color = T.PanelDark,
		BackgroundTransparency = 0.1,
		Corner = 18,
		Parent = gui,
	})
	UI.padding(bar, 10)
	UI.list(bar, 8, true)

	local entries = {}
	for _, f in Config.Flasks do
		table.insert(entries, { Kind = "Flask", Id = f.Id, Name = f.Name:gsub(" Flask", ""), Color = f.Color })
	end
	for _, d in Config.Draughts do
		table.insert(entries, { Kind = "Draught", Id = d.Id, Name = (d.Name:gsub(" Draught", "")), Color = d.Color })
	end
	table.insert(entries, { Kind = "Feed", Id = "", Name = "Feed", Color = T.Pink })

	for i, entry in entries do
		local holder = UI.make("Frame", { Size = UDim2.fromOffset(78, 84), BackgroundTransparency = 1, LayoutOrder = i, Parent = bar })
		local button = UI.button({
			Text = "",
			Size = UDim2.fromScale(1, 1),
			Color = T.Slot,
			Corner = 14,
		}, function()
			if entry.Kind == "Feed" then
				if feedPicker.Visible then
					feedPicker.Visible = false
				else
					showFeedPicker()
				end
			else
				feedPicker.Visible = false
				State.Select(entry.Kind, entry.Id)
			end
		end)
		button.Parent = holder
		local icon: Frame? = nil
		if entry.Kind == "Feed" then
			-- a heart drawn from two circles and a rotated square
			local heart = UI.make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(42, 42), BackgroundTransparency = 1, Parent = button })
			UI.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.5, 0.5), Rotation = 45, BackgroundColor3 = T.Pink, Parent = heart })
			for _, x in { 0.32, 0.68 } do
				UI.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.4), Size = UDim2.fromScale(0.42, 0.42), BackgroundColor3 = T.Pink, Corner = UDim.new(0.5, 0), Parent = heart })
			end
			icon = heart
		elseif entry.Kind == "Draught" then
			-- draughts are round splash potions, flasks have a neck
			icon = UI.orbIcon(button, entry.Color, 38, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6) })
		else
			icon = UI.flaskIcon(button, entry.Color, 46, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0) })
		end
		local name = UI.text({
			Text = entry.Name,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(1, 6, 0, 20),
			Parent = button,
		})
		local count = UI.badge(button, "x0")
		if UserInputService.KeyboardEnabled then
			UI.text({
				Text = tostring(i),
				Position = UDim2.fromOffset(-4, -4),
				Size = UDim2.fromOffset(16, 16),
				TextColor3 = T.Muted,
				Parent = button,
			})
		end
		table.insert(slotButtons, { Kind = entry.Kind, Id = entry.Id, Button = button, Count = count, Name = name, Icon = icon, Color = entry.Color })
	end

	feedPicker = UI.panel({
		Name = "FeedPicker",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, 400, 1, -132),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	UI.padding(feedPicker, 10)
	UI.list(feedPicker, 6)

	hintLabel = UI.text({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -128),
		Size = UDim2.fromOffset(600, 26),
		TextColor3 = T.Muted,
		Parent = gui,
	})

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local index = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		if index >= 1 and index <= #entries then
			local entry = entries[index]
			if entry.Kind == "Feed" then
				showFeedPicker()
			else
				State.Select(entry.Kind, entry.Id)
			end
		end
	end)
end

local function refreshHint()
	local sel = State.Selected
	local verb = if sel.Kind == "Feed" then "feed it" elseif sel.Kind == "Draught" then "weaken it" else "throw"
	local how = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Tap a guardian to " else "Click a guardian (or press F) to "
	hintLabel.Text = how .. verb
end

----------------------------------------------------------------------
-- Currency and menu buttons
----------------------------------------------------------------------
local function pill(parent: Instance, order: number, width: number): Frame
	local p = UI.panel({ Size = UDim2.fromOffset(width, 48), Color = T.PanelDark, Corner = 24, LayoutOrder = order, Parent = parent })
	return p
end

local function buildTopBar()
	local top = UI.make("Frame", {
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = UI.list(top, 10, true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local coins = pill(top, 1, 190)
	UI.coinIcon(coins, 36, { Position = UDim2.fromOffset(6, 6) })
	coinsLabel = UI.text({ Text = "0", Position = UDim2.fromOffset(50, 8), Size = UDim2.new(1, -62, 1, -16), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Gold, Parent = coins })

	local vials = pill(top, 2, 130)
	UI.vialIcon(vials, 36, { Position = UDim2.fromOffset(8, 6) })
	vialsLabel = UI.text({ Text = "0", Position = UDim2.fromOffset(50, 8), Size = UDim2.new(1, -62, 1, -16), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 230, 255), Parent = vials })

	luckPill = pill(top, 3, 150)
	luckPill.Visible = false
	luckLabel = UI.text({ Text = "", Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 1, -16), TextColor3 = Color3.fromRGB(120, 255, 160), Parent = luckPill })

	local menus = UI.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(84, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.list(menus, 10)
	local buttons = {
		{ "Journal", Color3.fromRGB(80, 160, 255), "J" },
		{ "Collection", Color3.fromRGB(255, 150, 60), "C" },
		{ "Help", Color3.fromRGB(120, 200, 110), "?" },
	}
	for i, info in buttons do
		local b = UI.button({ Text = "", LayoutOrder = i, Size = UDim2.fromOffset(84, 84), Color = info[2], Corner = 18 }, function()
			if Hud.OpenMenu then
				Hud.OpenMenu(info[1])
			end
		end)
		UI.text({ Text = info[3], AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(50, 46), Parent = b })
		UI.text({ Text = info[1], AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 8, 0, 20), Parent = b })
		b.Parent = menus
	end
end

local shownCoins = 0
local function refreshTop()
	local data = State.Data
	if not data then
		return
	end
	-- count up/down smoothly
	local target = math.floor(data.Coins)
	local start = shownCoins
	task.spawn(function()
		for i = 1, 10 do
			shownCoins = math.floor(start + (target - start) * i / 10)
			coinsLabel.Text = UI.formatNumber(shownCoins)
			task.wait(0.03)
		end
	end)
	vialsLabel.Text = tostring(data.Vials)
end

function Hud.Init()
	gui = UI.screen()

	toastHolder = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.list(toastHolder, 6)

	buildTopBar()
	buildHotbar()
	refreshHint()

	State.Changed:Connect(function()
		refreshTop()
		refreshSlots()
	end)
	State.SelectionChanged:Connect(function()
		refreshSlots()
		refreshHint()
	end)
	refreshSlots()

	task.spawn(function()
		while true do
			local data = State.Data
			local left = data and (data.LuckUntil or 0) - os.time() or 0
			luckPill.Visible = left > 0
			if left > 0 then
				luckLabel.Text = string.format("Luck %d:%02d", left // 60, left % 60)
			end
			task.wait(1)
		end
	end)
end

return Hud
