--------------------------------------------------------------------------------
-- range check implementation (classic, polling based)
--
-- Prior to 10.1.5, there's no API that lets us know when actions are in/out
-- of range. So we need to check every frame to see
--
-- The general idea for this approach comes from the addon RedRange.
--------------------------------------------------------------------------------

if type(ActionBarButtonEventsFrame_RegisterFrame) ~= "function" then return end

local _, Addon = ...

-- registered action and pet buttons
local actionButtons = {}
local petButtons = {}

-- buttons we should periodically check ranges on
local watchedActionButtons = {}
local watchedPetButtons = {}

-- current states for each button
local states = {}

--------------------------------------------------------------------------------
-- core update loop
--------------------------------------------------------------------------------

local function update()
	-- update actions
	local getActionState = Addon.GetActionState
	for button in pairs(watchedActionButtons) do
		local usable, oom, oor = getActionState(button.action)

		local iconState
		if usable then
			iconState = "normal"
		elseif oom then
			iconState = "oom"
		elseif oor then
			iconState = "oor"
		else
			iconState = "unusable"
		end

		local icon = button.icon
		if states[icon] ~= iconState then
			states[icon] = iconState

			local r, g, b, a, desaturate = Addon:GetColor(iconState)
			icon:SetDesaturated(desaturate)
			icon:SetVertexColor(r, g, b, a)
		end

		local hotkeyState
		if oor then
			hotkeyState = "oor"
		else
			hotkeyState = "normal"
		end

		local hotkey = button.HotKey
		if states[hotkey] ~= hotkeyState then
			states[hotkey] = hotkeyState

			local r, g, b = Addon:GetColor(hotkeyState)
			hotkey:SetVertexColor(r, g, b)
		end
	end

	-- update pet actions
	local getPetActionState = Addon.GetPetActionState
	for button in pairs(watchedPetButtons) do
		local usable, oom, oor = getPetActionState(button:GetID())

		local iconState
		if usable then
			iconState = "normal"
		elseif oom then
			iconState = "oom"
		elseif oor then
			iconState = "oor"
		else
			iconState = "unusable"
		end

		local icon = button.icon
		if states[icon] ~= iconState then
			states[icon] = iconState

			local r, g, b, a, desaturate = Addon:GetColor(iconState)
			icon:SetDesaturated(desaturate)
			icon:SetVertexColor(r, g, b, a)
		end

		local hotkeyState
		if oor then
			hotkeyState = "oor"
		else
			hotkeyState = "normal"
		end

		local hotkey = button.HotKey
		if states[hotkey] ~= hotkeyState then
			states[hotkey] = hotkeyState

			local r, g, b = Addon:GetColor(hotkeyState)
			hotkey:SetVertexColor(r, g, b)
		end
	end
end

local ticker = nil
local function updateRangeChecker()
	if next(watchedActionButtons) or next(watchedPetButtons) then
		if not ticker then
			ticker = C_Timer.NewTicker(Addon:GetUpdateDelay(), update)
		end
	elseif ticker then
		ticker:Cancel()
		ticker = nil
	end
end

--------------------------------------------------------------------------------
-- action button handling
--------------------------------------------------------------------------------

-- returns true if the given action button should be watched (due to having a
-- range component and being visible) and false otherwise
local function shouldWatchAction(button)
	return button:IsVisible() and ActionHasRange(button.action or 0)
end

local function actionButton_UpdateWatched(button)
	-- we want a true or nil value here for storage
	-- this helps reduce the amount of things we need to loop through in
	-- watchedActionButtons
	local state = shouldWatchAction(button) or nil

	if state ~= watchedActionButtons[button]  then
		watchedActionButtons[button] = state
		updateRangeChecker()
	end
end

local function actionButton_UpdateColor(button)
	local usable, oom, oor = Addon.GetActionState(button.action)

	-- icon coloring
	local iconState
	if usable then
		iconState = "normal"
	elseif oom then
		iconState = "oom"
	elseif oor then
		iconState = "oor"
	else
		iconState = "unusable"
	end

	local icon = button.icon
	states[icon] = iconState

	local r, g, b, a, desaturate = Addon:GetColor(iconState)
	icon:SetDesaturated(desaturate)
	icon:SetVertexColor(r, g, b, a)

	-- hotkey coloring
	local hotkeyState
	if oor then
		hotkeyState = "oor"
	else
		hotkeyState = "normal"
	end

	local hotkey = button.HotKey
	states[hotkey] = hotkeyState

	r, g, b = Addon:GetColor(hotkeyState)
	hotkey:SetVertexColor(r, g, b)
end

local function registerActionButton(button)
	if actionButtons[button] then return end

	button:SetScript("OnUpdate", nil)
	button:HookScript("OnShow", actionButton_UpdateWatched)
	button:HookScript("OnHide", actionButton_UpdateWatched)

	actionButton_UpdateColor(button)
	actionButton_UpdateWatched(button)

	if Addon:HandleAttackAnimations() then
		button:HookScript("OnShow", Addon.UpdateAttackAnimation)
		button:HookScript("OnHide", Addon.UpdateAttackAnimation)

		Addon.UpdateAttackAnimation(button)
	end

	actionButtons[button] = true
end

--------------------------------------------------------------------------------
-- pet action button handling
--------------------------------------------------------------------------------

-- returns true if the given pet action button should be watched (due to having
-- a range component and being visible) and false otherwise
local function shouldWatchPetAction(button)
	if button:IsVisible() then
		local _, _, _, _, _, _, _, hasRange = GetPetActionInfo(button:GetID())
		return hasRange
	end

	return false
end

local function petButton_OnShowHide(button)
	local state = shouldWatchPetAction(button) or nil

	if state ~= watchedPetButtons[button]  then
		watchedPetButtons[button] = state
		updateRangeChecker()
	end

	Addon.UpdateAttackAnimation(button)
end

local function petButton_UpdateColor(button)
	local usable, oom, oor = Addon.GetPetActionState(button:GetID())

	local iconState
	if usable then
		iconState = "normal"
	elseif oom then
		iconState = "oom"
	elseif oor then
		iconState = "oor"
	else
		iconState = "unusable"
	end

	local icon = button.icon
	states[icon] = iconState

	local r, g, b, a, desaturate = Addon:GetColor(iconState)
	icon:SetDesaturated(desaturate)
	icon:SetVertexColor(r, g, b, a)

	local hotkeyState
	if oor then
		hotkeyState = "oor"
	else
		hotkeyState = "normal"
	end

	local hotkey = button.HotKey
	states[hotkey] = hotkeyState

	r, g, b = Addon:GetColor(hotkeyState)
	hotkey:SetVertexColor(r, g, b)
end

local function registerPetButton(button)
	if petButtons[button] then return end

	button:SetScript("OnUpdate", nil)
	button:HookScript("OnShow", petButton_OnShowHide)
	button:HookScript("OnHide", petButton_OnShowHide)

	petButton_UpdateColor(button)
	petButton_OnShowHide(button)

	petButtons[button] = true
end

local function petActionBar_Update(bar)
	-- reset the timer on update, so that we don't trigger the bar's
	-- own range updater code
	(bar or PetActionBarFrame).rangeTimer = nil

	-- if we have a bar, update all the actions
	if PetHasActionBar() then
		for button in pairs(petButtons) do
			petButton_UpdateColor(button)
			watchedPetButtons[button] = shouldWatchPetAction(button) or nil
		end
	else
		-- if we don't, wipe any actions we currently are showing
		wipe(watchedPetButtons)
	end

	updateRangeChecker()
end

--------------------------------------------------------------------------------
-- engine implementation
--------------------------------------------------------------------------------

-- start handling range and usability checking
function Addon:Enable()
	-- handle action buttons
	for _,  frame in pairs(ActionBarButtonEventsFrame.frames) do
		registerActionButton(frame)
	end

	hooksecurefunc("ActionBarButtonEventsFrame_RegisterFrame", registerActionButton)

	-- ActionButton_UpdateUsable is called when the button normally changes
	-- color when unusable, so we need to reapply our custom coloring at this
	-- point
	hooksecurefunc("ActionButton_UpdateUsable", actionButton_UpdateColor)

	-- ActionButton_Update is called whenever an action button changes, so we
	-- check here to we if we need to pay attention to the button anymore or not
	hooksecurefunc("ActionButton_Update", actionButton_UpdateWatched)

	if self:HandleAttackAnimations() then
		hooksecurefunc("ActionButton_StartFlash", Addon.StartAttackAnimation)
	end

	if self:HandlePetActions() then
		-- register all pet action buttons
		for i = 1, NUM_PET_ACTION_SLOTS do
			local button = _G["PetActionButton" .. i]

			if button then
				registerPetButton(button)
			end
		end

		hooksecurefunc("PetActionBar_Update", petActionBar_Update)

		if self:HandleAttackAnimations() then
			hooksecurefunc("PetActionButton_StartFlash", Addon.StartAttackAnimation)
		end

		updateRangeChecker()
	end
end

function Addon:RequestUpdate()
	for button in pairs(actionButtons) do
		if button:IsVisible() then
			actionButton_UpdateColor(button)
		end
	end

	for button in pairs(petButtons) do
		if button:IsVisible() then
			petButton_UpdateColor(button)
		end
	end
end
