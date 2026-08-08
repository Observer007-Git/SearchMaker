local _, SMK = ...

local PanelSettings = {}
local Config = SMK.Config
local Widgets = SMK.Widgets

local function SetControlTooltip(control, text)
    control:SetScript("OnEnter", function()
        GameTooltip:SetOwner(control, "ANCHOR_TOP")
        GameTooltip:SetText(text)
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", GameTooltip_Hide)
end

local function SetLabelEnabled(label, enabled)
    label:SetTextColor(unpack(enabled and Config.colors.gold or Config.colors.disabled))
end

local function GetShortcutChord(shortcut)
    local parts = {}
    if shortcut.alt then parts[#parts + 1] = "ALT" end
    if shortcut.ctrl then parts[#parts + 1] = "CTRL" end
    if shortcut.shift then parts[#parts + 1] = "SHIFT" end
    if shortcut.meta then parts[#parts + 1] = "META" end
    if shortcut.key then parts[#parts + 1] = shortcut.key end
    return table.concat(parts, "-")
end

function PanelSettings:GetMapShortcutText()
    local shortcut = SMK.Settings:Get("mapPinCreateShortcut")
    if type(shortcut) ~= "table" then return SMK.L.MAP_PIN_SHORTCUT_DEFAULT end
    return string.format(SMK.L.MAP_PIN_SHORTCUT_VALUE,
        GetBindingText(GetShortcutChord(shortcut)))
end

function PanelSettings:StopMapShortcutCapture()
    local button = self.mapShortcutButton
    if not button then return end
    button.isCapturing = false
    button:EnableKeyboard(false)
    if button.SetPropagateKeyboardInput then
        button:SetPropagateKeyboardInput(true)
    end
    button:SetText(self:GetMapShortcutText())
end

function PanelSettings:StartMapShortcutCapture()
    local button = self.mapShortcutButton
    button.isCapturing = true
    button:SetText(SMK.L.CAPTURE_SHORTCUT)
    GameTooltip_Hide()
    button:EnableKeyboard(true)
    if button.SetPropagateKeyboardInput then
        button:SetPropagateKeyboardInput(false)
    end
end

function PanelSettings:SetMapShortcut(key, modifier)
    local shortcut = {
        key = key,
        alt = IsAltKeyDown() or nil,
        ctrl = IsControlKeyDown() or nil,
        shift = IsShiftKeyDown() or nil,
        meta = IsMetaKeyDown() or nil,
    }
    if modifier == "ALT" then shortcut.alt = true end
    if modifier == "CTRL" then shortcut.ctrl = true end
    if modifier == "SHIFT" then shortcut.shift = true end
    if modifier == "META" then shortcut.meta = true end
    local changed, message = SMK.Settings:Set("mapPinCreateShortcut", shortcut)
    self:StopMapShortcutCapture()
    if not changed then return message and SMK:Print(message) end
    SMK:Print(string.format(SMK.L.MAP_PIN_SHORTCUT_UPDATED,
        self:GetMapShortcutText()))
end

function PanelSettings:ResetMapShortcut()
    local changed, message = SMK.Settings:Set("mapPinCreateShortcut", false)
    self:StopMapShortcutCapture()
    if not changed then return message and SMK:Print(message) end
    SMK:Print(SMK.L.MAP_PIN_SHORTCUT_RESET)
end

function PanelSettings:ChangePinTextScale(delta)
    local value = math.max(Config.mapPins.minTextScale,
        math.min(Config.mapPins.maxTextScale, SMK.Settings:Get("mapPinTextScale") + delta))
    local changed, message = SMK.Settings:Set("mapPinTextScale", value)
    if not changed then SMK:Print(message) end
    self:Refresh()
end

function PanelSettings:ChangePinTextureScale(delta)
    local value = math.max(Config.mapPins.minTextureScale,
        math.min(Config.mapPins.maxTextureScale, SMK.Settings:Get("pinTextureScale") + delta))
    local changed, message = SMK.Settings:Set("pinTextureScale", value)
    if not changed then SMK:Print(message) end
    self:Refresh()
end

function PanelSettings:ChangePinNameOffset(axis, delta)
    local key = "mapPinNameOffset" .. axis
    local minVal = Config.mapPins["nameOffset" .. axis .. "Min"]
    local maxVal = Config.mapPins["nameOffset" .. axis .. "Max"]
    local value = math.max(minVal, math.min(maxVal, SMK.Settings:Get(key) + delta))
    local changed, message = SMK.Settings:Set(key, value)
    if not changed then SMK:Print(message) end
    self:Refresh()
end

function PanelSettings:Refresh()
    local pinsAvailable = SMK.MapPins:IsAvailable()

    local textureScale = SMK.Settings:Get("pinTextureScale") or Config.mapPins.defaultTextureScale
    self.pinTextureScaleValue:SetText(string.format("%d%%", math.floor(textureScale * 100 + 0.5)))
    self.pinTextureScaleMinus:SetEnabled(pinsAvailable and textureScale > Config.mapPins.minTextureScale)
    self.pinTextureScalePlus:SetEnabled(pinsAvailable and textureScale < Config.mapPins.maxTextureScale)
    SetLabelEnabled(self.pinTextureScaleLabel, pinsAvailable)

    local textScale = SMK.Settings:Get("mapPinTextScale") or Config.mapPins.defaultTextScale
    self.pinTextScaleValue:SetText(string.format("%d%%", math.floor(textScale * 100 + 0.5)))
    self.pinTextScaleMinus:SetEnabled(pinsAvailable and textScale > Config.mapPins.minTextScale)
    self.pinTextScalePlus:SetEnabled(pinsAvailable and textScale < Config.mapPins.maxTextScale)
    SetLabelEnabled(self.pinTextScaleLabel, pinsAvailable)

    local offsetX = SMK.Settings:Get("mapPinNameOffsetX") or Config.mapPins.defaultNameOffsetX
    self.pinNameOffsetXValue:SetText(tostring(offsetX))
    self.pinNameOffsetXMinus:SetEnabled(pinsAvailable and offsetX > Config.mapPins.nameOffsetXMin)
    self.pinNameOffsetXPlus:SetEnabled(pinsAvailable and offsetX < Config.mapPins.nameOffsetXMax)
    SetLabelEnabled(self.pinNameOffsetXLabel, pinsAvailable)

    local offsetY = SMK.Settings:Get("mapPinNameOffsetY") or Config.mapPins.defaultNameOffsetY
    self.pinNameOffsetYValue:SetText(tostring(offsetY))
    self.pinNameOffsetYMinus:SetEnabled(pinsAvailable and offsetY > Config.mapPins.nameOffsetYMin)
    self.pinNameOffsetYPlus:SetEnabled(pinsAvailable and offsetY < Config.mapPins.nameOffsetYMax)
    SetLabelEnabled(self.pinNameOffsetYLabel, pinsAvailable)
    if self.mapShortcutButton and not self.mapShortcutButton.isCapturing then
        self.mapShortcutButton:SetText(self:GetMapShortcutText())
    end
end

function PanelSettings:Open()
    self:Refresh()
    self.frame:Show()
end

function PanelSettings:Hide()
    if self.frame then self.frame:Hide() end
end

function PanelSettings:IsShown()
    return self.frame and self.frame:IsShown()
end

function PanelSettings:Create(anchor)
    local controls = Config.panel.controls
    local controlLeft, controlWidth = 164, 120
    local frame = CreateFrame(
        "Frame", SMK.name .. "PanelSettings", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(controls.settingsWidth, 235)
    frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(anchor:GetFrameLevel() + 10)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(Config.panel.backgroundAtlas, false)
    Widgets:ApplyPanelBorder(frame)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText(SMK.L.DISPLAY_SETTINGS)
    title:SetTextColor(unpack(Config.colors.gold))
    local close = Widgets:CreateCloseButton(frame)
    close:SetScript("OnClick", function() self:Hide() end)

    local function CreateRowLabel(text, y, indent)
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 20 + (indent or 0), y)
        label:SetText(text)
        label:SetTextColor(unpack(Config.colors.gold))
        return label
    end

    -- 标记材质大小
    self.pinTextureScaleLabel = CreateRowLabel(SMK.L.PIN_TEXTURE_SIZE, -57, 26)
    self.pinTextureScaleMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.pinTextureScaleMinus:SetPoint("TOPLEFT", controlLeft, -50)
    self.pinTextureScaleMinus:SetScript("OnClick", function()
        self:ChangePinTextureScale(-Config.mapPins.textureScaleStep)
    end)
    SetControlTooltip(self.pinTextureScaleMinus, SMK.L.PIN_TEXTURE_SIZE)
    self.pinTextureScaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.pinTextureScaleValue:SetPoint("LEFT", self.pinTextureScaleMinus, "RIGHT", 4, 0)
    self.pinTextureScaleValue:SetWidth(52)
    self.pinTextureScaleValue:SetJustifyH("CENTER")
    self.pinTextureScalePlus = Widgets:CreatePanelButton(frame, "+", { width = 30 })
    self.pinTextureScalePlus:SetPoint("LEFT", self.pinTextureScaleValue, "RIGHT", 4, 0)
    self.pinTextureScalePlus:SetScript("OnClick", function()
        self:ChangePinTextureScale(Config.mapPins.textureScaleStep)
    end)
    SetControlTooltip(self.pinTextureScalePlus, SMK.L.PIN_TEXTURE_SIZE)

    -- 名称文字大小
    self.pinTextScaleLabel = CreateRowLabel(SMK.L.PIN_TEXT_SIZE, -92, 26)
    self.pinTextScaleMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.pinTextScaleMinus:SetPoint("TOPLEFT", controlLeft, -85)
    self.pinTextScaleMinus:SetScript("OnClick", function()
        self:ChangePinTextScale(-Config.mapPins.textScaleStep)
    end)
    SetControlTooltip(self.pinTextScaleMinus, SMK.L.PIN_TEXT_SIZE)
    self.pinTextScaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.pinTextScaleValue:SetPoint("LEFT", self.pinTextScaleMinus, "RIGHT", 4, 0)
    self.pinTextScaleValue:SetWidth(52)
    self.pinTextScaleValue:SetJustifyH("CENTER")
    self.pinTextScalePlus = Widgets:CreatePanelButton(frame, "+", { width = 30 })
    self.pinTextScalePlus:SetPoint("LEFT", self.pinTextScaleValue, "RIGHT", 4, 0)
    self.pinTextScalePlus:SetScript("OnClick", function()
        self:ChangePinTextScale(Config.mapPins.textScaleStep)
    end)
    SetControlTooltip(self.pinTextScalePlus, SMK.L.PIN_TEXT_SIZE)

    -- 名称水平偏移
    self.pinNameOffsetXLabel = CreateRowLabel(SMK.L.PIN_NAME_OFFSET_X, -127, 26)
    self.pinNameOffsetXMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.pinNameOffsetXMinus:SetPoint("TOPLEFT", controlLeft, -120)
    self.pinNameOffsetXMinus:SetScript("OnClick", function()
        self:ChangePinNameOffset("X", -1)
    end)
    self.pinNameOffsetXValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.pinNameOffsetXValue:SetPoint("LEFT", self.pinNameOffsetXMinus, "RIGHT", 4, 0)
    self.pinNameOffsetXValue:SetWidth(52)
    self.pinNameOffsetXValue:SetJustifyH("CENTER")
    self.pinNameOffsetXPlus = Widgets:CreatePanelButton(frame, "+", { width = 30 })
    self.pinNameOffsetXPlus:SetPoint("LEFT", self.pinNameOffsetXValue, "RIGHT", 4, 0)
    self.pinNameOffsetXPlus:SetScript("OnClick", function()
        self:ChangePinNameOffset("X", 1)
    end)

    -- 名称垂直偏移
    self.pinNameOffsetYLabel = CreateRowLabel(SMK.L.PIN_NAME_OFFSET_Y, -162, 26)
    self.pinNameOffsetYMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.pinNameOffsetYMinus:SetPoint("TOPLEFT", controlLeft, -155)
    self.pinNameOffsetYMinus:SetScript("OnClick", function()
        self:ChangePinNameOffset("Y", -1)
    end)
    self.pinNameOffsetYValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.pinNameOffsetYValue:SetPoint("LEFT", self.pinNameOffsetYMinus, "RIGHT", 4, 0)
    self.pinNameOffsetYValue:SetWidth(52)
    self.pinNameOffsetYValue:SetJustifyH("CENTER")
    self.pinNameOffsetYPlus = Widgets:CreatePanelButton(frame, "+", { width = 30 })
    self.pinNameOffsetYPlus:SetPoint("LEFT", self.pinNameOffsetYValue, "RIGHT", 4, 0)
    self.pinNameOffsetYPlus:SetScript("OnClick", function()
        self:ChangePinNameOffset("Y", 1)
    end)

    -- 按住自定义组合键并左键点击地图；Esc 恢复默认 Alt+左键。
    self.mapShortcutLabel = CreateRowLabel(SMK.L.MAP_PIN_SHORTCUT, -197, 26)
    self.mapShortcutButton = Widgets:CreatePanelButton(
        frame, SMK.L.MAP_PIN_SHORTCUT_DEFAULT, { width = controlWidth })
    self.mapShortcutButton:SetPoint("TOPLEFT", controlLeft, -190)
    self.mapShortcutButton:SetScript("OnClick", function(button)
        if button.isCapturing then
            self:StopMapShortcutCapture()
        else
            self:StartMapShortcutCapture()
        end
    end)
    self.mapShortcutButton:SetScript("OnKeyDown", function(_, key)
        key = GetConvertedKeyOrButton(key)
        if key == "ESCAPE" then return self:ResetMapShortcut() end
        if not IsKeyPressIgnoredForBinding(key) then self:SetMapShortcut(key) end
    end)
    self.mapShortcutButton:SetScript("OnKeyUp", function(button, key)
        if not button.isCapturing then return end
        key = GetConvertedKeyOrButton(key)
        local modifier = key:match("ALT$") or key:match("CTRL$")
            or key:match("SHIFT$") or key:match("META$")
        if modifier then self:SetMapShortcut(nil, modifier) end
    end)
    self.mapShortcutButton:HookScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:SetText(SMK.L.MAP_PIN_SHORTCUT_TOOLTIP_TITLE)
        GameTooltip:AddLine(string.format(SMK.L.SHORTCUT_TOOLTIP_CURRENT,
            self:GetMapShortcutText()), 1, 1, 1)
        GameTooltip:AddLine(SMK.L.MAP_PIN_SHORTCUT_TOOLTIP_HINT, 0.35, 0.85, 1)
        GameTooltip:Show()
    end)
    self.mapShortcutButton:HookScript("OnLeave", GameTooltip_Hide)
    self:StopMapShortcutCapture()

    frame:HookScript("OnHide", function()
        if self.mapShortcutButton and self.mapShortcutButton.isCapturing then
            self:StopMapShortcutCapture()
        end
    end)

    return frame
end

SMK.PanelSettings = PanelSettings
