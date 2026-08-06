local _, SMK = ...

local SearchBarSettings = {}
local Config = SMK.Config
local Widgets = SMK.Widgets

function SearchBarSettings:GetStyleLabel()
    local styles = Config.search.appearance.styles
    local style = SMK.Settings:Get("searchBarStyle")
    if style == styles.noPortrait then
        return SMK.L.SEARCH_BAR_STYLE_NO_PORTRAIT
    elseif style == styles.blizzard then
        return SMK.L.SEARCH_BAR_STYLE_BLIZZARD
    end
    return SMK.L.SEARCH_BAR_STYLE_PORTRAIT
end

function SearchBarSettings:Refresh()
    local appearance = Config.search.appearance
    local scale = math.max(appearance.minScale,
        SMK.Settings:Get("searchBarScale") or appearance.defaultScale)
    self.scaleValue:SetText(string.format("%d%%", math.floor(scale * 100 + 0.5)))
    self.scaleMinus:SetEnabled(scale > appearance.minScale)
    self.scalePlus:SetEnabled(scale < appearance.maxScale)
    local opacity = math.max(appearance.minOpacity,
        SMK.Settings:Get("searchBarOpacity") or appearance.defaultOpacity)
    self.opacityValue:SetText(string.format("%d%%", math.floor(opacity * 100 + 0.5)))
    self.opacityMinus:SetEnabled(opacity > appearance.minOpacity)
    self.opacityPlus:SetEnabled(opacity < appearance.maxOpacity)
    if self.styleDropdown and self.styleDropdown.Text then
        self.styleDropdown.Text:SetText(self:GetStyleLabel())
    end
    self.mapOnlyCheck:SetChecked(SMK.Settings:Get("searchBarMapOnly") == true)
    self.thirdPartyCheck:SetChecked(
        SMK.Settings:Get("thirdPartySearchEnabled") == true)
end

function SearchBarSettings:ChangeScale(delta)
    local appearance = Config.search.appearance
    local value = math.max(appearance.minScale, math.min(appearance.maxScale,
        (SMK.Settings:Get("searchBarScale") or appearance.defaultScale) + delta))
    local changed = SMK.Settings:Set("searchBarScale", math.floor(value * 10 + 0.5) / 10)
    if changed then SMK.SearchBar:ApplyScale() end
    self:Refresh()
end

function SearchBarSettings:ChangeOpacity(delta)
    local appearance = Config.search.appearance
    local value = math.max(appearance.minOpacity, math.min(appearance.maxOpacity,
        (SMK.Settings:Get("searchBarOpacity") or appearance.defaultOpacity) + delta))
    local changed = SMK.Settings:Set("searchBarOpacity", math.floor(value * 10 + 0.5) / 10)
    if changed then SMK.SearchBar:ApplyOpacity() end
    self:Refresh()
end

function SearchBarSettings:SetStyle(value)
    if SMK.Settings:Get("searchBarStyle") == value then return end
    local changed, message = SMK.Settings:Set("searchBarStyle", value)
    if not changed then return SMK:Print(message) end
    SMK.SearchBar:ApplyStyle()
    self:Refresh()
end

function SearchBarSettings:Open()
    self:Refresh()
    self.frame:Show()
end

function SearchBarSettings:Hide()
    if self.frame then self.frame:Hide() end
end

function SearchBarSettings:IsShown()
    return self.frame and self.frame:IsShown()
end

function SearchBarSettings:IsMenuOpen()
    return self.styleDropdown and self.styleDropdown.IsMenuOpen
        and self.styleDropdown:IsMenuOpen()
end

function SearchBarSettings:ContainsMouseFocus() return false end

function SearchBarSettings:Create(anchor)
    local controls = Config.panel.controls
    local frame = CreateFrame(
        "Frame", SMK.name .. "SearchBarSettings", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(controls.settingsWidth, 280)
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
    title:SetText(SMK.L.SEARCH_BAR_SETTINGS)
    title:SetTextColor(unpack(Config.colors.gold))
    local close = Widgets:CreateCloseButton(frame)
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() self:Hide() end)

    local function Label(text, y, indent)
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 20 + (indent or 0), y)
        label:SetText(text)
        label:SetTextColor(unpack(Config.colors.gold))
        return label
    end

    -- 搜索框缩放
    local scaleY = -53
    self.scaleLabel = Label(SMK.L.SEARCH_BAR_SCALE, scaleY, 0)
    self.scaleMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.scaleMinus:SetPoint("TOPLEFT", 164, scaleY + 3)
    self.scaleMinus:SetScript("OnClick", function()
        self:ChangeScale(-Config.search.appearance.scaleStep)
    end)
    self.scaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.scaleValue:SetPoint("LEFT", self.scaleMinus, "RIGHT", 4, 0)
    self.scaleValue:SetWidth(52)
    self.scaleValue:SetJustifyH("CENTER")
    self.scalePlus = Widgets:CreatePanelButton(frame, "+", { width = 30 })
    self.scalePlus:SetPoint("LEFT", self.scaleValue, "RIGHT", 4, 0)
    self.scalePlus:SetScript("OnClick", function()
        self:ChangeScale(Config.search.appearance.scaleStep)
    end)

    -- 搜索框背景透明度
    local opacityY = -88
    self.opacityLabel = Label(SMK.L.SEARCH_BAR_OPACITY, opacityY, 0)
    self.opacityMinus = Widgets:CreatePanelButton(frame, "-", { width = 30 })
    self.opacityMinus:SetPoint("TOPLEFT", 164, opacityY + 3)
    self.opacityMinus:SetScript("OnClick", function()
        self:ChangeOpacity(-Config.search.appearance.opacityStep)
    end)
    self.opacityValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.opacityValue:SetPoint("LEFT", self.opacityMinus, "RIGHT", 4, 0)
    self.opacityValue:SetWidth(52)
    self.opacityValue:SetJustifyH("CENTER")
    self.opacityPlus = Widgets:CreatePanelButton(frame, "+", { width = 30 })
    self.opacityPlus:SetPoint("LEFT", self.opacityValue, "RIGHT", 4, 0)
    self.opacityPlus:SetScript("OnClick", function()
        self:ChangeOpacity(Config.search.appearance.opacityStep)
    end)

    -- 搜索框 UI 样式
    local styleY = -123
    self.styleLabel = Label(SMK.L.SEARCH_BAR_STYLE, styleY, 0)
    self.styleDropdown = CreateFrame(
        "DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    self.styleDropdown:SetSize(140, controls.buttonHeight)
    self.styleDropdown:SetPoint("TOPLEFT", 164, styleY + 3)
    self.styleDropdown:SetSelectionText(function()
        return self:GetStyleLabel()
    end)
    self.styleDropdown:SetupMenu(function(_, root)
        local styles = Config.search.appearance.styles
        local function AddStyle(label, value)
            root:CreateRadio(label,
                function(selected)
                    return SMK.Settings:Get("searchBarStyle") == selected
                end,
                function(selected) self:SetStyle(selected) end,
                value)
        end
        AddStyle(SMK.L.SEARCH_BAR_STYLE_PORTRAIT, styles.portrait)
        AddStyle(SMK.L.SEARCH_BAR_STYLE_NO_PORTRAIT, styles.noPortrait)
        AddStyle(SMK.L.SEARCH_BAR_STYLE_BLIZZARD, styles.blizzard)
    end)

    -- 呼出快捷键按钮
    local shortcutY = -158
    self.shortcutLabel = Label(SMK.L.SHORTCUT, shortcutY, 0)
    self.shortcutButton = Widgets:CreatePanelButton(frame, SMK.L.SHORTCUT_KEY, { minWidth = 140 })
    self.shortcutButton:SetPoint("TOPLEFT", 140, shortcutY + 3)
    self.shortcutButton:SetScript("OnClick", function()
        SMK.ShortcutController:OnClick()
    end)

    self.mapOnlyCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.mapOnlyCheck:SetSize(24, 24)
    self.mapOnlyCheck:SetPoint("TOPLEFT", 20, -193)
    self.mapOnlyCheck:SetScript("OnClick", function(button)
        local changed, message = SMK.Settings:Set(
            "searchBarMapOnly", button:GetChecked() == true)
        if not changed then
            button:SetChecked(not button:GetChecked())
            if message then SMK:Print(message) end
        end
    end)
    local mapOnlyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mapOnlyLabel:SetPoint("LEFT", self.mapOnlyCheck, "RIGHT", 4, 0)
    mapOnlyLabel:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    mapOnlyLabel:SetJustifyH("LEFT")
    mapOnlyLabel:SetText(SMK.L.SEARCH_BAR_MAP_ONLY)
    mapOnlyLabel:SetTextColor(unpack(Config.colors.gold))

    self.thirdPartyCheck = CreateFrame(
        "CheckButton", nil, frame, "UICheckButtonTemplate")
    self.thirdPartyCheck:SetSize(24, 24)
    self.thirdPartyCheck:SetPoint("TOPLEFT", 20, -225)
    self.thirdPartyCheck:SetScript("OnClick", function(button)
        local changed, message = SMK.Settings:Set(
            "thirdPartySearchEnabled", button:GetChecked() == true)
        if not changed then
            button:SetChecked(not button:GetChecked())
            if message then SMK:Print(message) end
        end
    end)
    local thirdPartyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thirdPartyLabel:SetPoint("LEFT", self.thirdPartyCheck, "RIGHT", 4, 0)
    thirdPartyLabel:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    thirdPartyLabel:SetJustifyH("LEFT")
    thirdPartyLabel:SetText(SMK.L.THIRD_PARTY_SEARCH_ENABLED)
    thirdPartyLabel:SetTextColor(unpack(Config.colors.gold))

    frame:HookScript("OnHide", function()
        if self.shortcutButton and self.shortcutButton.isCapturing and SMK.SearchBar then
            SMK.SearchBar:StopShortcutCapture()
        end
    end)

    return frame
end

SMK.SearchBarSettings = SearchBarSettings
