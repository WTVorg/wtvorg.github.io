-- Resolves UI icon keys to image content ids.
--
-- Keys: "Guardian_<Id>" (Config.GuardianOrder), "Ingredient_<Id>"
-- (Config.IngredientOrder), "Flask_<Id>" (Config.Flasks), "Draught_<Id>"
-- (Config.Draughts), "Coin", "Vial", "Cauldron", "Logo".
--
-- Icons.Get returns "rbxassetid://<imageId>" or nil when the icon isn't
-- uploaded yet; callers must fall back to their drawn icons.
-- (Stub: the publish pipeline work fills in the real resolution.)

local Icons = {}

function Icons.Get(_key: string): string?
	return nil
end

return Icons
