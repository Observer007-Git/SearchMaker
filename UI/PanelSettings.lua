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

function PanelSettings:ChangeLocationScale(delta)
    local value = math.max(Config.location.minScale,
        math.min(Config.location.maxScale, SMK.Settings:Get("locationScale") + delta))
    local changed, message = SMK.Settings:Set("locationScale", value)
    if not changed then SMK:Print(message) end
    self:Refresh()
end

function PanelSettings:ChangePinTextScale(delta)
    local value = math.max(Config.mapPins.minTextScale,
        math.min(Config.mapPins.maxTextScale, SMK.Settings:Get("mapPinTextScale") + delta))
    local changed, message = SMK.Settings:Set("mapPinTextScale", value)
    if not changed then SMK:Print(message) end
    self:Refresh()
end

function PanelSettings:SetPinTextColor(r, g, b)
    local changed, message = SMK.Settings:Set("mapPinTextColor", { r = r, g = g, b = b })
    if not changed then SMK:Print(message) end
    self:Refresh()
end

function PanelSettings:OpenPinTextColorPicker()
    local color = SMK.Settings:Get("mapPinTextColor")
    local previous = { r = color.r, g = color.g, b = color.b }
    ColorPickerFrame:Hide()
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ColorPickerFrame:SetFrameLevel(self.frame:GetFrameLevel() + 20)
    ColorPickerFrame:SetClampedToScreen(true)
    self.colorPickerOpen = true
    self.colorPickerCancelled = false
    ColorPickerFrame:SetupColorPickerAndShow({
        r = color.r,
        g = color.g,
        b = color.b,
        hasOpacity = false,
        swatchFunc = function()
            self.pinTextColorButton.swatch:SetColorTexture(ColorPickerFrame:GetColorRGB())
        end,
        cancelFunc = function()
            self.colorPickerCancelled = true
            self.pinTextColorButton.swatch:SetColorTexture(previous.r, previous.g, previous.b)
        end,
    })
end

function PanelSettings:Refresh()
    local locationScale = SMK.Settings:Get("locationScale")
    self.locationScaleValue:SetText(string.format("%d%%", math.floor(locationScale * 100 + 0.5)))
    self.locationScaleMinus:SetEnabled(locationScale > Config.location.minScale)
    self.locationScalePlus:SetEnabled(locationScale < Config.location.maxScale)

    local pinsAvailable = SMK.MapPins:IsAvailable()
    local showPins = SMK.Settings:Get("showMapPins")
    local showNames = SMK.Settings:Get("showMapPinNames")
    self.showPinsCheck:SetChecked(showPins)
    self.showPinsCheck:SetEnabled(pinsAvailable)
    SetLabelEnabled(self.showPinsLabel, pinsAvailable)

    local namesEnabled = pinsAvailable and showPins
    self.showPinNamesCheck:SetChecked(showNames)
    self.showPinNamesCheck:SetEnabled(namesEnabled)
    SetLabelEnabled(self.showPinNamesLabel, namesEnabled)

    local textEnabled = namesEnabled and showNames
    local color = SMK.Settings:Get("mapPinTextColor")
    self.pinTextColorButton.swatch:SetColorTexture(color.r, color.g, color.b)
    self.pinTextColorButton:SetEnabled(textEnabled)
    self.pinTextColorButton.swatch:SetAlpha(textEnabled and 1 or 0.35)
    SetLabelEnabled(self.pinTextColorLabel, textEnabled)

    local textScale = SMK.Settings:Get("mapPinTextScale")
    self.pinTextScaleValue:SetText(string.format("%d%%", math.floor(textScale * 100 + 0.5)))
    self.pinTextScaleMinus:SetEnabled(textEnabled and textScale > Config.mapPins.minTextScale)
    self.pinTextScalePlus:SetEnabled(textEnabled and textScale < Config.mapPins.maxTextScale)
    SetLabelEnabled(self.pinTextScaleLabel, textEnabled)
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
        and DoesAncestryIncludeAny(ColorPickerFrame, foci)
end

function PanelSettings:Create(anchor)
    local controls = Config.panel.controls
    local frame = CreateFrame("Frame", SMK.name .. "PanelSettings", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(controls.settingsWidth, 250)
    frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(anchor:GetFrameLevel() + 10)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop(Config.panelBackdrop)
    frame:SetBackdropColor(unpack(Config.colors.dialogBackground))
    frame:SetBackdropBorderColor(unpack(Config.colors.panelBorder))
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

    CreateRowLabel(SMK.L.LOCATION_SCALE, -53)
    self.locationScaleMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.locationScaleMinus:SetPoint("TOPLEFT", 164, -47)
    self.locationScaleMinus:SetScript("OnClick", function()
        self:ChangeLocationScale(-Config.location.scaleStep)
    end)
    self.locationScaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.locationScaleValue:SetPoint("LEFT", self.locationScaleMinus, "RIGHT", 4, 0)
    self.locationScaleValue:SetWidth(52)
    self.locationScaleValue:SetJustifyH("CENTER")
    self.locationScalePlus = Widgets:CreatePanelButton(frame, "+", { width = 30 })
    self.locationScalePlus:SetPoint("LEFT", self.locationScaleValue, "RIGHT", 4, 0)
    self.locationScalePlus:SetScript("OnClick", function()
        self:ChangeLocationScale(Config.location.scaleStep)
    end)

    self.showPinsCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.showPinsCheck:SetSize(24, 24)
    self.showPinsCheck:SetPoint("TOPLEFT", 16, -78)
    self.showPinsLabel = CreateRowLabel(SMK.L.SHOW_MAP_PINS, -82, 26)
    self.showPinsCheck:SetScript("OnClick", function()
        local changed, message = SMK.Settings:Set("showMapPins", self.showPinsCheck:GetChecked())
        if not changed then SMK:Print(message) end
        self:Refresh()
    end)

    self.showPinNamesCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.showPinNamesCheck:SetSize(24, 24)
    self.showPinNamesCheck:SetPoint("TOPLEFT", 40, -108)
    self.showPinNamesLabel = CreateRowLabel(SMK.L.SHOW_MAP_PIN_NAMES, -112, 50)
    self.showPinNamesCheck:SetScript("OnClick", function()
        local changed, message = SMK.Settings:Set("showMapPinNames",
            self.showPinNamesCheck:GetChecked())
        if not changed then SMK:Print(message) end
        self:Refresh()
    end)

    self.pinTextColorLabel = CreateRowLabel(SMK.L.PIN_TEXT_COLOR, -148, 50)
    self.pinTextColorButton = Widgets:CreatePanelButton(frame, "", { width = 42 })
    self.pinTextColorButton:SetPoint("TOPLEFT", 220, -141)
    self.pinTextColorButton.swatch = self.pinTextColorButton:CreateTexture(nil, "ARTWORK")
    self.pinTextColorButton.swatch:SetPoint("TOPLEFT", 8, -6)
    self.pinTextColorButton.swatch:SetPoint("BOTTOMRIGHT", -8, 6)
    self.pinTextColorButton:SetScript("OnClick", function() self:OpenPinTextColorPicker() end)
    SetControlTooltip(self.pinTextColorButton, SMK.L.PIN_TEXT_COLOR)

    self.pinTextScaleLabel = CreateRowLabel(SMK.L.PIN_TEXT_SIZE, -183, 50)
    self.pinTextScaleMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.pinTextScaleMinus:SetPoint("TOPLEFT", 164, -176)
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

    CreateRowLabel(SMK.L.SHORTCUT, -218)
    self.shortcutButton = Widgets:CreatePanelButton(frame, SMK.L.SHORTCUT, { width = 146 })
    self.shortcutButton:SetPoint("TOPLEFT", 164, -211)

    frame:HookScript("OnHide", function()
        if self.colorPickerOpen and ColorPickerFrame and ColorPickerFrame:IsShown() then
            self.colorPickerCancelled = true
            ColorPickerFrame:Hide()
        end
        if self.shortcutButton.isCapturing and SMK.SearchBar then
            SMK.SearchBar:StopShortcutCapture()
        end
    end)
    if ColorPickerFrame then
        ColorPickerFrame:HookScript("OnHide", function()
            if not self.colorPickerOpen then return end
            self.colorPickerOpen = false
            if self.colorPickerCancelled then
                self:Refresh()
            else
                self:SetPinTextColor(ColorPickerFrame:GetColorRGB())
            end
        end)
    end

    return frame
end

SMK.PanelSettings = PanelSettings
