--------------------------------------------------------------------------------
-- The main driver of the application
--------------------------------------------------------------------------------

local AddonName, Addon = ...

Addon.frame = CreateFrame("Frame", nil, SettingsPanel or InterfaceOptionsFrame)
Addon.frame.owner = Addon

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

-- addon intially loaded
function Addon:OnLoad()
	self.frame:SetScript("OnEvent", function(frame, event, ...)
		local func = frame.owner[event]

		if func then
			func(self, event, ...)
		end
	end)

	-- load the options menu when the settings frame is loaded
	self.frame:SetScript("OnShow", function(frame)
		C_AddOns.LoadAddOn(AddonName .. "_Config")
		frame:SetScript("OnShow", nil)
	end)

	-- register any events we need to watch
	self.frame:RegisterEvent("ADDON_LOADED")
	self.frame:RegisterEvent("PLAYER_LOGIN")
	self.frame:RegisterEvent("PLAYER_LOGOUT")

	-- drop this method, as we won't need it again
	self.OnLoad = nil
	_G[AddonName] = self
end

-- when the addon finishes loading
function Addon:ADDON_LOADED(event, addonName)
	if addonName ~= AddonName then return end

	-- initialize settings
	self.sets = self:GetOrCreateSettings()

	-- add a launcher for the addons tray
	_G[addonName .. '_Launch'] = function()
		if C_AddOns.LoadAddOn(addonName .. '_Config') then
			Settings.OpenToCategory(addonName)
		end
	end

	-- enable the addon, this is defined in classic/modern
	if type(self.Enable) == "function" then
		self:Enable()
	else
		print(addonName, " - Unable to enable for World of Warcraft version", (GetBuildInfo()))
	end

	-- get rid of the handler, as we don't need it anymore
	self.frame:UnregisterEvent(event)
	self[event] = nil
end

function Addon:PLAYER_LOGOUT(event)
	self:TrimSettings()

	self.frame:UnregisterEvent(event)
	self[event] = nil
end

--------------------------------------------------------------------------------
-- Settings management
--------------------------------------------------------------------------------

-- the name of our SavedVariablesentry in the addon toc
local DB_KEY = "TULLARANGE_COLORS"

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

-- gets or creates the addon settings database
-- populates it with defaults
function Addon:GetOrCreateSettings()
	local sets = _G[DB_KEY]

	if not sets then
		sets = {}

		_G[DB_KEY] = sets
	end

	return copyDefaults(sets, self:GetDefaultSettings())
end

-- removes any entries from the settings database that equate to default settings
function Addon:TrimSettings()
    local db = _G[DB_KEY]

    if db then
        removeDefaults(db, self:GetDefaultSettings())
    end
end

function Addon:GetDefaultSettings()
	return {
		-- how frequently we want to update, in seconds
		updateDelay = TOOLTIP_UPDATE_TIME,

		-- enable range coloring on pet actions
		petActions = true,

		-- enable flash animations
		flashAnimations = true,
		flashDuration = ATTACK_BUTTON_FLASH_TIME * 2,

		-- default colors (r, g, b, a, desaturate)
		normal = {1, 1, 1, 1, desaturate = false},
		oor = {1, 0.3, 0.1, 1, desaturate = true},
		oom = {0.1, 0.3, 1, 1, desaturate = true},
		unusable = {0.4, 0.4, 0.4, 1, desaturate = false}
	}
end

--------------------------------------------------------------------------------
-- Settings queries
--------------------------------------------------------------------------------

function Addon:GetUpdateDelay()
	return self.sets.updateDelay
end

function Addon:GetFlashDuration()
	return self.sets.flashDuration
end

function Addon:HandlePetActions()
	return self.sets.petActions
end

function Addon:HandleAttackAnimations()
	return self.sets.flashAnimations
end

function Addon:GetColor(state)
	local color = self.sets[state]
	if color then
		return color[1], color[2], color[3], color[4], color.desaturate
	end
end

-- load the addon
Addon:OnLoad()