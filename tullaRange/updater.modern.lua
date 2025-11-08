--------------------------------------------------------------------------------
-- range check implementation (modern, event based)
--
-- In 10.1.5, Blizzard added in an event based API for notifying us when
-- action slots are in/out of range. We leverage that to avoid the need
-- for a constant loop to determine if abilities are in range or not
--------------------------------------------------------------------------------

if not ActionBarButtonRangeCheckFrame then return end

local _, Addon = ...

local states = {}
local registered = {}

--------------------------------------------------------------------------------
-- action button coloring
--------------------------------------------------------------------------------

local function actionButton_Update(button)
    -- icon coloring
    local iconState, outOfRange = Addon.GetActionState(button.action)
    local icon = button.icon

    states[icon] = iconState

    local iconColor = Addon.sets[iconState]
    icon:SetVertexColor(iconColor[1], iconColor[2], iconColor[3], iconColor[4])
    icon:SetDesaturated(iconColor.desaturate)

    -- hotkey coloring
    local hotkey = button.HotKey
    local hotkeyState = outOfRange and 'oor' or 'normal'

    states[hotkey] = hotkeyState

    local hotkeyColor = Addon.sets[hotkeyState]
    hotkey:SetVertexColor(hotkeyColor[1], hotkeyColor[2], hotkeyColor[3])
end

local function actionButton_UpdateRange(button, checksRange, inRange)
    if not registered[button] then return end

    local oor = checksRange and not inRange

    local icon = button.icon
    local iconState = states[icon]
    local newIconState

    if iconState == "normal" and oor then
        newIconState = "oor"
    elseif iconState == "oor" and not oor then
        newIconState = "normal"
    end

    if newIconState then
        states[icon] = newIconState

        local iconColor = Addon.sets[newIconState]
        icon:SetVertexColor(iconColor[1], iconColor[2], iconColor[3], iconColor[4])
        icon:SetDesaturated(iconColor.desaturate)
    end

    local hotkey = button.HotKey
    local hotkeyState = states[hotkey]
    local newHotkeyState

    if hotkeyState == "normal" and oor then
        newHotkeyState = "oor"
    elseif hotkeyState == "oor" and not oor then
        newHotkeyState = "normal"
    end

    if newHotkeyState then
        states[hotkey] = newHotkeyState

        local hotkeyColor = Addon.sets[newHotkeyState]
        hotkey:SetVertexColor(hotkeyColor[1], hotkeyColor[2], hotkeyColor[3])
    end
end

local function actionButton_Register(button)
    if not registered[button] then
        hooksecurefunc(button, "UpdateUsable", actionButton_Update)

        if Addon:HandleAttackAnimations() then
            button:HookScript("OnShow", Addon.UpdateAttackAnimation)
            button:HookScript("OnHide", Addon.UpdateAttackAnimation)
            hooksecurefunc(button, "StartFlash", Addon.StartAttackAnimation)
        end

        registered[button] = true
    end
end

--------------------------------------------------------------------------------
-- pet action button coloring
--------------------------------------------------------------------------------

local function petButton_Register(button)
    if not registered[button] then
        if Addon:HandleAttackAnimations() then
            hooksecurefunc(button, "StartFlash", Addon.StartAttackAnimation)
            button:HookScript("OnShow", Addon.UpdateAttackAnimation)
            button:HookScript("OnHide", Addon.UpdateAttackAnimation)
        end

        registered[button] = true
    end
end

local function petBar_Update(bar)
    if not PetHasActionBar() then return end

    local getState = Addon.GetPetActionState
    for index, button in pairs(bar.actionButtons) do
        if button.icon:IsVisible() then
            -- icon coloring
            local icon = button.icon
            local iconState, outOfRange = getState(index)

            states[icon] = iconState

            local iconColor = Addon.sets[iconState]
            icon:SetVertexColor(iconColor[1], iconColor[2], iconColor[3], iconColor[4])
            icon:SetDesaturated(iconColor.desaturate)
        end
    end
end

--------------------------------------------------------------------------------
-- engine implementation
--------------------------------------------------------------------------------

function Addon:Enable()
    -- register action buttons
    ActionBarButtonEventsFrame:ForEachFrame(actionButton_Register)
    hooksecurefunc(ActionBarButtonEventsFrame, "RegisterFrame", function(_, button)
        actionButton_Register(button)
    end)

    -- watch for range check events
    hooksecurefunc('ActionButton_UpdateRangeIndicator', actionButton_UpdateRange)

    -- disable the ActionBarButtonUpdateFrame OnUpdate handler - we don't actually need it
    ActionBarButtonUpdateFrame:SetScript("OnUpdate", nil)

    if self:HandlePetActions() then
        for _, button in pairs(PetActionBar.actionButtons) do
            petButton_Register(button)
        end

        hooksecurefunc(PetActionBar, "Update", petBar_Update)
        self.frame:RegisterUnitEvent('UNIT_POWER_UPDATE', 'pet')
    end

    self:RequestUpdate()
end

function Addon:UNIT_POWER_UPDATE()
    petBar_Update(PetActionBar)
end

function Addon:RequestUpdate()
    if not self.updateRequested then
        C_Timer.After(1 / 30, function()
            ActionBarButtonEventsFrame:ForEachFrame(actionButton_Update)

            if self:HandlePetActions() then
                petBar_Update(PetActionBar)
            end

            self.updateRequested = nil
        end)

        self.updateRequested = true
    end
end
