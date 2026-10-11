-- Lighting, sky, clouds and post-processing. All built-in engine features,
-- so none of it needs uploaded assets. Lighting.Technology (Future) is set in
-- default.project.json because scripts can't change it.

local Lighting = game:GetService("Lighting")

local Environment = {}

local function make(className: string, parent: Instance, props: { [string]: any })
	local existing = parent:FindFirstChildOfClass(className)
	local inst = existing or Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

function Environment.Setup()
	Lighting.ClockTime = 14.6
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0.1
	Lighting.Ambient = Color3.fromRGB(70, 70, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 160)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true

	make("Sky", Lighting, { SunAngularSize = 14, MoonAngularSize = 9, StarCount = 3000 })
	make("Atmosphere", Lighting, {
		Density = 0.32,
		Offset = 0.2,
		Color = Color3.fromRGB(205, 225, 255),
		Decay = Color3.fromRGB(110, 150, 205),
		Glare = 0.25,
		Haze = 1.4,
	})
	-- Bloom makes Neon parts (brews, flames, crystals, lava) actually glow.
	make("BloomEffect", Lighting, { Intensity = 0.7, Size = 28, Threshold = 1.4 })
	make("ColorCorrectionEffect", Lighting, {
		Brightness = 0.02,
		Contrast = 0.08,
		Saturation = 0.18,
		TintColor = Color3.fromRGB(255, 248, 238),
	})
	make("SunRaysEffect", Lighting, { Intensity = 0.05, Spread = 0.8 })
	make("DepthOfFieldEffect", Lighting, { FarIntensity = 0.12, FocusDistance = 80, InFocusRadius = 120, NearIntensity = 0 })

	local terrain = workspace.Terrain
	make("Clouds", terrain, { Cover = 0.55, Density = 0.65, Color = Color3.fromRGB(255, 255, 255) })
end

return Environment
