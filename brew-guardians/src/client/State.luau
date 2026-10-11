-- Client-side copy of the player's data plus the selected action slot.

local State = {}

State.Data = nil :: any
-- { Kind = "Flask" | "Draught" | "Feed", Id = string }
State.Selected = { Kind = "Flask", Id = "Clay" }

local changed = Instance.new("BindableEvent")
local selectionChanged = Instance.new("BindableEvent")
State.Changed = changed.Event
State.SelectionChanged = selectionChanged.Event

function State.Set(data)
	State.Data = data
	changed:Fire(data)
end

function State.Select(kind: string, id: string)
	State.Selected = { Kind = kind, Id = id }
	selectionChanged:Fire(State.Selected)
end

-- How many of the selected item the player holds.
function State.SelectedCount(): number
	local data = State.Data
	if not data then
		return 0
	end
	local sel = State.Selected
	if sel.Kind == "Flask" then
		return data.Flasks[sel.Id] or 0
	elseif sel.Kind == "Draught" then
		return data.Draughts[sel.Id] or 0
	end
	return data.Ingredients[sel.Id] or 0
end

return State
