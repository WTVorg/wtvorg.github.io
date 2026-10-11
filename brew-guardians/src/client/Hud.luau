-- Always-on HUD: coins, menu buttons, the action bar, toasts and banners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local T = UI.Theme

local Hud = {}
Hud.OpenMenu = nil :: ((name: string) -> ())?

local gui: ScreenGui
local coinsLabel: TextLabel
local vialsLabel: TextLabel
local luckLabel: TextLabel
local toastHolder: Frame
local slotButtons: { { Kind: string, Id: string, Button: TextButton, Count: TextLabel } } = {}
local feedPicker: Frame

local KIND_COLORS = {
	item = Color3.fromRGB(120, 200, 255),
	coins = T.Gold,
	weaken = Color3.fromRGB(255, 160, 80),
	favorite = Color3.fromRGB(255, 130, 210),
	catch = T.Good,
	nearmiss = Color3.fromRGB(255, 120, 60),
	fail = T.Bad,
	error = T.Bad,
	brew = Color3.fromRGB(160, 255, 180),
	info = T.Text,
}

----------------------------------------------------------------------
-- Toasts, banners, flashes
----------------------------------------------------------------------
function Hud.Toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or T.Text
	local toast = UI.make("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.15,
		Corner = 8,
		Stroke = color,
		Parent = toastHolder,
	}, {
		UI.text({
			Text = text,
			Size = UDim2.new(1, -16, 1, -8),
			Position = UDim2.fromOffset(8, 4),
			TextColor3 = color,
			Font = T.Body,
		}),
	})
	task.delay(3.5, function()
		local label = toast:FindFirstChildOfClass("TextLabel")
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		if label then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
		task.wait(0.45)
		toast:Destroy()
	end)
	-- Keep the stack short.
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 5 then
		toasts[1]:Destroy()
	end
end

function Hud.Announce(text: string)
	local banner = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		Size = UDim2.fromOffset(620, 56),
		BackgroundColor3 = Color3.fromRGB(60, 40, 10),
		Corner = 12,
		Stroke = T.Gold,
		Parent = gui,
	}, {
		UI.text({ Text = text, Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6), TextColor3 = T.Gold }),
	})
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 70) }):Play()
	task.delay(5, function()
		TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
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
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(200, 50),
		TextColor3 = color,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		ZIndex = 60,
		Parent = gui,
	})
	TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(640, 110) }):Play()
	task.delay(hold or 1.4, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.35)
		label:Destroy()
	end)
end

----------------------------------------------------------------------
-- Action bar
----------------------------------------------------------------------
local function refreshSlots()
	local data = State.Data
	local sel = State.Selected
	for _, slot in slotButtons do
		local count = 0
		local label = ""
		if data then
			if slot.Kind == "Flask" then
				count = data.Flasks[slot.Id] or 0
			elseif slot.Kind == "Draught" then
				count = data.Draughts[slot.Id] or 0
			end
		end
		if slot.Kind == "Feed" then
			local feedId = if sel.Kind == "Feed" then sel.Id else nil
			if feedId and data then
				count = data.Ingredients[feedId] or 0
				label = "Feed: " .. Config.Ingredients[feedId].Name
			else
				label = "Feed"
			end
			slot.Button.Text = label
			slot.Count.Text = if feedId then "x" .. count else ""
		else
			slot.Count.Text = "x" .. count
		end
		local selected = sel.Kind == slot.Kind and (slot.Kind == "Feed" or sel.Id == slot.Id)
		slot.Button.BackgroundTransparency = if count > 0 or slot.Kind == "Feed" then 0 else 0.55
		local stroke = slot.Button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if selected then T.Gold else T.PanelLight
			stroke.Thickness = if selected then 3 else 2
		end
	end
end

local function showFeedPicker()
	UI.clear(feedPicker)
	local data = State.Data
	local any = false
	for _, id in Config.IngredientOrder do
		local count = data and data.Ingredients[id] or 0
		if count > 0 then
			any = true
			local def = Config.Ingredients[id]
			UI.button({
				Text = string.format("%s x%d", def.Name, count),
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = def.Color:Lerp(T.Panel, 0.45),
			}, function()
				State.Select("Feed", id)
				feedPicker.Visible = false
			end).Parent = feedPicker
		end
	end
	if not any then
		UI.text({ Text = "No ingredients. Harvest some in the zones!", Size = UDim2.new(1, 0, 0, 30), Font = T.Body }).Parent =
			feedPicker
	end
	feedPicker.Visible = true
end

local function buildActionBar()
	local bar = UI.make("Frame", {
		Name = "ActionBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(0, 74),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.2,
		Corner = 12,
		Parent = gui,
	})
	UI.padding(bar, 6)
	UI.list(bar, 6, true)

	local entries = {}
	for _, f in Config.Flasks do
		table.insert(entries, { Kind = "Flask", Id = f.Id, Name = f.Name, Color = f.Color })
	end
	for _, d in Config.Draughts do
		table.insert(entries, { Kind = "Draught", Id = d.Id, Name = d.Name, Color = d.Color })
	end
	table.insert(entries, { Kind = "Feed", Id = "", Name = "Feed", Color = Color3.fromRGB(255, 130, 210) })

	for i, entry in entries do
		local button = UI.button({
			Text = entry.Name,
			LayoutOrder = i,
			Size = UDim2.fromOffset(84, 62),
			BackgroundColor3 = entry.Color:Lerp(T.Panel, 0.5),
			Stroke = T.PanelLight,
			Font = T.Font,
		}, function()
			if entry.Kind == "Feed" then
				showFeedPicker()
			else
				feedPicker.Visible = false
				State.Select(entry.Kind, entry.Id)
			end
		end)
		button.TextScaled = true
		local keyHint = UI.text({
			Text = tostring(i),
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(-2, -4),
			TextColor3 = T.Muted,
			Parent = button,
		})
		keyHint.Visible = UserInputService.KeyboardEnabled
		local count = UI.text({
			Text = "",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 2, 1, 4),
			Size = UDim2.fromOffset(34, 18),
			TextColor3 = T.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = button,
		})
		button.Parent = bar
		table.insert(slotButtons, { Kind = entry.Kind, Id = entry.Id, Button = button, Count = count })
	end

	feedPicker = UI.make("ScrollingFrame", {
		Name = "FeedPicker",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, 330, 1, -96),
		Size = UDim2.fromOffset(240, 260),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		BackgroundColor3 = T.Panel,
		Corner = 10,
		Visible = false,
		Parent = gui,
	})
	UI.padding(feedPicker, 6)
	UI.list(feedPicker, 4)

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

----------------------------------------------------------------------
-- Top bar
----------------------------------------------------------------------
local function buildTopBar()
	local top = UI.make("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.2,
		Corner = 10,
		Parent = gui,
	})
	UI.padding(top, 6)
	UI.list(top, 10, true)
	coinsLabel = UI.text({ Text = "0 coins", Size = UDim2.fromOffset(150, 34), TextColor3 = T.Gold, LayoutOrder = 1, Parent = top })
	vialsLabel = UI.text({ Text = "0 vials", Size = UDim2.fromOffset(100, 34), TextColor3 = Color3.fromRGB(170, 220, 255), LayoutOrder = 2, Parent = top })
	luckLabel = UI.text({ Text = "", Size = UDim2.fromOffset(130, 34), TextColor3 = Color3.fromRGB(120, 255, 160), LayoutOrder = 3, Visible = false, Parent = top })

	local menus = UI.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(120, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.list(menus, 8)
	for i, name in { "Journal", "Collection", "Help" } do
		UI.button({ Text = name, LayoutOrder = i, Size = UDim2.fromOffset(120, 40), BackgroundColor3 = T.PanelLight, Stroke = T.Accent }, function()
			if Hud.OpenMenu then
				Hud.OpenMenu(name)
			end
		end).Parent = menus
	end
end

local function refreshTop()
	local data = State.Data
	if not data then
		return
	end
	coinsLabel.Text = UI.formatNumber(data.Coins) .. " coins"
	vialsLabel.Text = data.Vials .. " vials"
end

function Hud.Init()
	gui = UI.screen()

	toastHolder = UI.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.list(toastHolder, 6)

	buildTopBar()
	buildActionBar()

	State.Changed:Connect(function()
		refreshTop()
		refreshSlots()
	end)
	State.SelectionChanged:Connect(refreshSlots)

	-- Luck boost countdown
	task.spawn(function()
		while true do
			local data = State.Data
			local left = data and (data.LuckUntil or 0) - os.time() or 0
			luckLabel.Visible = left > 0
			if left > 0 then
				luckLabel.Text = string.format("Luck %d:%02d", left // 60, left % 60)
			end
			task.wait(1)
		end
	end)
end

return Hud
