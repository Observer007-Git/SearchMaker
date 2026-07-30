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
    local frame = CreateFrame(
        "Frame", SMK.name .. "PanelSettings", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(controls.settingsWidth, 200)
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
    close:SetPoint("TOPRIGHT", -3, -3)
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
    self.pinTextureScaleMinus:SetPoint("TOPLEFT", 164, -50)
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
    self.pinTextScaleMinus:SetPoint("TOPLEFT", 164, -85)
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
    self.pinNameOffsetXMinus:SetPoint("TOPLEFT", 164, -120)
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
    self.pinNameOffsetYMinus:SetPoint("TOPLEFT", 164, -155)
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

    frame:HookScript("OnHide", function()
        if self.shortcutButton and self.shortcutButton.isCapturing and SMK.SearchBar then
            SMK.SearchBar:StopShortcutCapture()
        end
    end)

    return frame
end

SMK.PanelSettings = PanelSettings
