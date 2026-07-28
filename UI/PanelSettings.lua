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

function PanelSettings:OpenPinTextColor()
    local previous = SMK.Settings:Get("mapPinTextColor")
    previous = { r = previous.r, g = previous.g, b = previous.b }
    self.colorPickerOpen = false
    ColorPickerFrame:Hide()
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ColorPickerFrame:SetFrameLevel(self.frame:GetFrameLevel() + 20)
    ColorPickerFrame:SetClampedToScreen(true)
    self.colorPickerOpen = true
    self.colorPickerCancelled = false
    self.pendingPinTextColor = previous
    ColorPickerFrame:SetupColorPickerAndShow({
        r = previous.r,
        g = previous.g,
        b = previous.b,
        hasOpacity = false,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            self.pendingPinTextColor = { r = r, g = g, b = b }
            self.pinTextColorButton.swatch:SetColorTexture(r, g, b)
            SMK.MapPins:PreviewDefaultPinTextColor(self.pendingPinTextColor)
        end,
        cancelFunc = function()
            self.colorPickerCancelled = true
            self.pendingPinTextColor = previous
            self.pinTextColorButton.swatch:SetColorTexture(previous.r, previous.g, previous.b)
            SMK.MapPins:PreviewDefaultPinTextColor(previous)
        end,
    })
end

function PanelSettings:Refresh()
    local pinsAvailable = SMK.MapPins:IsAvailable()
    local showTextures = SMK.Settings:Get("showPinTextures")
    local showNames = SMK.Settings:Get("showMapPinNames")

    self.showPinTexturesCheck:SetChecked(showTextures)
    self.showPinTexturesCheck:SetEnabled(pinsAvailable)
    SetLabelEnabled(self.showPinTexturesLabel, pinsAvailable)

    local texturesEnabled = pinsAvailable and showTextures
    local textureScale = SMK.Settings:Get("pinTextureScale") or Config.mapPins.defaultTextureScale
    self.pinTextureScaleValue:SetText(string.format("%d%%", math.floor(textureScale * 100 + 0.5)))
    self.pinTextureScaleMinus:SetEnabled(texturesEnabled and textureScale > (Config.mapPins.minTextureScale or 0))
    self.pinTextureScalePlus:SetEnabled(texturesEnabled and textureScale < (Config.mapPins.maxTextureScale or 2))
    SetLabelEnabled(self.pinTextureScaleLabel, texturesEnabled)

    self.showPinNamesCheck:SetChecked(showNames)
    self.showPinNamesCheck:SetEnabled(pinsAvailable)
    SetLabelEnabled(self.showPinNamesLabel, pinsAvailable)

    local nameControlsEnabled = pinsAvailable and showNames
    local textColor = SMK.Settings:Get("mapPinTextColor")
    self.pinTextColorButton.swatch:SetColorTexture(textColor.r, textColor.g, textColor.b)
    self.pinTextColorButton:SetEnabled(nameControlsEnabled)
    self.pinTextColorButton.swatch:SetAlpha(nameControlsEnabled and 1 or 0.3)
    SetLabelEnabled(self.pinTextColorLabel, nameControlsEnabled)

    local textScale = SMK.Settings:Get("mapPinTextScale") or Config.mapPins.defaultTextScale
    self.pinTextScaleValue:SetText(string.format("%d%%", math.floor(textScale * 100 + 0.5)))
    self.pinTextScaleMinus:SetEnabled(nameControlsEnabled and textScale > (Config.mapPins.minTextScale or 0))
    self.pinTextScalePlus:SetEnabled(nameControlsEnabled and textScale < (Config.mapPins.maxTextScale or 2))
    SetLabelEnabled(self.pinTextScaleLabel, nameControlsEnabled)

    local offsetX = SMK.Settings:Get("mapPinNameOffsetX") or Config.mapPins.defaultNameOffsetX
    self.pinNameOffsetXValue:SetText(tostring(offsetX))
    self.pinNameOffsetXMinus:SetEnabled(nameControlsEnabled and offsetX > (Config.mapPins.nameOffsetXMin or -50))
    self.pinNameOffsetXPlus:SetEnabled(nameControlsEnabled and offsetX < (Config.mapPins.nameOffsetXMax or 50))
    SetLabelEnabled(self.pinNameOffsetXLabel, nameControlsEnabled)

    local offsetY = SMK.Settings:Get("mapPinNameOffsetY") or Config.mapPins.defaultNameOffsetY
    self.pinNameOffsetYValue:SetText(tostring(offsetY))
    self.pinNameOffsetYMinus:SetEnabled(nameControlsEnabled and offsetY > (Config.mapPins.nameOffsetYMin or -50))
    self.pinNameOffsetYPlus:SetEnabled(nameControlsEnabled and offsetY < (Config.mapPins.nameOffsetYMax or 50))
    SetLabelEnabled(self.pinNameOffsetYLabel, nameControlsEnabled)
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

function PanelSettings:ContainsMouseFocus(foci)
    return self.colorPickerOpen and ColorPickerFrame and ColorPickerFrame:IsShown()
        and DoesAncestryIncludeAny and DoesAncestryIncludeAny(ColorPickerFrame, foci)
end

function PanelSettings:Create(anchor)
    local controls = Config.panel.controls
    local frame = CreateFrame("Frame", SMK.name .. "PanelSettings", UIParent)
    self.frame = frame
    frame:SetSize(controls.settingsWidth, 335)
    frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(anchor:GetFrameLevel() + 10)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(Config.panel.backgroundAtlas, false)
    frame.borderAtlas = frame:CreateTexture(nil, "BORDER", nil, 7)
    frame.borderAtlas:SetAllPoints(frame)
    frame.borderAtlas:SetAtlas(Config.panel.borderAtlas, false)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText(SMK.L.DISPLAY_SETTINGS)
    title:SetTextColor(unpack(Config.colors.gold))
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() self:Hide() end)

    local function CreateRowLabel(text, y, indent)
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 20 + (indent or 0), y)
        label:SetText(text)
        label:SetTextColor(unpack(Config.colors.gold))
        return label
    end

    -- 显示标记材质
    self.showPinTexturesCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.showPinTexturesCheck:SetSize(24, 24)
    self.showPinTexturesCheck:SetPoint("TOPLEFT", 16, -53)
    self.showPinTexturesLabel = CreateRowLabel(SMK.L.SHOW_PIN_TEXTURES, -57, 26)
    self.showPinTexturesCheck:SetScript("OnClick", function()
        local changed, message = SMK.Settings:Set("showPinTextures",
            self.showPinTexturesCheck:GetChecked())
        if not changed then SMK:Print(message) end
        self:Refresh()
    end)

    -- 标记材质大小
    self.pinTextureScaleLabel = CreateRowLabel(SMK.L.PIN_TEXTURE_SIZE, -88, 26)
    self.pinTextureScaleMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.pinTextureScaleMinus:SetPoint("TOPLEFT", 164, -81)
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

    -- 显示标记名称
    self.showPinNamesCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.showPinNamesCheck:SetSize(24, 24)
    self.showPinNamesCheck:SetPoint("TOPLEFT", 16, -118)
    self.showPinNamesLabel = CreateRowLabel(SMK.L.SHOW_MAP_PIN_NAMES, -122, 26)
    self.showPinNamesCheck:SetScript("OnClick", function()
        local changed, message = SMK.Settings:Set("showMapPinNames",
            self.showPinNamesCheck:GetChecked())
        if not changed then SMK:Print(message) end
        self:Refresh()
    end)

    -- 全局标记文字颜色；单地点可在编辑器中覆盖。
    self.pinTextColorLabel = CreateRowLabel(SMK.L.PIN_COLOR_LABEL, -153, 26)
    self.pinTextColorButton = Widgets:CreatePanelButton(frame, "", { width = 42 })
    self.pinTextColorButton:SetPoint("TOPLEFT", 220, -146)
    self.pinTextColorButton.swatch = self.pinTextColorButton:CreateTexture(nil, "ARTWORK")
    self.pinTextColorButton.swatch:SetPoint("TOPLEFT", 8, -6)
    self.pinTextColorButton.swatch:SetPoint("BOTTOMRIGHT", -8, 6)
    self.pinTextColorButton:SetScript("OnClick", function() self:OpenPinTextColor() end)
    ColorPickerFrame:HookScript("OnHide", function()
        if not self.colorPickerOpen then return end
        self.colorPickerOpen = false
        local color = self.pendingPinTextColor
        self.pendingPinTextColor = nil
        if not self.colorPickerCancelled and color then
            local changed, message = SMK.Settings:Set("mapPinTextColor", color)
            if not changed then
                SMK:Print(message)
                local saved = SMK.Settings:Get("mapPinTextColor")
                self.pinTextColorButton.swatch:SetColorTexture(saved.r, saved.g, saved.b)
                SMK.MapPins:PreviewDefaultPinTextColor(saved)
            end
        end
        self.colorPickerCancelled = false
        self:Refresh()
    end)

    -- 名称文字大小
    self.pinTextScaleLabel = CreateRowLabel(SMK.L.PIN_TEXT_SIZE, -188, 26)
    self.pinTextScaleMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.pinTextScaleMinus:SetPoint("TOPLEFT", 164, -181)
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
    self.pinNameOffsetXLabel = CreateRowLabel(SMK.L.PIN_NAME_OFFSET_X, -223, 26)
    self.pinNameOffsetXMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.pinNameOffsetXMinus:SetPoint("TOPLEFT", 164, -216)
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
    self.pinNameOffsetYLabel = CreateRowLabel(SMK.L.PIN_NAME_OFFSET_Y, -258, 26)
    self.pinNameOffsetYMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.pinNameOffsetYMinus:SetPoint("TOPLEFT", 164, -251)
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
        if self.colorPickerOpen and ColorPickerFrame and ColorPickerFrame:IsShown() then
            ColorPickerFrame:Hide()
        end
        self.colorPickerOpen = false
        if self.shortcutButton and self.shortcutButton.isCapturing and SMK.SearchBar then
            SMK.SearchBar:StopShortcutCapture()
        end
    end)

    return frame
end

SMK.PanelSettings = PanelSettings
