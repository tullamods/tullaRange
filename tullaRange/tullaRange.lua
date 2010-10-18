--[[
	tullaRange
		Adds out of range coloring to action buttons
		Derived from RedRange with negligable improvements to CPU usage
--]]

--[[ locals and speed ]]--

local _G = _G
local UPDATE_DELAY = 0.1
local ATTACK_BUTTON_FLASH_TIME = ATTACK_BUTTON_FLASH_TIME
local SPELL_POWER_HOLY_POWER = SPELL_POWER_HOLY_POWER
local ActionButton_GetPagedID = ActionButton_GetPagedID
local ActionButton_IsFlashing = ActionButton_IsFlashing
local ActionHasRange = ActionHasRange
local IsActionInRange = IsActionInRange
local IsUsableAction = IsUsableAction
local HasAction = HasAction

--stuff for holy power detection
local HAND_OF_LIGHT = GetSpellInfo(90174)
local PLAYER_IS_PALADIN = select(2, UnitClass('player')) == 'PALADIN'
local HOLY_POWER_SPELLS = {
	[85256] = GetSpellInfo(85256),
	[53385] = GetSpellInfo(53385),
	[53600] = GetSpellInfo(53600),
	[84963] = GetSpellInfo(84963)
}

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

local tullaRange = CreateFrame('Frame', 'tullaRange', UIParent); tullaRange:Hide()

function tullaRange:Load()
	self:SetScript('OnUpdate', self.OnUpdate)
	self:SetScript('OnHide', self.OnHide)
	self:SetScript('OnEvent', self.OnEvent)
	self.elapsed = 0

	self:RegisterEvent('PLAYER_LOGIN')
	self:RegisterEvent('PLAYER_LOGOUT')
end


--[[ Frame Events ]]--

function tullaRange:OnEvent(event, ...)
	local action = self[event]
	if action then
		action(self, event, ...)
	end
end

function tullaRange:OnUpdate(elapsed)
	if self.elapsed < UPDATE_DELAY then
		self.elapsed = self.elapsed + elapsed
	else
		self:Update()
	end
end

function tullaRange:OnHide()
	self.elapsed = 0
end


--[[ Game Events ]]--

function tullaRange:PLAYER_LOGIN()
	if not TULLARANGE_COLORS then
		TULLARANGE_COLORS = {}
	end
	self.colors = copyDefaults(TULLARANGE_COLORS, self:GetDefaults())

	--add options loader
	local f = CreateFrame('Frame', nil, InterfaceOptionsFrame)
	f:SetScript('OnShow', function(self)
		self:SetScript('OnShow', nil)
		LoadAddOn('tullaRange_Config')
	end)

	self.buttonsToUpdate = {}

	hooksecurefunc('ActionButton_OnUpdate', self.RegisterButton)
	hooksecurefunc('ActionButton_UpdateUsable', self.OnUpdateButtonUsable)
	hooksecurefunc('ActionButton_Update', self.OnButtonUpdate)
end

function tullaRange:PLAYER_LOGOUT()
	removeDefaults(TULLARANGE_COLORS, self:GetDefaults())
end


--[[ Actions ]]--

function tullaRange:Update()
	self:UpdateButtons(self.elapsed)
	self.elapsed = 0
end

function tullaRange:ForceColorUpdate()
	for button in pairs(self.buttonsToUpdate) do
		tullaRange.OnUpdateButtonUsable(button)
	end
end

function tullaRange:UpdateShown()
	if next(self.buttonsToUpdate) then
		self:Show()
	else
		self:Hide()
	end
end

function tullaRange:UpdateButtons(elapsed)
	if not next(self.buttonsToUpdate) then
		self:Hide()
		return
	end

	for button in pairs(self.buttonsToUpdate) do
		self:UpdateButton(button, elapsed)
	end
end

function tullaRange:UpdateButton(button, elapsed)
	tullaRange.UpdateButtonUsable(button)
	tullaRange.UpdateFlash(button, elapsed)
end

function tullaRange:UpdateButtonStatus(button)
	local action = ActionButton_GetPagedID(button)
	if not(button:IsVisible() and action and HasAction(action) and ActionHasRange(action)) then
		self.buttonsToUpdate[button] = nil
	else
		self.buttonsToUpdate[button] = true
	end
	self:UpdateShown()
end



--[[ Button Hooking ]]--

function tullaRange.RegisterButton(button)
	button:HookScript('OnShow', tullaRange.OnButtonShow)
	button:HookScript('OnHide', tullaRange.OnButtonHide)
	button:SetScript('OnUpdate', nil)

	tullaRange:UpdateButtonStatus(button)
end

function tullaRange.OnButtonShow(button)
	tullaRange:UpdateButtonStatus(button)
end

function tullaRange.OnButtonHide(button)
	tullaRange:UpdateButtonStatus(button)
end

function tullaRange.OnUpdateButtonUsable(button)
	button.tullaRangeColor = nil
	tullaRange.UpdateButtonUsable(button)
end

function tullaRange.OnButtonUpdate(button)
	 tullaRange:UpdateButtonStatus(button)
end


--[[ Range Coloring ]]--

local function isHolyPowerAbility(actionId)
	local actionType, id = GetActionInfo(actionId)
	if acitonType == 'macro' then
		local macroSpell = GetMacroSpell(id)
		if macroSpell then
			for spellId, spellName in pairs(HOLY_POWER_SPELLS) do
				if macroSpell == spellName then
					return true
				end
			end
		end
	else
		for spellId, spellName in pairs(HOLY_POWER_SPELLS) do
			if id == spellId then
				return true
			end
		end
	end
	
	return false
end

function tullaRange.UpdateButtonUsable(button)
	local action = ActionButton_GetPagedID(button)
	local isUsable, notEnoughMana = IsUsableAction(action)

	--usable
	if isUsable then
		--but out of range
		if IsActionInRange(action) == 0 then
			tullaRange.SetButtonColor(button, 'oor')
		--a holy power abilty, and we're less than 3 Holy Power
		elseif PLAYER_IS_PALADIN and isHolyPowerAbility(action) and not(UnitPower('player', SPELL_POWER_HOLY_POWER) == 3 or UnitBuff('player', HAND_OF_LIGHT)) then
			tullaRange.SetButtonColor(button, 'ooh')
		--in range
		else
			tullaRange.SetButtonColor(button, 'normal')
		end
	--out of mana
	elseif notEnoughMana then
		tullaRange.SetButtonColor(button, 'oom')
	--unusable
	else
		button.tullaRangeColor = 'unusuable'
	end
end

function tullaRange.SetButtonColor(button, colorType)
	if button.tullaRangeColor ~= colorType then
		button.tullaRangeColor = colorType

		local r, g, b = tullaRange:GetColor(colorType)

		local icon =  _G[button:GetName() .. 'Icon']
		icon:SetVertexColor(r, g, b)

		local nt = button:GetNormalTexture()
		nt:SetVertexColor(r, g, b)
	end
end

function tullaRange.UpdateFlash(button, elapsed)
	if ActionButton_IsFlashing(button) then
		local flashtime = button.flashtime - elapsed

		if flashtime <= 0 then
			local overtime = -flashtime
			if overtime >= ATTACK_BUTTON_FLASH_TIME then
				overtime = 0
			end
			flashtime = ATTACK_BUTTON_FLASH_TIME - overtime

			local flashTexture = _G[button:GetName() .. 'Flash']
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

function tullaRange:GetDefaults()
	return {
		normal = {1, 1, 1},
		oor = {1, 0.3, 0.1},
		oom = {0.1, 0.3, 1},
		ooh = {0.45, 0.45, 1},
	}
end

function tullaRange:Reset()
	TULLARANGE_COLORS = {}
	self.colors = copyDefaults(TULLARANGE_COLORS, self:GetDefaults())

	self:ForceColorUpdate()
end

function tullaRange:SetColor(index, r, g, b)
	local color = self.colors[index]
	color[1] = r
	color[2] = g
	color[3] = b

	self:ForceColorUpdate()
end

function tullaRange:GetColor(index)
	local color = self.colors[index]
	return color[1], color[2], color[3]
end

--[[ Load The Thing ]]--

tullaRange:Load()