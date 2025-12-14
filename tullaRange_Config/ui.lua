local _, Addon = ...

local L = Addon.L
local AddonSettingsFrame = tullaRange.frame
local ColorChannels = { 'Red', 'Green', 'Blue', 'Opacity' }

local function getRandomSpellIcon()
    if type(GetSpellBookItemTexture) == "function" then
        local _, _, offset, numSlots = GetSpellTabInfo(GetNumSpellTabs())
        return GetSpellBookItemTexture(math.random(offset + numSlots - 1), 'player')
    end

    local i = C_SpellBook.GetSpellBookSkillLineInfo(C_SpellBook.GetNumSpellBookSkillLines())
    local offset = i.itemIndexOffset
    local numSlots = i.numSpellBookItems
    return C_SpellBook.GetSpellBookItemTexture(math.random(offset + numSlots - 1), Enum.SpellBookSpellBank.Player)
end

local function createPercentSlider(props)
    local slider = CreateFrame('Slider', nil, props.parent, "MinimalSliderTemplate")

    slider:SetMinMaxValues(props.low or 0, props.high or 100)
    slider:SetValueStep(props.step or 1)
    slider:EnableMouseWheel(true)

    local label = slider:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    label:SetPoint('BOTTOMLEFT', slider, 'TOPLEFT')
    label:SetText(props.label)
    slider.Label = label

    local value = slider:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmallRight')
    value:SetPoint('BOTTOMRIGHT', slider, 'TOPRIGHT')
    slider.Value = value

    slider:SetScript('OnShow', function(s)
        local value = props.value
        if type(value) == "function" then
            s:SetValue(value())
        elseif type(value) == "number" then
            s:SetValue(value)
        else
            s:SetValue(s:GetMinMaxValues())
        end
    end)

    slider:SetScript('OnValueChanged', function(s, value)
        if s.prevValue ~= value then
            s.prevValue = value
            s.Value:SetFormattedText("%d %%", value)
            props.onChange(value, s)
        end
    end)

    slider:SetScript('OnMouseWheel', function(s, direction)
        local v = s:GetValue()
        local minVal, maxVal = s:GetMinMaxValues()
        local delta = s:GetValueStep() * direction

        if delta > 0 then
            s:SetValue(math.min(v + delta, maxVal))
        else
            s:SetValue(math.max(v + delta, minVal))
        end
    end)

    return slider
end

local function createCheckButton(parent, label)
    local button = CreateFrame('CheckButton', nil, parent)

    button:SetSize(30, 29)
    button:SetNormalAtlas("checkbox-minimal")
    button:SetPushedAtlas("checkbox-minimal")
    button:SetCheckedTexture("checkmark-minimal")
    button:SetDisabledAtlas("checkmark-minimal-disabled")

    local labelText = button:CreateFontString(nil, "ARTWORK")
    labelText:SetFontObject("GameFontNormalLeft")
    labelText:SetText(label)
    labelText:SetPoint("LEFT", button, "RIGHT")

    button:SetHitRectInsets(0, -labelText:GetStringWidth(), 0, 0)
    button.Text = labelText

    return button
end

local function createColorSelector(state, parent)
    local frame = CreateFrame("Frame", nil, parent)

    local previewPanel = CreateFrame('Frame', nil, frame)
    previewPanel:SetPoint('TOPLEFT')
    previewPanel:SetPoint('BOTTOMLEFT')
    previewPanel:SetWidth(128)

    local colorsPanel = CreateFrame('Frame', nil, frame)
    colorsPanel:SetPoint('TOPLEFT', previewPanel, 'TOPRIGHT', 16, 0)
    colorsPanel:SetPoint('BOTTOMRIGHT')

    -- add title
    local title = previewPanel:CreateFontString(nil, 'BACKGROUND', 'GameFontHighlightLarge')
    title:SetJustifyH('CENTER')
    title:SetPoint('TOP')
    title:SetText(L[state])

    -- add preview image
    local previewButton = CreateFrame('Button', nil, previewPanel)
    previewButton:SetPoint('CENTER')
    previewButton:SetSize(96, 96)
    previewButton:SetScript('OnClick', function(f) f.Icon:SetTexture(getRandomSpellIcon()) end)

    local previewButtonIcon = previewButton:CreateTexture(nil, 'ARTWORK')
    previewButtonIcon:SetAllPoints()
    previewButtonIcon:SetTexture(getRandomSpellIcon())
    previewButtonIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    previewButton.Icon = previewButtonIcon

    -- add desaturate toggle
    local desaturate = createCheckButton(previewPanel, L.Desaturate)

    desaturate:SetScript("OnShow", function(checkbox)
        local desaturated = tullaRange.sets[state].desaturate and true

        checkbox:SetChecked(desaturated)
        previewButtonIcon:SetDesaturated(desaturated)
    end)

    desaturate:SetScript("OnClick", function(checkbox)
        local desaturated = checkbox:GetChecked() and true

        previewButtonIcon:SetDesaturated(desaturated)

        tullaRange.sets[state].desaturate = desaturated
        tullaRange:RequestUpdate()
    end)

    desaturate:SetPoint('BOTTOM', -desaturate.Text:GetStringWidth()/2, 0)

    -- add color channel siders
    local sliders = {}
    for i = 1, #ColorChannels do
        local color = ColorChannels[i]

        local slider = createPercentSlider{
            parent = colorsPanel,

            label = L[color],

            value = function()
                return tullaRange.sets[state][i] * 100
            end,

            onChange = function(value)
                tullaRange.sets[state][i] = math.floor(value + 0.5) / 100

                local r, g, b, a = tullaRange:GetColor(state)
                previewButtonIcon:SetVertexColor(r, g, b, a)

                tullaRange:RequestUpdate()
            end
        }

        if i > 1 then
            slider:SetPoint('TOPLEFT', sliders[i - 1], 'BOTTOMLEFT', 0, -24)
            slider:SetPoint('TOPRIGHT')
        else
            slider:SetPoint('TOPLEFT', 0, -12)
            slider:SetPoint('TOPRIGHT')
        end

        sliders[i] = slider
    end

    return frame
end

local header = CreateFrame("Frame", nil,  AddonSettingsFrame)
header:SetHeight(50)
header:SetPoint("TOPLEFT")
header:SetPoint("TOPRIGHT")

local headerTitle = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
headerTitle:SetJustifyH("LEFT")
headerTitle:SetPoint("TOPLEFT", 7, -22)
headerTitle:SetFormattedText("%s - %s", "tullaRange", COLORS)

local headerDivider = header:CreateTexture(nil, "ARTWORK")
headerDivider:SetAtlas("Options_HorizontalDivider", true)
headerDivider:SetPoint("TOP", 0, -50)

-- add color optons
for i, type in ipairs{'oor', 'oom', 'unusable'} do
    local selector = createColorSelector(type, AddonSettingsFrame)

    selector:SetHeight(164)

    local s = 16
    local y = -(64 + (i - 1) * (selector:GetHeight() + s))

    selector:SetPoint("TOPLEFT", 7, y)
    selector:SetPoint("TOPRIGHT", -21, y)
end

local category = Settings.RegisterCanvasLayoutCategory(AddonSettingsFrame, "tullaRange")

category.ID = "tullaRange"

Settings.RegisterAddOnCategory(category)