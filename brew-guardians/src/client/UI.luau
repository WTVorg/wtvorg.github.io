-- UI kit: theme, chunky outlined buttons and panels, and small drawn icons
-- (flask, coin, vial, ingredient orb) so nothing depends on uploaded images.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}
UI.OnClick = nil :: (() -> ())? -- set by the HUD to play the click sound

UI.Theme = {
	Panel = Color3.fromRGB(46, 32, 72),
	PanelDark = Color3.fromRGB(30, 20, 48),
	PanelLight = Color3.fromRGB(70, 52, 104),
	Slot = Color3.fromRGB(88, 70, 124),
	Outline = Color3.fromRGB(16, 10, 26),
	Accent = Color3.fromRGB(150, 100, 255),
	Good = Color3.fromRGB(90, 210, 110),
	Bad = Color3.fromRGB(240, 80, 90),
	Gold = Color3.fromRGB(255, 200, 60),
	Blue = Color3.fromRGB(80, 170, 255),
	Pink = Color3.fromRGB(255, 120, 200),
	Text = Color3.fromRGB(255, 250, 240),
	Muted = Color3.fromRGB(190, 175, 220),
	Font = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
}
local T = UI.Theme

local function lighten(c: Color3, a: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), a)
end
local function darken(c: Color3, a: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), a)
end
UI.lighten = lighten
UI.darken = darken

-- make("Frame", { Size = ..., Parent = ..., Corner = 8, Stroke = color }, { children })
function UI.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			elseif k == "Corner" then
				local c = Instance.new("UICorner")
				c.CornerRadius = if typeof(v) == "UDim" then v else UDim.new(0, v)
				c.Parent = inst
			elseif k == "Stroke" then
				local s = Instance.new("UIStroke")
				s.Color = v
				s.Thickness = props.StrokeThickness or 3
				s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				s.Parent = inst
			elseif k == "StrokeThickness" then
				continue
			elseif k == "Gradient" then
				local g = Instance.new("UIGradient")
				g.Color = ColorSequence.new(v[1], v[2])
				g.Rotation = 90
				g.Parent = inst
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Bold text with a dark outline, the house style for every label.
function UI.text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = T.Font,
		TextColor3 = T.Text,
		TextScaled = true,
		TextStrokeColor3 = T.Outline,
		TextStrokeTransparency = 0.35,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for k, v in props do
		defaults[k] = v
	end
	return UI.make("TextLabel", defaults)
end

-- Chunky gradient button with a thick outline and a squash on press.
function UI.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local color = props.Color or T.Accent
	props.Color = nil
	local defaults = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Gradient = { lighten(color, 0.15), darken(color, 0.12) },
		Font = T.Font,
		TextColor3 = T.Text,
		TextScaled = true,
		TextStrokeColor3 = T.Outline,
		TextStrokeTransparency = 0.2,
		AutoButtonColor = false,
		Corner = 10,
		Stroke = T.Outline,
		Size = UDim2.fromOffset(120, 40),
	}
	for k, v in props do
		defaults[k] = v
	end
	local b = UI.make("TextButton", defaults)
	UI.make("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
		Parent = b,
	})
	local scale = UI.make("UIScale", { Parent = b })
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	b.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	b.Activated:Connect(function()
		if UI.OnClick then
			UI.OnClick()
		end
		onClick()
	end)
	return b
end

-- Panel with a soft vertical gradient and the dark outline.
function UI.panel(props: { [string]: any }): Frame
	local color = props.Color or T.Panel
	props.Color = nil
	local defaults = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Gradient = { lighten(color, 0.08), darken(color, 0.15) },
		Corner = 14,
		Stroke = T.Outline,
	}
	for k, v in props do
		defaults[k] = v
	end
	return UI.make("Frame", defaults)
end

function UI.list(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	return UI.make("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = parent,
	})
end

function UI.padding(parent: Instance, px: number)
	UI.make("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		Parent = parent,
	})
end

function UI.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

----------------------------------------------------------------------
-- Drawn icons. Each fills a square `size` px box placed in `parent`.
----------------------------------------------------------------------
local function iconBox(parent: Instance, size: number, props: { [string]: any }?): Frame
	local box = UI.make("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = parent })
	if props then
		for k, v in props do
			(box :: any)[k] = v
		end
	end
	return box
end

-- Round potion flask with neck, cork and a shine.
function UI.flaskIcon(parent: Instance, color: Color3, size: number, props: { [string]: any }?): Frame
	local box = iconBox(parent, size, props)
	UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.26, 0.14),
		BackgroundColor3 = Color3.fromRGB(160, 110, 70),
		Corner = 3,
		Stroke = T.Outline,
		StrokeThickness = 2,
		Parent = box,
	})
	UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.18),
		Size = UDim2.fromScale(0.3, 0.22),
		BackgroundColor3 = lighten(color, 0.45),
		Stroke = T.Outline,
		StrokeThickness = 2,
		Parent = box,
	})
	local bulb = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(0.78, 0.62),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Gradient = { lighten(color, 0.3), darken(color, 0.15) },
		Corner = UDim.new(0.5, 0),
		Stroke = T.Outline,
		StrokeThickness = 2,
		Parent = box,
	})
	UI.make("Frame", {
		Position = UDim2.fromScale(0.2, 0.18),
		Size = UDim2.fromScale(0.2, 0.24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		Corner = UDim.new(0.5, 0),
		Parent = bulb,
	})
	return box
end

function UI.coinIcon(parent: Instance, size: number, props: { [string]: any }?): Frame
	local box = iconBox(parent, size, props)
	local coin = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Gradient = { Color3.fromRGB(255, 225, 100), Color3.fromRGB(230, 150, 30) },
		Corner = UDim.new(0.5, 0),
		Stroke = T.Outline,
		StrokeThickness = 2,
		Parent = box,
	})
	UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
		Corner = UDim.new(0.5, 0),
		Stroke = Color3.fromRGB(200, 120, 20),
		StrokeThickness = 2,
		Parent = coin,
	})
	return box
end

function UI.vialIcon(parent: Instance, size: number, props: { [string]: any }?): Frame
	local box = iconBox(parent, size, props)
	UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.5, 0.14),
		BackgroundColor3 = Color3.fromRGB(160, 110, 70),
		Corner = 3,
		Stroke = T.Outline,
		StrokeThickness = 2,
		Parent = box,
	})
	UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.fromScale(0.42, 0.8),
		BackgroundColor3 = Color3.fromRGB(200, 235, 255),
		BackgroundTransparency = 0.1,
		Corner = UDim.new(0.3, 0),
		Stroke = T.Outline,
		StrokeThickness = 2,
		Parent = box,
	})
	return box
end

-- Glossy orb in an ingredient's colour.
function UI.orbIcon(parent: Instance, color: Color3, size: number, props: { [string]: any }?): Frame
	local box = iconBox(parent, size, props)
	local orb = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Gradient = { lighten(color, 0.35), darken(color, 0.2) },
		Corner = UDim.new(0.5, 0),
		Stroke = T.Outline,
		StrokeThickness = 2,
		Parent = box,
	})
	UI.make("Frame", {
		Position = UDim2.fromScale(0.2, 0.14),
		Size = UDim2.fromScale(0.3, 0.26),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.3,
		Corner = UDim.new(0.5, 0),
		Parent = orb,
	})
	return box
end

-- Small rounded count badge anchored to a corner of `parent`.
function UI.badge(parent: Instance, text: string, color: Color3?): TextLabel
	return UI.text({
		Text = text,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(36, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = color or T.Gold,
		TextColor3 = T.Outline,
		TextStrokeTransparency = 1,
		Corner = 11,
		Stroke = T.Outline,
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = parent,
	})
end

local screen: ScreenGui? = nil
function UI.screen(): ScreenGui
	if screen then
		return screen
	end
	local gui = UI.make("ScreenGui", {
		Name = "BrewGuardiansUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- Shrink everything on small screens.
	local scale = UI.make("UIScale", { Parent = gui })
	local camera = workspace.CurrentCamera
	local function rescale()
		local y = camera.ViewportSize.Y
		scale.Scale = math.clamp(y / 860, 0.55, 1.1)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	screen = gui
	return gui
end

function UI.formatNumber(n: number): string
	n = math.floor(n)
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

return UI
