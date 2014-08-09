--[[
	tullaRange
		Adds out of range coloring to action buttons
		Derived from RedRange with negligable improvements to CPU usage
--]]

--locals and speed
local AddonName, Addon = ...
local _G = _G

local DB_KEY = 'TULLARANGE_COLORS'
local UPDATE_DELAY = 0.15
local ATTACK_BUTTON_FLASH_TIME = _G['ATTACK_BUTTON_FLASH_TIME']
local SPELL_POWER_HOLY_POWER = _G['SPELL_POWER_HOLY_POWER']

local ActionHasRange = _G['ActionHasRange']
local IsActionInRange = _G['IsActionInRange']
local IsUsableAction = _G['IsUsableAction']
local HasAction = _G['HasAction']
local GetTime = _G['GetTime']
local Timer_After = _G['CTimer'].After


--code for handling defaults
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


--[[ The main thing ]]--

function Addon:Load()
	self.buttonsToUpdate = {}

	self.started = nil

	self.updateFinshed = function()
		local elapsed = GetTime() - self.started
		self.started = nil

		self:Update()
	end

	local f = CreateFrame('Frame', nil, _G['InterfaceOptionsFrame'])

	f:SetScript('OnShow', function()
		f:SetScript('OnShow', nil)

		LoadAddOn(AddonName .. '_Config')
	end)

	f:SetScript('OnEvent', self.OnEvent)

	f:RegisterEvent('PLAYER_LOGIN')
	f:RegisterEvent('PLAYER_LOGOUT')
end


--[[ Frame Events ]]--

function Addon:OnEvent(event, ...)
	local action = self[event]

	if action then
		action(self, event, ...)
	end
end

--[[ Game Events ]]--

function Addon:PLAYER_LOGIN()
	self:SetupDatabase()
	self:HookActionEvents()
end

function Addon:PLAYER_LOGOUT()
	self:CleanupDatabase()
end


--[[ Actions ]]--

function Addon:RequestUpdate()
	if not self.timerDone then
		self.timerDone = function()
			local elapsed = GetTime() - self.started
			self.started = nil

			if self:Update(elapsed) then
				self:RequestUpdate()
			end
		end
	end

	if not self.started then
		self.started = GetTime()

		Timer_After(UPDATE_DELAY, self.timerDone)
	end
end

function Addon:Update(elapsed)
	return self:UpdateButtons(elapsed)
end

function Addon:UpdateActive()
	if next(self.buttonsToUpdate) then
		self:RequestUpdate()
	end
end

function Addon:UpdateButtons(elapsed)
	if next(self.buttonsToUpdate) then
		for button in pairs(self.buttonsToUpdate) do
			self:UpdateButton(button, elapsed)
		end

		return true
	end

	return false
end

function Addon:UpdateButton(button, elapsed)
	self:UpdateButtonUsable(button)
	self:UpdateFlash(button, elapsed)
end

function Addon:UpdateButtonStatus(button)
	local action = button.action

	if button:IsVisible() and action and HasAction(action) and ActionHasRange(action) then
		self.buttonsToUpdate[button] = true
	else
		self.buttonsToUpdate[button] = nil
	end

	self:UpdateActive()
end



--[[ Button Hooking ]]--

do
	local function button_OnShow(button)
		Addon:UpdateButtonStatus(button)
	end

	local function button_OnHide(button)
		Addon:UpdateButtonStatus(button)
	end

	local function button_OnUpdateUsable(button)
		Addon:UpdateButtonUsable(button, true)
	end

	local function button_OnUpdate(button)
		Addon:Register(button)
	end

	function Addon:HookActionEvents()
		hooksecurefunc('ActionButton_OnUpdate', button_OnUpdate)
		hooksecurefunc('ActionButton_UpdateUsable', button_OnUpdateUsable)
		hooksecurefunc('ActionButton_Update', button_OnUpdate)
	end

	function Addon:Register(button)
		button:HookScript('OnShow', button_OnShow)
		button:HookScript('OnHide', button_OnHide)
		button:SetScript('OnUpdate', nil)

		self:UpdateButtonStatus(button)
	end
end

--[[ Button Updates ]]--

function Addon:SetButtonColor(button, colorType)
	if button.tullaRangeColor ~= colorType then
		button.tullaRangeColor = colorType

		local r, g, b = self:GetColor(colorType)
		button.icon:SetVertexColor(r, g, b)
	end
end

function Addon:UpdateButtonUsable(button, force)
	if force then
		button.tullaRangeColor = nil
	end

	local action = button.action
	local isUsable, notEnoughMana = IsUsableAction(action)

	--usable
	if isUsable then
		--but out of range
		if IsActionInRange(action) == 0 then
			self:SetButtonColor(button, 'oor')
		else
			self:SetButtonColor(button, 'normal')
		end
	--out of mana
	elseif notEnoughMana then
		self:SetButtonColor(button, 'oom')
	--unusable
	else
		button.tullaRangeColor = 'unusuable'
	end
end

function Addon:UpdateFlash(button, elapsed)
	if button.flashing then
		local flashtime = button.flashtime - elapsed

		if flashtime <= 0 then
			local overtime = -flashtime
			if overtime >= ATTACK_BUTTON_FLASH_TIME then
				overtime = 0
			end
			flashtime = ATTACK_BUTTON_FLASH_TIME - overtime

			local flashTexture = button.Flash
			if flashTexture:IsShown() then
				flashTexture:Hide()
			else
				flashTexture:Show()
			end
		end

		button.flashtime = flashtime
	end
end


--[[ Configuration ]]--

function Addon:SetupDatabase()
	local sets = _G[DB_KEY]

	if not sets then
		sets = {}
		_G[DB_KEY] = sets
	end

	self.sets = copyDefaults(sets, self:GetDatabaseDefaults())
end

function Addon:CleanupDatabase()
	local sets = _G[DB_KEY]

	if sets then
		removeDefaults(sets, self:GetDatabaseDefaults())
	end
end

function Addon:GetDatabaseDefaults()
	return {
		normal = {1, 1, 1},
		oor = {1, 0.3, 0.1},
		oom = {0.1, 0.3, 1}
	}
end

function Addon:ResetDatabase()
	_G[DB_KEY] = nil

	self:SetupDatabase()
	self:ForceColorUpdate()
end

function Addon:SetColor(index, r, g, b)
	local color = self.sets[index]

	color[1] = r
	color[2] = g
	color[3] = b

	self:ForceColorUpdate()
end

function Addon:GetColor(index)
	local color = self.sets[index]

	return color[1], color[2], color[3]
end

function Addon:ForceColorUpdate()
	for button in pairs(self.buttonsToUpdate) do
		self:UpdateButtonUsable(button, true)
	end
end


--[[ Load The Thing ]]--

do
	Addon:Load()
	_G[AddonName] = Addon
end
