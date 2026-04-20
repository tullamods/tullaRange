--------------------------------------------------------------------------------
-- shared functions between the different implementations
--------------------------------------------------------------------------------

local _, Addon = ...
local SINGLE_BUTTON_ASSISTANT_SPELL_ID = 1229376
local SINGLE_BUTTON_ASSISTANT_NAME = C_Spell.GetSpellName(SINGLE_BUTTON_ASSISTANT_SPELL_ID)

function Addon.IsSingleButtonAssistantAction(slot)
    local actionType, id = GetActionInfo(slot)

    if actionType == "spell" then
        return id == SINGLE_BUTTON_ASSISTANT_SPELL_ID
    end

    if actionType == "macro" and id then
        local macroSpell = GetMacroSpell(id)
        return macroSpell == SINGLE_BUTTON_ASSISTANT_SPELL_ID or macroSpell == SINGLE_BUTTON_ASSISTANT_NAME
    end

    return false
end

function Addon.IsSingleButtonAssistantButton(button)
    if not button then
        return false
    end

    if type(button.UpdateAssistedCombatRotationFrame) == "function" then
        return true
    end

    return button.ActiveFrame ~= nil or button.InactiveTexture ~= nil
end

function Addon.GetActionState(slot)
    local actionType, id = GetActionInfo(slot)
    local isUsable, notEnoughMana

    -- for macros with names that start with a #, we prioritize the OOM
    -- check using a spell cost strategy over other ones to better
    -- clarify if the macro is actually usable or not
    if actionType == "macro" then
        local name = GetMacroInfo(id)
        if name and name:sub(1, 1) == "#" then
            local spellID = GetMacroSpell(id)
            if spellID then
                isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
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
    local isUsable, notEnoughMana

    if spellID then
        isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
    else
        isUsable = GetPetActionSlotUsable(index)
        notEnoughMana = false
    end

    if isUsable then
        return outOfRange and 'oor' or 'normal', outOfRange
    end

    return notEnoughMana and 'oom' or 'unusable', outOfRange
end
