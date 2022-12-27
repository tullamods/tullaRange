
--------------------------------------------------------------------------------
-- tullaRange
-- Adds out of range coloring to action buttons
-- Derived from RedRange with negligable improvements to CPU usage
--------------------------------------------------------------------------------

local AddonName = ...

local _G, next, pairs, ipairs, type = _G, next, pairs, ipairs, type
local tinsert, wipe, hooksecurefunc = tinsert, wipe, hooksecurefunc
local NUM_PET_ACTION_SLOTS, ATTACK_BUTTON_FLASH_TIME = NUM_PET_ACTION_SLOTS, ATTACK_BUTTON_FLASH_TIME

local ActionHasRange = _G.ActionHasRange
local IsActionInRange = _G.IsActionInRange
local IsUsableAction = _G.IsUsableAction
local GetPetActionInfo = _G.GetPetActionInfo
local GetPetActionSlotUsable = _G.GetPetActionSlotUsable
local GetActionInfo = _G.GetActionInfo
local GetMacroInfo = _G.GetMacroInfo
local GetMacroSpell = _G.GetMacroSpell
local GetSpellPowerCost = _G.GetSpellPowerCost
local UnitPower = _G.UnitPower
local PetHasActionBar = _G.PetHasActionBar
local EnumerateFrames = _G.EnumerateFrames
local LoadAddOn = _G.LoadAddOn

-- the name of the database
local DB_KEY = "TULLARANGE_COLORS"

-- how frequently we want to update colors, in seconds
local UPDATE_DELAY = 1/60

-- the addon event handler
local Addon = CreateFrame("Frame", AddonName, SettingsPanel or InterfaceOptionsFrame)

--------------------------------------------------------------------------------
-- Saved settings setup stuff
--------------------------------------------------------------------------------

local function removeDefaults(tbl, defaults)
	for k, v in pairs(defaults) do
		if type(tbl[k]) == "table" and type(v) == "table" then
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
		if type(v) == "table" then
			tbl[k] = copyDefaults(tbl[k] or {}, v)
		elseif tbl[k] == nil then
			tbl[k] = v
		end
	end

	return tbl
end

function Addon:GetDatabaseDefaults()
	return {
		-- enable range coloring on pet actions
		petActions = true,

		-- enable flash animations
		flashAnimations = true,
		flashDuration = ATTACK_BUTTON_FLASH_TIME * 1.5,

		-- default colors (r, g, b, a)
		normal = {1, 1, 1, 1},
		oor = {1, 0.3, 0.1, 1},
		oom = {0.1, 0.3, 1, 1},
		unusable = {0.4, 0.4, 0.4, 1}
	}
end

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
	-- create new frame to load separately from the UI frame
	local updateFrame = CreateFrame("Frame", nil, UIParent)
	updateFrame:SetScript("OnUpdate", self.HandleUpdate)
	self:SetScript("OnShow", self.OnShow)
	self:SetScript("OnEvent", self.OnEvent)

	-- register any events we need to watch
	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("PLAYER_LOGIN")
	self:RegisterEvent("PLAYER_LOGOUT")

	-- drop this method, as we won't need it again
	self.OnLoad = nil
end

-- addon shown (which in this case means that InterfaceOptionsFrame was shown)
-- load the config addon and get rid of this method
function Addon:OnShow()
	LoadAddOn(AddonName .. "_Config")

	-- drop this method, as we won't need it again
	self:SetScript("OnShow", nil)
	self.OnShow = nil
end

function Addon:OnEvent(event, ...)
	local func = self[event]

	if func then
		func(self, event, ...)
	end
end

-- when the addon finishes loading
function Addon:ADDON_LOADED(event, addonName)
	if addonName ~= AddonName then
		return
	end

	-- setup our saved settings stuff
	local sets = _G[DB_KEY]

	if not sets then
		sets = {}
		_G[DB_KEY] = sets
	end

	self.sets = copyDefaults(sets, self:GetDatabaseDefaults())

	-- get rid of the handler, as we don't need it anymore
	self:UnregisterEvent(event)
	self[event] = nil
end

-- use this function when performance is not critical
function Addon:SetButtonState(button, state)
	self.buttonStates[button] = state
	button.icon:SetDesaturated(state == "oom" or state == "oor")
	local color = self.sets[state]
	button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
end

-- when the player first logs in
function Addon:PLAYER_LOGIN(event)
	local function button_StartFlash(button)
		if button:IsVisible() then
			self:StartButtonFlashing(button)
		end
	end

	local function actionButton_OnShowHide(button)
		self:UpdateActionButtonWatched(button)
		self:UpdateButtonFlashing(button)
	end

	local function actionButton_Update(button)
		self:UpdateActionButtonWatched(button)
	end

	local function actionButton_UpdateUsable(button)
		local actionType, actionTypeId = GetActionInfo(button.action)

		if not actionType then
			self:SetButtonState(button, "normal")
		elseif actionType == "macro" then
			-- for macros with names that start with a #, we prioritize the OOM check
			-- using a spell cost strategy over other ones to better clarify if the
			-- macro is actually usable or not
			local name = GetMacroInfo(actionTypeId)

			if name and name:sub(1, 1) == "#" then
				local spellId = GetMacroSpell(actionTypeId)

				-- only run the check for spell macros
				if spellId then
					local debounce = true

					for _, cost in ipairs(GetSpellPowerCost(spellId)) do
						if UnitPower("player", cost.type) < cost.minCost then
							self:SetButtonState(button, "oom")
							debounce = false
						end
					end

					if debounce then
						if IsActionInRange(button.action) == false then
							self:SetButtonState(button, "oor")
						else
							self:SetButtonState(button, "normal")
						end
					end
				end
			end
		else
			local isUsable, notEnoughMana = IsUsableAction(button.action)

			if not isUsable then
				if notEnoughMana then
					self:SetButtonState(button, "oom")
				else
					self:SetButtonState(button, "unusable")
				end
			elseif IsActionInRange(button.action) == false then
				-- we do == false here because IsActionInRange can return one of true
				-- (has range, in range), false (has range, out of range), and nil (does
				-- not have range) and we explicitly want to know about (has range, oor)
				self:SetButtonState(button, "oor")
			else
				self:SetButtonState(button, "normal")
			end
		end
	end

	-- register existing action buttons
	-- the method varies between classic and shadowlands, as action buttons in
	-- shadowlands use ActionBarActionButtonMixin
	local ActionBarActionButtonMixin = _G.ActionBarActionButtonMixin

	if ActionBarActionButtonMixin then
		local function actionButton_OnLoad(button)
			button:SetScript("OnUpdate", nil)
			button:HookScript("OnShow", actionButton_OnShowHide)
			button:HookScript("OnHide", actionButton_OnShowHide)

			-- Update is called whenever an action button changes, so we
			-- check here to we if we need to pay attention to the button anymore
			hooksecurefunc(button, "Update", actionButton_Update)

			-- UpdateUsable is called when the button normally changes
			-- color when unusuable, so we need to reapply our custom coloring
			hooksecurefunc(button, "UpdateUsable", actionButton_UpdateUsable)

			if self.sets.flashAnimations then
				hooksecurefunc(button, "StartFlash", button_StartFlash)
			end

			self:UpdateActionButtonWatched(button)
		end

		-- hook any existing frames that are derived from ActionBarActionButtonMixin
		local f = EnumerateFrames()

		while f do
			if f.OnLoad == ActionBarActionButtonMixin.OnLoad then
				actionButton_OnLoad(f)
			end

			f = EnumerateFrames(f)
		end

		-- grab later ones, too
		hooksecurefunc(ActionBarActionButtonMixin, "OnLoad", actionButton_OnLoad)
	else
		local function actionButton_OnUpdate(button)
			button:SetScript("OnUpdate", nil)
			button:HookScript("OnShow", actionButton_OnShowHide)
			button:HookScript("OnHide", actionButton_OnShowHide)

			self:UpdateActionButtonWatched(button)
		end

		-- hook any action button events we need to take care of
		-- register events on update initially, and wipe out their individual on
		-- update handlers. This is why tullaRange has a negative performance
		-- impact
		hooksecurefunc("ActionButton_OnUpdate", actionButton_OnUpdate)

		-- ActionButton_UpdateUsable is called when the button normally changes
		-- color when unusuable, so we need to reapply our custom coloring at this
		-- point
		hooksecurefunc("ActionButton_UpdateUsable", actionButton_UpdateUsable)

		-- ActionButton_Update is called whenever an action button changes, so we
		-- check here to we if we need to pay attention to the button anymore or not
		hooksecurefunc("ActionButton_Update", actionButton_Update)

		-- setup flash animations
		if self.sets.flashAnimations then
			hooksecurefunc("ActionButton_StartFlash", button_StartFlash)
		end
	end

	-- register pet actions, if we want to
	if self.sets.petActions then
		-- register all pet action slots
		self.petActions = {}

		for i = 1, NUM_PET_ACTION_SLOTS do
			tinsert(self.petActions, _G["PetActionButton" .. i])
		end

		local function petButton_OnShowHide(button)
			self:UpdatePetActionButtonWatched(button)
			self:UpdateButtonFlashing(button)
		end

		local function petButton_OnUpdate(button)
			button:SetScript("OnUpdate", nil)
			button:HookScript("OnShow", petButton_OnShowHide)
			button:HookScript("OnHide", petButton_OnShowHide)
			self:UpdatePetActionButtonWatched(button)
		end

		local function petActionBar_Update(bar)
			-- the UI does not actually use the self arg here
			-- and sometimes calls the method without it
			bar = bar or _G.PetActionBarFrame

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
			else
				-- if we don't, wipe any actions we currently are showing
				wipe(self.watchedPetActions)
			end
		end

		-- hook any pet button events we need to take care of
		-- register events on update initially, and wipe out their individual on
		-- update handlers
		local PetActionBar = _G.PetActionBar

		if type(PetActionBar) == "table" then
			if type(PetActionBar.Update) == "function" then
				hooksecurefunc(PetActionBar, "Update", petActionBar_Update)
			end

			if type(PetActionBar.actionButtons) == "table" then
				for _, button in pairs(PetActionBar.actionButtons) do
					hooksecurefunc(button, "OnUpdate", petButton_OnUpdate)
					hooksecurefunc(button, "StartFlash", button_StartFlash)
				end
			end
		else
			hooksecurefunc("PetActionButton_OnUpdate", petButton_OnUpdate)
			hooksecurefunc("PetActionBar_Update", petActionBar_Update)

			if self.sets.flashAnimations then
				hooksecurefunc("PetActionButton_StartFlash", button_StartFlash)
			end
		end
	end

	-- get rid of the handler, as we don't need it anymore
	self:UnregisterEvent(event)
	self[event] = nil
end

function Addon:PLAYER_LOGOUT()
	if self.sets then
		removeDefaults(self.sets, self:GetDatabaseDefaults())
	end
end

--------------------------------------------------------------------------------
-- Update API
--------------------------------------------------------------------------------

local actionType, actionTypeId
local color
local name
local spellId
local debounce
local isUsable, notEnoughMana
local state

local delta = 0

function Addon:HandleUpdate(elapsed)
	if delta >= UPDATE_DELAY then
		delta = elapsed
	else
		delta = delta + elapsed
		return
	end

	for button in pairs(Addon.watchedActions) do
		actionType, actionTypeId = GetActionInfo(button.action)

		if not actionType then
			if Addon.buttonStates[button] ~= "normal" then
				Addon.buttonStates[button] = "normal"
				button.icon:SetDesaturated(false)
				color = Addon.sets["normal"]
				button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
			end
		elseif actionType == "macro" then
			-- for macros with names that start with a #, we prioritize the OOM check
			-- using a spell cost strategy over other ones to better clarify if the
			-- macro is actually usable or not
			name = GetMacroInfo(actionTypeId)

			if name and name:sub(1, 1) == "#" then
				spellId = GetMacroSpell(actionTypeId)

				-- only run the check for spell macros
				if spellId then
					debounce = true

					for _, cost in ipairs(GetSpellPowerCost(spellId)) do
						if UnitPower("player", cost.type) < cost.minCost then
							if Addon.buttonStates[button] ~= "oom" then
								Addon.buttonStates[button] = "oom"
								button.icon:SetDesaturated(true)
								color = Addon.sets["oom"]
								button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
							end

							debounce = false
						end
					end

					if debounce then
						if IsActionInRange(button.action) == false then
							if Addon.buttonStates[button] ~= "oor" then
								Addon.buttonStates[button] = "oor"
								button.icon:SetDesaturated(true)
								color = Addon.sets["oor"]
								button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
							end
						else
							if Addon.buttonStates[button] ~= "normal" then
								Addon.buttonStates[button] = "normal"
								button.icon:SetDesaturated(false)
								color = Addon.sets["normal"]
								button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
							end
						end
					end
				end
			end
		else
			isUsable, notEnoughMana = IsUsableAction(button.action)

			if not isUsable then
				if notEnoughMana then
					if Addon.buttonStates[button] ~= "oom" then
						Addon.buttonStates[button] = "oom"
						button.icon:SetDesaturated(true)
						color = Addon.sets["oom"]
						button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
					end
				else
					if Addon.buttonStates[button] ~= "unusable" then
						Addon.buttonStates[button] = "unusable"
						button.icon:SetDesaturated(false)
						color = Addon.sets["unusable"]
						button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
					end
				end
			elseif IsActionInRange(button.action) == false then
				-- we do == false here because IsActionInRange can return one of true
				-- (has range, in range), false (has range, out of range), and nil (does
				-- not have range) and we explicitly want to know about (has range, oor)
				if Addon.buttonStates[button] ~= "oor" then
					Addon.buttonStates[button] = "oor"
					button.icon:SetDesaturated(true)
					color = Addon.sets["oor"]
					button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
				end
			else
				if Addon.buttonStates[button] ~= "normal" then
					Addon.buttonStates[button] = "normal"
					button.icon:SetDesaturated(false)
					color = Addon.sets["normal"]
					button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
				end
			end
		end
	end

	for button in pairs(Addon.watchedPetActions) do
		-- pet action button specific stuff
		local slot = button:GetID() or 0
		local _, _, _, _, _, _, _, checksRange, inRange = GetPetActionInfo(slot)
		local isUsable, notEnoughMana = GetPetActionSlotUsable(slot)

		-- usable (ignoring target information)
		if isUsable then
			-- but out of range
			if checksRange and not inRange then
				state = "oor"
			else
				state = "normal"
			end
		elseif notEnoughMana then
			state = "oom"
		else
			state = "unusable"
		end

		if Addon.buttonStates[button] ~= state then
			Addon.buttonStates[button] = state
			button.icon:SetDesaturated(state == "oom" or state == "oor")
			color = Addon.sets[state]
			button.icon:SetVertexColor(color[1], color[2], color[3], color[4])
		end
	end
end

function Addon:UpdateActionButtonWatched(button)
	if button.action and button:IsVisible() and ActionHasRange(button.action) then
		self.watchedActions[button] = true
	else
		self.watchedActions[button] = nil
	end
end

function Addon:UpdatePetActionButtonWatched(button)
	local _, _, _, _, _, _, _, checksRange = GetPetActionInfo(button:GetID() or 0)

	if button:IsVisible() and checksRange then
		self.watchedPetActions[button] = true
	else
		self.watchedPetActions[button] = nil
	end
end

--------------------------------------------------------------------------------
-- Flashing replacement
--------------------------------------------------------------------------------

local function alpha_OnFinished(self)
	if self.owner.flashing ~= 1 then
		Addon:StopButtonFlashing(self.owner)
	end
end

function Addon:StartButtonFlashing(button)
	local animation = self.flashAnimations and self.flashAnimations[button]

	if not animation then
		animation = button.Flash:CreateAnimationGroup()
		animation:SetLooping("BOUNCE")

		local alpha = animation:CreateAnimation("ALPHA")
		alpha:SetDuration(self.sets.flashDuration)
		alpha:SetFromAlpha(0)
		alpha:SetToAlpha(1)
		alpha:SetScript("OnFinished", alpha_OnFinished)
		alpha.owner = button

		if self.flashAnimations then
			self.flashAnimations[button] = animation
		else
			self.flashAnimations = {[button] = animation}
		end
	end

	button.Flash:Show()
	animation:Play()
end

function Addon:StopButtonFlashing(button)
	local animation = self.flashAnimations and self.flashAnimations[button]

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
-- Needed for colorSelector.lua
--------------------------------------------------------------------------------

function Addon:UpdateButtonStates() end

function Addon:GetColor(state)
	local color = self.sets[state]

	return color[1], color[2], color[3], color[4]
end

-- load the addon
Addon:OnLoad()
