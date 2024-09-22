--------------------------------------------------------------------------------
-- shared functions between the different implementations
--------------------------------------------------------------------------------

local _, Addon = ...

local function isUsuableAction(slot)
	local actionType, id = GetActionInfo(slot)

	if actionType == "macro" then
		-- for macros with names that start with a #, we prioritize the OOM
		-- check using a spell cost strategy over other ones to better
		-- clarify if the macro is actually usable or not
		local name = GetMacroInfo(id)

		if name and name:sub(1, 1) == "#" then
			local spellID = GetMacroSpell(id)

			-- only run the check for spell macros
			if spellID then
				local costs = (GetSpellPowerCost or C_Spell.GetSpellPowerCost)(spellID)
				if costs then
					for i = 1, #costs do
						local cost = costs[i]

						if UnitPower("player", cost.type) < cost.minCost then
							return false, false
						end
					end
				end
			end
		end
	end

	return IsUsableAction(slot)
end

function Addon.GetActionState(slot)
	local usable, oom = isUsuableAction(slot)
	local oor = IsActionInRange(slot) == false

	return usable and not oor, oom, oor
end

function Addon.GetPetActionState(slot)
	local _, _, _, _, _, _, spellID, checksRange, inRange = GetPetActionInfo(slot)
	local oor = checksRange and not inRange

	if spellID then
		local _, oom = (IsUsableSpell or C_Spell.IsSpellUsable)(spellID)
		if oom then
			return false, oom, oor
		end
	end

	return (not oor) and GetPetActionSlotUsable(slot), false, oor
end
