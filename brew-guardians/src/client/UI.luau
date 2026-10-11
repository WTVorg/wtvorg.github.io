-- Tiny helpers for building UI in code.

local Players = game:GetService("Players")

local UI = {}

UI.Theme = {
	Panel = Color3.fromRGB(34, 28, 48),
	PanelLight = Color3.fromRGB(52, 44, 72),
	Slot = Color3.fromRGB(64, 54, 88),
	Accent = Color3.fromRGB(150, 110, 255),
	Good = Color3.fromRGB(110, 220, 130),
	Bad = Color3.fromRGB(255, 95, 95),
	Gold = Color3.fromRGB(255, 205, 80),
	Text = Color3.fromRGB(245, 240, 255),
	Muted = Color3.fromRGB(170, 160, 195),
	Font = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
}

-- make("Frame", { Size = ..., Parent = ... }, { children })
function UI.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			elseif k == "Corner" then
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, v)
				c.Parent = inst
			elseif k == "Stroke" then
				local s = Instance.new("UIStroke")
				s.Color = v
				s.Thickness = 2
				s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				s.Parent = inst
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

function UI.text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UI.Theme.Font,
		TextColor3 = UI.Theme.Text,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for k, v in props do
		defaults[k] = v
	end
	return UI.make("TextLabel", defaults)
end

function UI.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults = {
		BackgroundColor3 = UI.Theme.Accent,
		Font = UI.Theme.Font,
		TextColor3 = UI.Theme.Text,
		TextScaled = true,
		AutoButtonColor = true,
		Corner = 8,
		Size = UDim2.fromOffset(120, 36),
	}
	for k, v in props do
		defaults[k] = v
	end
	local b = UI.make("TextButton", defaults)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	b.Activated:Connect(onClick)
	return b
end

function UI.list(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	return UI.make("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
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
		scale.Scale = math.clamp(y / 820, 0.55, 1.1)
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
