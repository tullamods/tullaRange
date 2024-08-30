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
	do
		states[icon] = iconState

		local color = Addon.sets[iconState]
		icon:SetVertexColor(color[1], color[2], color[3], color[4])
		icon:SetDesaturated(color.desaturate)
	end

	-- hotkey coloring
	local hotkeyState
	if oor then
		hotkeyState = "oor"
	else
		hotkeyState = "normal"
	end

	local hotkey = button.HotKey
	do
		states[hotkey] = hotkeyState

		local color = Addon.sets[hotkeyState]
		button.HotKey:SetVertexColor(color[1], color[2], color[3])
	end
end

local function registerActionButton(button)
	if registered[button] then return end

	hooksecurefunc(button, "UpdateUsable", actionButton_UpdateColor)	

	if Addon:HandleAttackAnimations() then
		button:HookScript("OnShow", Addon.UpdateAttackAnimation)
		button:HookScript("OnHide", Addon.UpdateAttackAnimation)
		hooksecurefunc(button, "StartFlash", Addon.StartAttackAnimation)
	end

	registered[button] = true
end

--------------------------------------------------------------------------------
-- pet action button coloring
-- This, unfortunately, still requires polling
--------------------------------------------------------------------------------

local watchedPetButtons = {}

-- update pet actions
local function update()
	local getPetActionState = Addon.GetPetActionState
	local colors = Addon.sets

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

			local color = colors[iconState]
			icon:SetVertexColor(color[1], color[2], color[3], color[4])
			icon:SetDesaturated(color.desaturate)
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

			local color = colors[hotkeyState]
			hotkey:SetVertexColor(color[1], color[2], color[3])
		end
	end
end

local ticker = nil
local function updatePetRangeChecker()
	if next(watchedPetButtons) then
		if not ticker then
			ticker = C_Timer.NewTicker(Addon:GetUpdateDelay(), update)
		end
	elseif ticker then
		ticker:Cancel()
		ticker = nil
	end
end

-- returns true if the given pet action button should be watched (due to having
-- a range component and being visible) and false otherwise
local function shouldWatchPetAction(button)
	if button:IsVisible() then
		local _, _, _, _, _, _, _, hasRange = GetPetActionInfo(button:GetID())
		return hasRange
	end

	return false
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
	do
		states[icon] = iconState

		local color = Addon.sets[iconState]
		icon:SetVertexColor(color[1], color[2], color[3], color[4])
		icon:SetDesaturated(color.desaturate)
	end

	local hotkeyState
	if oor then
		hotkeyState = "oor"
	else
		hotkeyState = "normal"
	end

	local hotkey = button.HotKey
	do
		states[hotkey] = hotkeyState

		local color = Addon.sets[hotkeyState]
		button.HotKey:SetVertexColor(color[1], color[2], color[3])
	end
end

local function petButton_UpdateWatched(button)
	local state = shouldWatchPetAction(button) or nil

	if state ~= watchedPetButtons[button] then
		watchedPetButtons[button] = state
		updatePetRangeChecker()
	end
end

local function registerPetButton(button)
	if registered[button] then return end

	button:SetScript("OnUpdate", nil)
	button:HookScript("OnShow", petButton_UpdateWatched)
	button:HookScript("OnHide", petButton_UpdateWatched)

	if Addon:HandleAttackAnimations() then
		hooksecurefunc(button, "StartFlash", Addon.StartAttackAnimation)
		button:HookScript("OnShow", Addon.UpdateAttackAnimation)
		button:HookScript("OnHide", Addon.UpdateAttackAnimation)
	end

	registered[button] = true
end

--------------------------------------------------------------------------------
-- engine implementation
--------------------------------------------------------------------------------

function Addon:Enable()
	-- register known action buttons
	for _, button in pairs(ActionBarButtonEventsFrame.frames) do
		registerActionButton(button)
	end

	-- and watch for any additional action buttons
	hooksecurefunc(ActionBarButtonEventsFrame, "RegisterFrame", function(_, button)
		registerActionButton(button)
	end)

	-- disable the ActionBarButtonUpdateFrame OnUpdate handler (unneeded)
	ActionBarButtonUpdateFrame:SetScript("OnUpdate", nil)

	-- watch for range event updates
	self.frame:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")

	if self:HandlePetActions() then
		-- register all pet action buttons
		for _, button in pairs(PetActionBar.actionButtons) do
			registerPetButton(button)
		end

		hooksecurefunc(PetActionBar, "Update", function(bar)
			-- reset the timer on update, so that we don't trigger the bar's
			-- own range updater code
			bar.rangeTimer = nil

			-- if we have a bar, update all the actions
			if PetHasActionBar() then
				for _, button in pairs(bar.actionButtons) do
					if button.icon:IsVisible() then
						petButton_UpdateColor(button)
					end

					petButton_UpdateWatched(button)
				end
			else
				wipe(watchedPetButtons)
				updatePetRangeChecker()
			end
		end)
	end
end

function Addon:RequestUpdate()
	for _, buttons in pairs(ActionBarButtonRangeCheckFrame.actions) do
		for _, button in pairs(buttons) do
			if button:IsVisible() then
				actionButton_UpdateColor(button)
			end
		end
	end

	for _, button in pairs(PetActionBar.actionButtons) do
		if button:IsVisible() then
			petButton_UpdateColor(button)
		end
	end
end

function Addon:ACTION_RANGE_CHECK_UPDATE(_, slot, isInRange, checksRange)
	local buttons = ActionBarButtonRangeCheckFrame.actions[slot]
	if not buttons then
		return
	end

	local oor = checksRange and not isInRange
	if oor then
		local newState = "oor"
		local color = Addon.sets[newState]

		for _, button in pairs(buttons) do
			local icon = button.icon
			if states[icon] ~= newState then
				states[icon] = newState
	
				icon:SetVertexColor(color[1], color[2], color[3], color[4])
				icon:SetDesaturated(color.desaturate)
			end
	
			local hotkey = button.HotKey
			if states[hotkey] == newState then
				states[hotkey] = newState
				hotkey:SetVertexColor(color[1], color[2], color[3])
			end
		end
	else
		local oldState = "oor"

		for _, button in pairs(buttons) do
			local icon = button.icon
			if states[icon] == oldState then
				local usable, oom = Addon.GetActionState(button.action)
				
				local newState
				if usable then
					newState = "normal"
				elseif oom then
					newState = "oom"
				else
					newState = "unusable"
				end
			
				states[icon] = newState
	
				local color = Addon.sets[newState]
				icon:SetVertexColor(color[1], color[2], color[3], color[4])
				icon:SetDesaturated(color.desaturate)
			end
	
			local hotkey = button.HotKey
			if states[hotkey] == oldState then
				states[hotkey] = "normal"
	
				local color = Addon.sets["normal"]
				hotkey:SetVertexColor(color[1], color[2], color[3])
			end
		end		
	end
end
