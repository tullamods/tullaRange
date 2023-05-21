--------------------------------------------------------------------------------
-- a color selector widget
--
-- provides options for red, green, blue, and alpha channels
-- as well as desaturate checkbox
--------------------------------------------------------------------------------
local _, Addon = ...

local L = Addon.L
local tullaRange = _G.tullaRange
local ColorChannels = {'Red', 'Green', 'Blue', 'Opacity'}

local ColorSelector = Addon:NewWidgetTemplate('Frame')

function ColorSelector:New(state, parent)
    local selector = self:Bind(CreateFrame('Frame', nil, parent))

    -- add title
    local title = selector:CreateFontString(nil, 'BACKGROUND', 'GameFontHighlightLarge')
    title:SetJustifyH('LEFT')
    title:SetPoint('TOPLEFT')
    title:SetText(L[state])
    title:SetWidth(120)
    selector.Title = title

    -- add preview image
    local previewIcon = selector:CreateTexture(nil, 'ARTWORK')
    previewIcon:SetPoint('LEFT')
    previewIcon:SetSize(104, 104)
    selector.PreviewIcon = previewIcon

    -- add color channel siders
    local sliders = {}
    for i, color in ipairs(ColorChannels) do
        local slider = Addon.Slider:New(L[color], selector, 0, 100, 1)

        slider.SetSavedValue = function(_, value)
            tullaRange.sets[state][i] = math.floor(value + 0.5) / 100

            local r, g, b, a = tullaRange:GetColor(state)
            previewIcon:SetVertexColor(r, g, b, a)

            tullaRange:RequestUpdate()
        end

        slider.GetSavedValue = function()
            return tullaRange.sets[state][i] * 100
        end

        if i > 1 then
            slider:SetPoint('TOPLEFT', sliders[i - 1], 'BOTTOMLEFT', 0, -24)
            slider:SetPoint('RIGHT')
        else
            slider:SetPoint('TOPLEFT', title, 'TOPRIGHT', 8, -16)
            slider:SetPoint('RIGHT')
        end

        sliders[i] = slider
    end

    selector.sliders = sliders

    -- add desaturate button
    local desaturate = CreateFrame('CheckButton', nil, selector, 'InterfaceOptionsCheckButtonTemplate')

    desaturate.Text:SetText(L.Desaturate)

    desaturate:SetScript("OnShow", function(checkbox)
        local desaturated = tullaRange.sets[state].desaturate and true

        checkbox:SetChecked(desaturated)
        previewIcon:SetDesaturated(desaturated)
    end)

    desaturate:SetScript("OnClick", function(checkbox)
        local desaturated = checkbox:GetChecked() and true

        previewIcon:SetDesaturated(desaturated)

        tullaRange.sets[state].desaturate = desaturated
        tullaRange:RequestUpdate()
    end)

    desaturate:SetPoint('BOTTOMLEFT')

    return selector
end

do
    local spellIcons = {}

    -- generate spell icons
    do
        for i = 1, GetNumSpellTabs() do
            local offset, numSpells = select(3, GetSpellTabInfo(i))
            local tabEnd = offset + numSpells

            for j = offset, tabEnd - 1 do
                local texture = GetSpellBookItemTexture(j, 'player')
                if texture then
                    table.insert(spellIcons, texture)
                end
            end
        end
    end

    function ColorSelector:UpdateValues()
        local texture = spellIcons[math.random(1, #spellIcons)]

        self.PreviewIcon:SetTexture(texture)

        for _, slider in pairs(self.sliders) do
            slider:UpdateValue()
        end
    end
end

-- exports
Addon.ColorSelector = ColorSelector
