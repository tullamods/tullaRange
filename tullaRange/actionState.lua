--------------------------------------------------------------------------------
-- shared functions between the different implementations
--------------------------------------------------------------------------------

local _, Addon = ...

function Addon.GetActionState(slot)
    local isUsable, notEnoughMana
    local actionType, id = GetActionInfo(slot)

    -- for macros with names that start with a #, we prioritize the OOM
    -- check using a spell cost strategy over other ones to better
    -- clarify if the macro is actually usable or not
    if actionType == "macro" then
        local name = GetMacroInfo(id)
        if name and name:sub(1, 1) == "#" then
            local spellID = GetMacroSpell(id)

            -- only run the check for spell macros
            if spellID then
                local costs = C_Spell.GetSpellPowerCost(spellID)
                if costs then
                    for i = 1, #costs do
                        local cost = costs[i]
                        if UnitPower("player", cost.type) < cost.minCost then
                            isUsable = false
                            notEnoughMana = true
                            break
                        end
                    end
                end
            end
        end
    end

    if isUsable == nil then
        isUsable, notEnoughMana = IsUsableAction(slot)
    end

    local outOfRange = IsActionInRange(slot) == false
    if isUsable then
        return outOfRange and 'oor' or 'normal', outOfRange
    end

    return notEnoughMana and 'oom' or 'unusable', outOfRange
end

function Addon.GetPetActionState(index)
    local _, _, _, _, _, _, spellID, checksRange, inRange = GetPetActionInfo(index)
    local outOfRange = checksRange and not inRange

    if spellID then
        local isUsable = C_Spell.IsSpellUsable(spellID)
        local notEnoughMana = false

        local costs = C_Spell.GetSpellPowerCost(spellID)
        if costs then
            for i = 1, #costs do
                local cost = costs[i]
                if UnitPower("pet", cost.type) < cost.minCost then
                    isUsable = false
                    notEnoughMana = true
                    break
                end
            end
        end

        if isUsable then
            return outOfRange and 'oor' or 'normal', outOfRange
        end

        return notEnoughMana and 'oom' or 'unusable', outOfRange
    end

    if GetPetActionSlotUsable(index) then
        return outOfRange and 'oor' or 'normal', outOfRange
    end

    return 'unusable', outOfRange
end
