-- Catch odds and the timing of the shake sequence. Shared so the client can
-- preview odds and play the sequence in lockstep with the server.

local Config = require(script.Parent.Config)

local CatchMath = {}

CatchMath.Shakes = 3
CatchMath.LandTime = 0.7 -- flask lands and swallows the guardian
CatchMath.ShakeInterval = 1.15 -- each shake (the burst happens during a shake)
CatchMath.ResultTime = 0.6 -- lock flash after the final shake

export type ChanceParams = {
	BaseRate: number,
	FlaskMult: number,
	Resistance: number, -- 0..100
	FedFavorite: boolean?,
	Stunned: boolean?,
	Slowed: boolean?,
	Luck: number?,
}

-- Same shape as the classic formula: a guardian at full resistance is three
-- times harder to catch than one worn all the way down.
function CatchMath.Chance(p: ChanceParams): number
	local resistance = math.clamp(p.Resistance, 0, 100) / 100
	local chance = p.BaseRate * p.FlaskMult * (3 - 2 * resistance) / 3
	if p.FedFavorite then
		chance *= Config.Catch.FavoriteMult
	end
	if p.Stunned then
		chance *= Config.Catch.StunnedMult
	elseif p.Slowed then
		chance *= Config.Catch.SlowedMult
	end
	chance *= p.Luck or 1
	return math.clamp(chance, 0.01, 1)
end

-- Each shake is an independent check. Passing all of them equals the overall
-- chance, so a near miss on the last shake is common and honest.
function CatchMath.ShakeChance(chance: number): number
	return chance ^ (1 / CatchMath.Shakes)
end

-- Returns how many shakes passed. Shakes == CatchMath.Shakes means caught.
function CatchMath.Roll(chance: number, rng: Random): number
	local perShake = CatchMath.ShakeChance(chance)
	for i = 1, CatchMath.Shakes do
		if rng:NextNumber() >= perShake then
			return i - 1
		end
	end
	return CatchMath.Shakes
end

function CatchMath.Duration(shakesPassed: number): number
	if shakesPassed >= CatchMath.Shakes then
		return CatchMath.LandTime + CatchMath.Shakes * CatchMath.ShakeInterval + CatchMath.ResultTime
	end
	-- It bursts out during shake number shakesPassed + 1.
	return CatchMath.LandTime + (shakesPassed + 1) * CatchMath.ShakeInterval
end

return CatchMath
