--[[
	tullaRange Config Localization - Russian
--]]

local AddonName, Addon = ...

local L = {
	ColorSettings = 'Цвета',

	ColorSettingsTitle = 'Настройки цветовой конфигурации tullaRange',

	oor = 'Вне диапазона',

	oom = 'Нет маны',

	unusable = 'Неиспользуемый',

	Red = 'Красный',

	Green = 'Зелёный',

	Blue = 'Синий',

	Desaturate = 'Обесцвеченный'
}

Addon.L = setmetatable(L, { __index = function(t, k) return k end })
