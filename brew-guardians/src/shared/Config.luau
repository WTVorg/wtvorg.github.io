-- All game tuning lives here. Designers should be able to add a guardian,
-- ingredient or flask tier by editing this file only.

local Config = {}

----------------------------------------------------------------------
-- Economy
----------------------------------------------------------------------
Config.StartingData = {
	Coins = 40,
	Vials = 4,
	Flasks = { Clay = 3 },
	Ingredients = { Sunpetal = 2, Dewleaf = 2 },
}

Config.Shop = {
	{ Id = "Vial", Name = "Empty Vial", Price = 8, Amount = 1, Description = "Every flask and draught is brewed into a vial." },
	{ Id = "Vial5", Name = "Vial Crate (x5)", Price = 35, Amount = 5, Description = "Five vials, a small discount." },
	{ Id = "Pot2", Name = "Copper Cauldron", Price = 400, PotLevel = 2, Description = "+1 brew quality on everything you brew." },
	{ Id = "Pot3", Name = "Runed Cauldron", Price = 2500, PotLevel = 3, Description = "+2 brew quality on everything you brew." },
}

-- Robux products. Leave at 0 to hide them. These are deliberately boosts,
-- never flasks or creatures: selling a random chance at a guardian for Robux
-- would fall under Roblox's paid random item rules (odds disclosure).
Config.Monetization = {
	LuckBoostProductId = 0, -- Developer Product id for "Lucky Brew (15 min)"
	LuckBoostMinutes = 15,
	LuckBoostMultiplier = 1.25, -- applied to the final catch chance
}

Config.IncomeTickSeconds = 1
Config.MaxPendingIncomeSeconds = 60 * 60 * 2 -- plot stops filling after 2h of income
Config.MaxPlotDisplays = 12
Config.ReleaseValueSeconds = 90 -- releasing pays this many seconds of the guardian's income

----------------------------------------------------------------------
-- Ingredients
----------------------------------------------------------------------
Config.IngredientOrder = {
	"Sunpetal", "Dewleaf", "HoneydewRoot", "EmberPepper", "Ashcap", "Frostcap", "Moonberry", "StarlightNectar",
}

Config.Ingredients = {
	Sunpetal = {
		Style = "Flower",
		Name = "Sunpetal", Tier = 1, Color = Color3.fromRGB(255, 214, 74),
		Zones = { Meadow = 7 }, Respawn = 20,
		Description = "A cheerful flower that hums when the sun is out.",
	},
	Dewleaf = {
		Style = "Leaf",
		Name = "Dewleaf", Tier = 1, Color = Color3.fromRGB(110, 220, 170),
		Zones = { Meadow = 7, Frost = 3 }, Respawn = 20,
		Description = "Always wet, even at noon.",
	},
	HoneydewRoot = {
		Style = "Root",
		Name = "Honeydew Root", Tier = 2, Color = Color3.fromRGB(214, 160, 92),
		Zones = { Meadow = 4 }, Respawn = 45,
		Description = "Sweet, knotted and stubborn to pull up.",
	},
	EmberPepper = {
		Style = "Pepper",
		Name = "Ember Pepper", Tier = 2, Color = Color3.fromRGB(255, 92, 48),
		Zones = { Caldera = 6 }, Respawn = 35,
		Description = "Warm to the touch. Do not lick.",
	},
	Ashcap = {
		Style = "Mushroom",
		Name = "Ashcap", Tier = 3, Color = Color3.fromRGB(120, 110, 120),
		Zones = { Caldera = 4 }, Respawn = 70,
		Description = "A mushroom that only grows where something burned.",
	},
	Frostcap = {
		Style = "Mushroom",
		Name = "Frostcap", Tier = 2, Color = Color3.fromRGB(150, 210, 255),
		Zones = { Frost = 6, Caldera = 1 }, Respawn = 35,
		Description = "Leaves a ring of frost wherever it is set down.",
	},
	Moonberry = {
		Style = "Berry",
		Name = "Moonberry", Tier = 3, Color = Color3.fromRGB(170, 120, 255),
		Zones = { Frost = 4 }, Respawn = 70,
		Description = "Glows faintly. Tastes like a cold night.",
	},
	StarlightNectar = {
		Style = "Nectar",
		Name = "Starlight Nectar", Tier = 4, Color = Color3.fromRGB(255, 250, 210),
		Zones = { Meadow = 1, Caldera = 1, Frost = 1 }, Respawn = 240,
		Description = "One drop makes a flask sing. Very rare.",
	},
}

----------------------------------------------------------------------
-- Brewing
----------------------------------------------------------------------
-- A capture flask is brewed from 3 ingredients. Quality = sum of tiers
-- plus the cauldron bonus. Higher quality gives a higher flask tier.
Config.FlaskIngredientCount = 3
Config.Flasks = {
	{ Id = "Clay", Name = "Clay Flask", Mult = 1.0, MinQuality = 0, Color = Color3.fromRGB(196, 132, 92) },
	{ Id = "Glass", Name = "Glass Flask", Mult = 1.5, MinQuality = 5, Color = Color3.fromRGB(140, 220, 255) },
	{ Id = "Crystal", Name = "Crystal Flask", Mult = 2.2, MinQuality = 8, Color = Color3.fromRGB(200, 120, 255) },
	{ Id = "Starlight", Name = "Starlight Flask", Mult = 3.5, MinQuality = 11, Color = Color3.fromRGB(255, 240, 150) },
}

-- Weakening draughts are thrown to lower a guardian's resistance and slow it.
Config.DraughtIngredientCount = 2
Config.Draughts = {
	{ Id = "Weak", Name = "Weak Draught", Power = 18, MinQuality = 0, Color = Color3.fromRGB(120, 200, 120) },
	{ Id = "Strong", Name = "Strong Draught", Power = 30, MinQuality = 4, Color = Color3.fromRGB(60, 180, 200) },
	{ Id = "Potent", Name = "Potent Draught", Power = 45, MinQuality = 7, Color = Color3.fromRGB(230, 80, 160) },
}
Config.DraughtSlowSeconds = 6

-- Fusing a caught guardian with 3 ingredients grows it into a mutated form.
-- Index = the mutation level being reached.
Config.Mutations = {
	{ Prefix = "Giant", MinQuality = 5, Scale = 1.45, IncomeMult = 2.5 },
	{ Prefix = "Mutant", MinQuality = 8, Scale = 1.9, IncomeMult = 6 },
	{ Prefix = "Colossal", MinQuality = 11, Scale = 2.5, IncomeMult = 15 },
}

----------------------------------------------------------------------
-- Catching
----------------------------------------------------------------------
Config.Catch = {
	ThrowRange = 60,
	FeedRange = 18,
	ThrowCooldown = 1.0,
	FlightTime = 0.45,
	FavoriteMult = 2.0,
	StunnedMult = 1.5,
	SlowedMult = 1.25,
	BreakFreeResistance = 25, -- resistance regained when it bursts out
	EnragedSeconds = 10,
	CalmSeconds = 8, -- after being fed its favorite ingredient
	StunSeconds = 2.5,
	RegenPerSecond = 1.5, -- resistance regained when no player is near
	RegenDelay = 10,
}

Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(200, 200, 200) },
	Uncommon = { Order = 2, Color = Color3.fromRGB(110, 230, 120) },
	Rare = { Order = 3, Color = Color3.fromRGB(90, 160, 255) },
	Legendary = { Order = 4, Color = Color3.fromRGB(255, 190, 60) },
}

----------------------------------------------------------------------
-- Guardians
----------------------------------------------------------------------
-- Behavior: "Skittish" flees and slams when cornered, "Charger" telegraphs a
-- dash (lure it through hazards), "Caster" lobs orbs at your feet,
-- "Legendary" mixes all three.
-- Drop a model named after the id into ServerStorage.GuardianModels to
-- replace the built-in placeholder body (it needs a PrimaryPart).
Config.GuardianOrder = { "Mossling", "Thornback", "Cinderpup", "Magmaw", "Glimmerfox", "Aurorath" }

Config.Guardians = {
	Mossling = {
		Name = "Mossling", Element = "Nature", Zone = "Meadow", Rarity = "Common",
		BaseRate = 0.9, Favorite = "Sunpetal", Income = 2,
		Behavior = "Skittish", Speed = 13, Size = 4,
		Color = Color3.fromRGB(96, 170, 80), Accent = Color3.fromRGB(255, 214, 74),
		Attack = { Radius = 10, Damage = 10, Windup = 1.2, Cooldown = 4 },
		DodgeDrop = 12, HazardDrop = 22, Count = 4, Respawn = 25,
		Hint = "Turns its face toward anything that blooms in the sun.",
	},
	Thornback = {
		Name = "Thornback", Element = "Nature", Zone = "Meadow", Rarity = "Uncommon",
		BaseRate = 0.6, Favorite = "HoneydewRoot", Income = 5,
		Behavior = "Charger", Speed = 11, Size = 6,
		Color = Color3.fromRGB(70, 110, 60), Accent = Color3.fromRGB(150, 90, 50),
		Attack = { Length = 45, Width = 7, Damage = 18, Windup = 1.1, Cooldown = 5 },
		DodgeDrop = 10, HazardDrop = 25, Count = 2, Respawn = 45,
		Hint = "Digs for something sweet beneath the soil.",
	},
	Cinderpup = {
		Name = "Cinderpup", Element = "Fire", Zone = "Caldera", Rarity = "Common",
		BaseRate = 0.85, Favorite = "EmberPepper", Income = 4,
		Behavior = "Caster", Speed = 15, Size = 4,
		Color = Color3.fromRGB(230, 100, 50), Accent = Color3.fromRGB(255, 220, 90),
		Attack = { Radius = 7, Damage = 14, Windup = 1.3, Cooldown = 3.5, Orbs = 1 },
		DodgeDrop = 10, HazardDrop = 15, Count = 4, Respawn = 30,
		Hint = "Its breath smells of something spicy.",
	},
	Magmaw = {
		Name = "Magmaw", Element = "Fire", Zone = "Caldera", Rarity = "Rare",
		BaseRate = 0.3, Favorite = "Frostcap", Income = 14,
		Behavior = "Charger", Speed = 10, Size = 8,
		Color = Color3.fromRGB(60, 40, 40), Accent = Color3.fromRGB(255, 120, 30),
		Attack = { Length = 55, Width = 9, Damage = 26, Windup = 1.0, Cooldown = 4.5 },
		DodgeDrop = 8, HazardDrop = 20, Count = 1, Respawn = 90,
		Hint = "It is always too hot. It craves the opposite.",
	},
	Glimmerfox = {
		Name = "Glimmerfox", Element = "Ice", Zone = "Frost", Rarity = "Uncommon",
		BaseRate = 0.55, Favorite = "Moonberry", Income = 9,
		Behavior = "Skittish", Speed = 18, Size = 5,
		Color = Color3.fromRGB(200, 230, 255), Accent = Color3.fromRGB(170, 120, 255),
		Attack = { Radius = 11, Damage = 16, Windup = 1.0, Cooldown = 3.5 },
		DodgeDrop = 10, HazardDrop = 20, Count = 3, Respawn = 45,
		Hint = "Only comes out when the moon is up. So does its snack.",
	},
	Aurorath = {
		Name = "Aurorath", Element = "Spirit", Zone = "Frost", Rarity = "Legendary",
		BaseRate = 0.09, Favorite = "StarlightNectar", Income = 60,
		Behavior = "Legendary", Speed = 12, Size = 11,
		Color = Color3.fromRGB(120, 255, 220), Accent = Color3.fromRGB(255, 140, 240),
		Attack = { Radius = 14, Length = 60, Width = 10, Damage = 30, Windup = 1.1, Cooldown = 3, Orbs = 3 },
		DodgeDrop = 6, HazardDrop = 12, Count = 1, Respawn = 300,
		Hint = "Said to drink only what falls from the stars.",
		Announce = true,
	},
}

----------------------------------------------------------------------
-- World layout
----------------------------------------------------------------------
Config.HubRadius = 90
Config.PlotCount = 6
Config.PlotRadius = 150
Config.PlotSize = 60

Config.Zones = {
	Meadow = {
		Name = "Meadow Grove", Angle = 270, Distance = 420, Radius = 130,
		Floor = Color3.fromRGB(110, 180, 90), HazardName = "Bramble Patch",
		HazardColor = Color3.fromRGB(60, 90, 40), Hazards = 7, DecorKind = "Tree",
	},
	Caldera = {
		Name = "Ember Caldera", Angle = 30, Distance = 420, Radius = 130,
		Floor = Color3.fromRGB(90, 70, 65), HazardName = "Lava Vent",
		HazardColor = Color3.fromRGB(255, 110, 30), Hazards = 8, DecorKind = "Rock",
	},
	Frost = {
		Name = "Frost Hollow", Angle = 150, Distance = 420, Radius = 130,
		Floor = Color3.fromRGB(220, 235, 245), HazardName = "Ice Spikes",
		HazardColor = Color3.fromRGB(160, 220, 255), Hazards = 7, DecorKind = "Crystal",
	},
}
Config.ZoneOrder = { "Meadow", "Caldera", "Frost" }
Config.HazardRadius = 9
Config.HazardPlayerDamage = 8

-- Sound ids. The defaults are the few sounds built into the engine so the
-- place makes noise with nothing uploaded. Replace them with Creator Store
-- audio: in Studio open Toolbox > Audio, find a sound you like, right-click >
-- Copy Asset ID, and paste it here as "rbxassetid://<id>". Leave a slot as
-- "" for silence.
Config.Sounds = {
	Throw = "rbxasset://sounds/swoosh.wav", -- flask leaves your hand (try "whoosh")
	Shake = "rbxasset://sounds/clickfast.wav", -- each wobble (try "glass clink", "wood knock")
	Lock = "rbxasset://sounds/electronicpingshort.wav", -- caught! (try "success chime", "magic sparkle")
	Burst = "rbxasset://sounds/collide.wav", -- broke free (try "glass break", "pop")
	Brew = "rbxasset://sounds/button.wav", -- potion finished (try "bubble", "potion")
	Harvest = "", -- picking an ingredient (try "pluck", "pop")
	Coins = "", -- collecting / buying (try "coins", "cash register")
	Click = "", -- UI buttons (try "ui click")
	Music = "", -- looping background music (try "fantasy", "cozy")
}

----------------------------------------------------------------------
-- Helpers shared by client and server
----------------------------------------------------------------------
function Config.ZoneCenter(zoneId: string): Vector3
	local zone = Config.Zones[zoneId]
	local a = math.rad(zone.Angle)
	return Vector3.new(math.cos(a) * zone.Distance, 0, math.sin(a) * zone.Distance)
end

function Config.PlotCenter(index: number): Vector3
	local a = math.rad((index - 1) * (360 / Config.PlotCount))
	return Vector3.new(math.cos(a) * Config.PlotRadius, 0, math.sin(a) * Config.PlotRadius)
end

function Config.QualityOf(ingredientIds: { string }, potLevel: number?): number
	local q = 0
	for _, id in ingredientIds do
		local def = Config.Ingredients[id]
		if def then
			q += def.Tier
		end
	end
	return q + math.max((potLevel or 1) - 1, 0)
end

local function pickTier(list, quality)
	local best = list[1]
	for _, entry in list do
		if quality >= entry.MinQuality then
			best = entry
		end
	end
	return best
end

function Config.FlaskForQuality(quality: number)
	return pickTier(Config.Flasks, quality)
end

function Config.DraughtForQuality(quality: number)
	return pickTier(Config.Draughts, quality)
end

function Config.GetFlask(id: string)
	for _, f in Config.Flasks do
		if f.Id == id then
			return f
		end
	end
	return nil
end

function Config.GetDraught(id: string)
	for _, d in Config.Draughts do
		if d.Id == id then
			return d
		end
	end
	return nil
end

function Config.GetShopItem(id: string)
	for _, item in Config.Shop do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Config.GuardianIncome(entry): number
	local def = Config.Guardians[entry.Id]
	if not def then
		return 0
	end
	local mutation = Config.Mutations[entry.Mutation or 0]
	return def.Income * (mutation and mutation.IncomeMult or 1)
end

function Config.GuardianDisplayName(entry): string
	local def = Config.Guardians[entry.Id]
	local name = def and def.Name or entry.Id
	local mutation = Config.Mutations[entry.Mutation or 0]
	if mutation then
		return mutation.Prefix .. " " .. name
	end
	return name
end

return Config
