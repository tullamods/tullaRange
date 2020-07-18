--------------------------------------------------------------------------------
-- tullaRange
-- Adds out of range coloring to action buttons
-- Derived from RedRange with negligable improvements to CPU usage
--------------------------------------------------------------------------------

local AddonName = ...

-- the addon event handler
local Addon = CreateFrame('Frame', AddonName, _G.InterfaceOptionsFrame)

-- how quickly attack actions flash
local ATTACK_BUTTON_FLASH_TIME = _G.ATTACK_BUTTON_FLASH_TIME

-- the name of the database
local DB_KEY = 'TULLARANGE_COLORS'

-- how frequently we want to update colors, in seconds
local UPDATE_DELAY = 0.2

local ActionHasRange = _G.ActionHasRange
local After = _G.C_Timer.After
local GetTime = _G.GetTime
local IsActionInRange = _G.IsActionInRange
local IsUsableAction = _G.IsUsableAction
local GetPetActionInfo = _G.GetPetActionInfo
local GetPetActionSlotUsable = _G.GetPetActionSlotUsable

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

-- addon intially loaded
function Addon:OnLoad()
    -- a table for the action buttons we want to periodically check the range of
    self.watchedActions = {}

    -- a table for the action buttons we want to periodically check the ranges of
    self.watchedPetActions = {}

    -- a table for all of the known action button states
    self.buttonStates = {}

    -- setup script handlers
    self:SetScript('OnShow', self.OnShow)
    self:SetScript('OnEvent', self.OnEvent)

    -- register any events we need to watch
    self:RegisterEvent('ADDON_LOADED')
    self:RegisterEvent('PLAYER_LOGIN')
    self:RegisterEvent('PLAYER_LOGOUT')

    -- drop this method, as we won't need it again
    self.OnLoad = nil
end

-- addon shown (which in this case means that InterfaceOptionsFrame was shown)
-- load the config addon and get rid of this method
function Addon:OnShow()
    LoadAddOn(AddonName .. '_Config')

    -- drop this method, as we won't need it again
    self:SetScript('OnShow', nil)
    self.OnShow = nil
end

function Addon:OnEvent(event, ...)
    local func = self[event]

    if func then
        func(self, event, ...)
    end
end

-- when the addon finishes loading...
function Addon:ADDON_LOADED(event, addonName)
    if addonName ~= AddonName then
        return
    end

    -- setup our saved settings stuff
    self:SetupDatabase()

    -- get rid of the handler, as we don't need it anymore
    self:UnregisterEvent(event)
    self[event] = nil
end

-- when the player first logs in...
function Addon:PLAYER_LOGIN(event)
    local function actionButton_OnVisibilityChanged(button)
        self:UpdateActionButtonWatched(button)
        self:UpdateButtonFlashing(button)
    end

    local function petActionButton_OnVisibilityChanged(button)
        self:UpdatePetActionButtonWatched(button)
        self:UpdateButtonFlashing(button)
    end

    -- hook any action button events we need to take care of
    -- register events on update initially, and wipe out their individual on
    -- update handlers. This is why tullaRange has a negative performance
    -- impact
    hooksecurefunc(
        'ActionButton_OnUpdate',
        function(button)
            button:SetScript('OnUpdate', nil)
            button:HookScript('OnShow', actionButton_OnVisibilityChanged)
            button:HookScript('OnHide', actionButton_OnVisibilityChanged)

            self:UpdateActionButtonWatched(button)
        end
    )

    -- ActionButton_UpdateUsable is called when the button normally changes
    -- color when unusuable, so we need to reapply our custom coloring at this
    -- point
    hooksecurefunc(
        'ActionButton_UpdateUsable',
        function(button)
            self:UpdateActionButtonState(button, true)
        end
    )

    -- ActionButton_Update is called whenever an action button changes, so we
    -- check here to we if we need to pay attention to the button anymore or not
    hooksecurefunc(
        'ActionButton_Update',
        function(button)
            self:UpdateActionButtonWatched(button)
        end
    )

    -- check to see if we're coloring pet actions
    if self:EnablePetActions() then
        self.petActions = {}
        for i = 1, NUM_PET_ACTION_SLOTS do
            tinsert(self.petActions, _G['PetActionButton' .. i])
        end

        -- hook any pet button events we need to take care of
        -- register events on update initially, and wipe out their individual on
        -- update handlers. This is why tullaRange has a negative performance
        -- impact
        hooksecurefunc(
            'PetActionButton_OnUpdate',
            function(button)
                button:SetScript('OnUpdate', nil)
                button:HookScript('OnShow', petActionButton_OnVisibilityChanged)
                button:HookScript('OnHide', petActionButton_OnVisibilityChanged)
                self:UpdatePetActionButtonWatched(button)
            end
        )

        hooksecurefunc(
            'PetActionBar_Update',
            function(bar)
                -- reset the timer on update, so that we don't trigger the bar's
                -- own range updater code
                bar.rangeTimer = nil

                -- if we have a bar, update all the actions
                if PetHasActionBar() then
                    for _, button in pairs(self.petActions) do
                        -- clear our current styling
                        self.buttonStates[button] = nil
                        self:UpdatePetActionButtonWatched(button)
                    end
                -- if we don't, wipe any actions we currently are showing
                else
                    wipe(self.watchedPetActions)
                end
            end
        )
    end

    -- we've enabled flash animations, hook the stuff we need to
    if self:EnableFlashAnimations() then
        -- a table for all of the flash animations we may create
        self.flashAnimations = {}

        -- hook stop/start flashing functions
        -- we use animations for this instead of on update handlers
        hooksecurefunc(
            'ActionButton_StartFlash',
            function(button)
                if not button:IsVisible() then
                    return
                end

                self:StartButtonFlashing(button)
            end
        )

        if self:EnablePetActions() then
            hooksecurefunc(
                'PetActionButton_StartFlash',
                function(button)
                    if not button:IsVisible() then
                        return
                    end

                    self:StartButtonFlashing(button)
                end
            )
        end
    end

    -- get rid of the handler, as we don't need it anymore
    self:UnregisterEvent(event)
    self[event] = nil
end

function Addon:PLAYER_LOGOUT()
    self:CleanupDatabase()
end

--------------------------------------------------------------------------------
-- Update API
--------------------------------------------------------------------------------

local function handleUpdate()
    if Addon:UpdateButtonStates() then
        Addon.updating = GetTime()
        After(UPDATE_DELAY, handleUpdate)
    else
        Addon.updating = nil
    end
end

function Addon:RequestUpdate()
    if self.updating ~= nil then
        return
    end

    self.updating = GetTime()
    After(UPDATE_DELAY, handleUpdate)
end

function Addon:SetButtonState(button, state, force)
    if self.buttonStates[button] == state and not force then
        return
    end

    self.buttonStates[button] = state

    local r, g, b, a = self:GetColor(state)

    button.icon:SetVertexColor(r, g, b, a)
end

function Addon:UpdateButtonStates(force)
    local updatedButtons = false

    if next(self.watchedActions) then
        for button in pairs(self.watchedActions) do
            self:UpdateActionButtonState(button, force)
        end

        updatedButtons = true
    end

    if next(self.watchedPetActions) then
        for button in pairs(self.watchedPetActions) do
            self:UpdatePetActionButtonState(button, force)
        end

        updatedButtons = true
    end

    return updatedButtons
end

-- action button specific methods

-- gets the current state of the action button
function Addon:GetActionButtonState(button)
    local action = button.action
    local isUsable, notEnoughMana = IsUsableAction(action)
    local inRange = IsActionInRange(action)

    -- usable (ignoring target information)
    if isUsable then
        -- but out of range
        if inRange == false then
            return 'oor'
        else
            return 'normal'
        end
    elseif notEnoughMana then
        return 'oom'
    else
        return 'unusable'
    end
end

function Addon:UpdateActionButtonState(button, force)
    self:SetButtonState(button, self:GetActionButtonState(button), force)
end

function Addon:UpdateActionButtonWatched(button)
    local action = button.action

    if action and button:IsVisible() and ActionHasRange(action) then
        self.watchedActions[button] = true
    else
        self.watchedActions[button] = nil
    end

    self:RequestUpdate()
end

-- pet action button specific stuff
function Addon:GetPetActionButtonState(button)
    local slot = button:GetID() or 0
    local _, _, _, _, _, _, _, checksRange, inRange = GetPetActionInfo(slot)
    local isUsable, notEnoughMana = GetPetActionSlotUsable(slot)

    -- usable (ignoring target information)
    if isUsable then
        -- but out of range
        if checksRange and not inRange then
            return 'oor'
        else
            return 'normal'
        end
    elseif notEnoughMana then
        return 'oom'
    else
        return 'unusable'
    end
end

function Addon:UpdatePetActionButtonState(button, force)
    self:SetButtonState(button, self:GetPetActionButtonState(button), force)
end

function Addon:UpdatePetActionButtonWatched(button)
    local slot = button:GetID() or 0
    local _, _, _, _, _, _, _, checksRange = GetPetActionInfo(slot)

    if button:IsVisible() and checksRange then
        self.watchedPetActions[button] = true
    else
        self.watchedPetActions[button] = nil
    end

    self:RequestUpdate()
end

--------------------------------------------------------------------------------
-- Flashing replacement
--------------------------------------------------------------------------------

local function alpha_OnFinished(self)
    local owner = self.owner

    if owner.flashing ~= 1 then
        Addon:StopButtonFlashing(owner)
    end
end

function Addon:StartButtonFlashing(button)
    local animation = self.flashAnimations[button]

    if not animation then
        animation = button.Flash:CreateAnimationGroup()
        animation:SetLooping('BOUNCE')

        local alpha = animation:CreateAnimation('ALPHA')

        alpha:SetDuration(self:GetFlashDuration())
        alpha:SetFromAlpha(0)
        alpha:SetToAlpha(1)
        alpha:SetScript('OnFinished', alpha_OnFinished)

        alpha.owner = button

        self.flashAnimations[button] = animation
    end

    button.Flash:Show()
    animation:Play()
end

function Addon:StopButtonFlashing(button)
    local animation = self.flashAnimations[button]

    if animation then
        animation:Stop()
        button.Flash:Hide()
    end
end

function Addon:UpdateButtonFlashing(button)
    if button.flashing == 1 and button:IsVisible() then
        self:StartButtonFlashing(button)
    else
        self:StopButtonFlashing(button)
    end
end

--------------------------------------------------------------------------------
-- Saved settings setup stuff
--------------------------------------------------------------------------------

local function removeDefaults(tbl, defaults)
    for k, v in pairs(defaults) do
        if type(tbl[k]) == 'table' and type(v) == 'table' then
            removeDefaults(tbl[k], v)
            if next(tbl[k]) == nil then
                tbl[k] = nil
            end
        elseif tbl[k] == v then
            tbl[k] = nil
        end
    end

    return tbl
end

local function copyDefaults(tbl, defaults)
    for k, v in pairs(defaults) do
        if type(v) == 'table' then
            tbl[k] = copyDefaults(tbl[k] or {}, v)
        elseif tbl[k] == nil then
            tbl[k] = v
        end
    end

    return tbl
end

function Addon:SetupDatabase()
    local sets = _G[DB_KEY]

    if not sets then
        sets = {}
        _G[DB_KEY] = sets
    end

    self.sets = copyDefaults(sets, self:GetDatabaseDefaults())
end

function Addon:CleanupDatabase()
    local sets = self.sets

    if sets then
        removeDefaults(sets, self:GetDatabaseDefaults())
    end
end

function Addon:GetDatabaseDefaults()
    return {
        -- enable range coloring on pet actions
        petActions = true,

        -- enable flash animations,
        flashAnimations = true,
        flashDuration = ATTACK_BUTTON_FLASH_TIME * 1.5,

        -- default color (r, g, b, a)
        normal = {1, 1, 1, 1},
        -- out of range
        oor = {1, 0.3, 0.1, 1},
        -- out of mana
        oom = {0.1, 0.3, 1, 1},
        -- unusable action
        unusable = {0.4, 0.4, 0.4, 1}
    }
end

function Addon:ResetDatabase()
    _G[DB_KEY] = nil

    self:SetupDatabase()
    self:UpdateButtonStates(true)
end

--------------------------------------------------------------------------------
-- Configuration API
--------------------------------------------------------------------------------

function Addon:GetColor(state)
    local color = self.sets[state]

    return color[1], color[2], color[3], color[4]
end

function Addon:SetColor(state, r, g, b, a)
    local color = self.sets[state]

    color[1] = r
    color[2] = g
    color[3] = b
    color[4] = a or 1

    self:UpdateButtonStates(true)
end

-- gets or sets enabling action button flashing
function Addon:EnableFlashAnimations()
    return self.sets.flashAnimations
end

function Addon:SetEnableFlashAnimations(enable)
    self.sets.flashAnimations = enable
end

-- sets the flash animation speed
function Addon:GetFlashDuration()
    return self.sets.flashDuration
end

function Addon:SetFlashDuration(duration)
    self.sets.flashDuration = tonumber(duration)
end

-- gets or sets enabling out of range  coloring on pet actions
function Addon:EnablePetActions()
    return self.sets.petActions
end

function Addon:SetEnablePetActions(enable)
    self.sets.petActions = enable
end

-- load the addon
Addon:OnLoad()
