--[[
	slider.lua
		A options slider
--]]
local _, Addon = ...

local Slider = Addon:NewWidgetTemplate('Slider')

local SLIDER_TEMPLATE_NAME
if LE_EXPANSION_LEVEL_CURRENT <= LE_EXPANSION_WRATH_OF_THE_LICH_KING then
    SLIDER_TEMPLATE_NAME = "HorizontalSliderTemplate"
else
    SLIDER_TEMPLATE_NAME = "UISliderTemplate"
end

function Slider:New(name, parent, low, high, step)
    local slider = self:Bind(CreateFrame('Slider', nil, parent, SLIDER_TEMPLATE_NAME))

    slider:SetSize(144, 17)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    slider:EnableMouseWheel(true)

    local label = slider:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    label:SetPoint('BOTTOMLEFT', slider, 'TOPLEFT')
    label:SetText(name)
    slider.Label = label

    local value = slider:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmallRight')
    value:SetPoint('BOTTOMRIGHT', slider, 'TOPRIGHT')
    slider.Value = value

    slider:SetScript('OnShow', slider.OnShow)
    slider:SetScript('OnMouseWheel', slider.OnMouseWheel)
    slider:SetScript('OnValueChanged', slider.OnValueChanged)
    slider:SetScript('OnMouseWheel', slider.OnMouseWheel)
    slider:SetScript('OnEnter', slider.OnEnter)
    slider:SetScript('OnLeave', slider.OnLeave)

    return slider
end

function Slider:OnShow()
    self:UpdateValue()
end

function Slider:OnValueChanged(value)
    self:SetSavedValue(value)
    self:UpdateText(self:GetSavedValue())
end

function Slider:OnMouseWheel(direction)
    local step = self:GetValueStep() * direction
    local value = self:GetValue()
    local minVal, maxVal = self:GetMinMaxValues()

    if step > 0 then
        self:SetValue(math.min(value + step, maxVal))
    else
        self:SetValue(math.max(value + step, minVal))
    end
end

function Slider:OnEnter()
    if not GameTooltip:IsOwned(self) and self.tooltip then
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetText(self.tooltip)
    end
end

function Slider:OnLeave()
    if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
    end
end

-- update methods
function Slider:SetSavedValue(value)
    assert(false, 'Hey, you forgot to set SetSavedValue for ' .. self:GetName())
end

function Slider:GetSavedValue()
    assert(false, 'Hey, you forgot to set GetSavedValue for ' .. self:GetName())
end

function Slider:UpdateValue()
    self:SetValue(self:GetSavedValue())
    self:UpdateText(self:GetSavedValue())
end

function Slider:UpdateText(value)
    if self.GetFormattedText then
        self.Value:SetText(self:GetFormattedText(value))
    else
        self.Value:SetText(value)
    end
end

-- exports
Addon.Slider = Slider
