-- tullaRange localization strings
local AddonName, Addon = ...

local L = {}

-- define defaults
L.Blue = 'Blue'
L.ColorSettings = 'Colors'
L.ColorSettingsTitle = ('%s color configuration settings'):format(AddonName)
L.Desaturate = 'Desaturate'
L.Green = 'Green'
L.oom = 'Out of Mana'
L.oor = 'Out of Range'
L.Opacity = OPACITY
L.Red = 'Red'
L.unusable = 'Unusable'

-- fallback to the key if a value is not present
Addon.L = setmetatable(L, { __index = function(_, k) return k end })
