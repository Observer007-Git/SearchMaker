local _, SMK = ...

local MainPanel = {}
local Config = SMK.Config
local Widgets = SMK.Widgets

local function CategoryHeadingHeight()
    return Config.location.baseHeight * Config.categoryHeadingScale
end

--- 从部件池获取一个部件（标题、按钮或消息）。
-- 如果没有可用的空闲部件则创建一个新的。
-- @param kind string "heading"、"button" 或 "message"。
-- @return Frame 部件。
function MainPanel:Acquire(kind)
    for _, widget in ipairs(self.listWidgets) do
        if not widget.inUse and widget.kind == kind then
            widget.inUse = true
            widget:Show()
            return widget
        end
    end
    local widget
    if kind == "heading" then
        widget = Widgets:CreateCategoryHeading(self.listContent)
    elseif kind == "message" then
        widget = self.listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    else
        widget = Widgets:CreateLocationButton(self.listContent, self.locationCallbacks)
    end
    widget.kind, widget.inUse = kind, true
    self.listWidgets[#self.listWidgets + 1] = widget
    return widget
end

--- 将所有池化部件恢复为空闲状态（隐藏、清除定位点）。
function MainPanel:ReleaseWidgets()
    for _, widget in ipairs(self.listWidgets) do
        widget.inUse = false
        widget:Hide()
        widget:ClearAllPoints()
    end
end

--- 渲染当前地图上的所有地点，按类别分组，按名称排序。
-- 使用部件池（Acquire/Release）最小化框架创建。
function MainPanel:RenderList()
    self:ReleaseWidgets()
    local entries = SMK.State.currentEntries
    if #entries == 0 then
        local empty = self:Acquire("message")
        empty:SetTextColor(unpack(Config.colors.disabled))
        empty:SetText(SMK.L.NO_LOCATIONS)
        empty:SetPoint("TOP", self.listContent, "TOP", 0, -28)
        self.listContent:SetHeight(90)
        return
    end
    local groups = {}
    for _, entry in ipairs(entries) do
        local catKey = entry.categoryKey
        groups[catKey] = groups[catKey] or {}
        groups[catKey][#groups[catKey] + 1] = entry
    end
    local y = 6
    local headingHeight = CategoryHeadingHeight()
    for _, categoryInfo in ipairs(Config.categories) do
        local categoryEntries = groups[categoryInfo.key]
        if categoryEntries then
            table.sort(categoryEntries, function(a, b) return a.name < b.name end)
            local heading = self:Acquire("heading")
            heading:SetSize(math.max(1, self.listContent:GetWidth() - 8), headingHeight)
            Widgets:SetCategory(heading, SMK.L[categoryInfo.nameKey] or categoryInfo.key, categoryInfo.key)
            heading:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 4, -y)
            local startX = 4 + heading.leftWidth
            local rowX = startX
            local rowY = y + headingHeight + Config.location.verticalGap
            local rowHeight = 0
            for _, entry in ipairs(categoryEntries) do
                local button = self:Acquire("button")
                button.background:Show()
                Widgets:SetLocationEntry(button, entry)
                local width, height = button:GetWidth(), button:GetHeight()
                if rowX > startX and rowX + width > self.listContent:GetWidth() - startX then
                    rowX = startX
                    rowY = rowY + rowHeight + Config.location.verticalGap
                    rowHeight = 0
                end
                button:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", rowX, -rowY)
                rowX = rowX + width + Config.location.horizontalGap
                rowHeight = math.max(rowHeight, height)
            end
            y = rowY + rowHeight + Config.location.groupGap
        end
    end
    self.listContent:SetHeight(math.max(y, 100))
end

--- 收集使用次数不为零的地点，按使用频率排序。
-- @return table { entry, count } 数组。
function MainPanel:GetFrequent()
    local frequent = {}
    for _, entry in ipairs(SMK.State.currentEntries) do
        local count = SMK.Store:GetUsage(entry)
        if count > 0 then frequent[#frequent + 1] = { entry = entry, count = count } end
    end
    table.sort(frequent, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.entry.name < b.entry.name
    end)
    return frequent
end

--- 渲染"常用"行，显示最近使用过的地点。
function MainPanel:RenderFrequent()
    local frequent = self:GetFrequent()
    local visible = math.min(#frequent, Config.location.maxFrequent)
    self.frequentEmpty:SetShown(visible == 0)
    local startX = 2 + CategoryHeadingHeight() * Config.art.textLeft / Config.art.buttonArtHeight
    local x, y, rowHeight, firstRowHeight = startX, 0, 0, nil
    local available = self.frequentRow:GetWidth() > 0 and self.frequentRow:GetWidth() or Config.panel.width - 28
    for index = 1, visible do
        local button = self.frequentButtons[index]
        if not button then
            button = Widgets:CreateLocationButton(self.frequentRow, self.locationCallbacks)
            self.frequentButtons[index] = button
        end
        button:ClearAllPoints()
        button.background:Show()
        Widgets:SetLocationEntry(button, frequent[index].entry)
        local width, height = button:GetWidth(), button:GetHeight()
        if x > startX and x + width > available - startX then
            firstRowHeight = firstRowHeight or rowHeight
            x, y, rowHeight = startX, y + rowHeight + Config.location.verticalGap, 0
        end
        button:SetPoint("TOPLEFT", self.frequentRow, "TOPLEFT", x, -y)
        x, rowHeight = x + width + Config.location.horizontalGap, math.max(rowHeight, height)
    end
    firstRowHeight = firstRowHeight or rowHeight
    self.frequentRow:SetHeight(visible > 0 and y + rowHeight or Config.location.baseHeight)
    self.frequentRow.title:ClearAllPoints()
    self.frequentRow.title:SetPoint("TOPLEFT", 4,
        -math.max(0, ((visible > 0 and firstRowHeight or Config.location.baseHeight)
            - self.frequentRow.title:GetStringHeight()) / 2))
    self.frequentEmpty:ClearAllPoints()
    self.frequentEmpty:SetPoint("TOPLEFT", 60,
        -math.max(0, (Config.location.baseHeight - self.frequentEmpty:GetStringHeight()) / 2))
    for index = visible + 1, #self.frequentButtons do self.frequentButtons[index]:Hide() end
end

function MainPanel:RefreshHeader()
    local mapID = SMK.State.currentMapID
    self.frame.mapName:SetText(mapID and string.format(SMK.L.MAP_FORMAT, SMK.Map:GetMapName(mapID), mapID)
        or SMK.L.UNKNOWN_MAP)
    if self.frame.mapName.GetUnboundedStringWidth then
        self.frame.mapName:SetWidth(math.ceil(self.frame.mapName:GetUnboundedStringWidth()))
    end
    self.frame.locationCount:SetText(string.format(SMK.L.LOCATION_COUNT,
        #SMK.State.currentEntries, SMK.State.totalLocationCount))
end

--- 全面板刷新：头部、地点列表、常用列表、缩放控件。
function MainPanel:Refresh()
    self:RefreshHeader()
    self:RenderList()
    self:RenderFrequent()
    self:UpdateScaleControls()
end

function MainPanel:UpdateScaleControls()
    local scale = SMK.Settings:Get("locationScale")
    self.scaleValue:SetText(string.format("%d%%", math.floor(scale * 100 + 0.5)))
    self.frame.locationScaleMinus:SetEnabled(scale > Config.location.minScale)
    self.frame.locationScalePlus:SetEnabled(scale < Config.location.maxScale)
    self.showPinsCheck:SetChecked(SMK.Settings:Get("showMapPins"))
    self.showPinNamesCheck:SetChecked(SMK.Settings:Get("showMapPinNames"))
    local color = SMK.Settings:Get("mapPinTextColor")
    self.pinTextColorButton.swatch:SetColorTexture(color.r, color.g, color.b)
    local textScale = SMK.Settings:Get("mapPinTextScale")
    local pinsAvailable = SMK.MapPins:IsAvailable()
    self.pinTextScaleValue:SetText(string.format("%d%%", math.floor(textScale * 100 + 0.5)))
    self.pinTextColorButton:SetEnabled(pinsAvailable)
    self.pinTextColorButton.swatch:SetAlpha(pinsAvailable and 1 or 0.45)
    self.pinTextScaleMinus:SetEnabled(pinsAvailable and textScale > Config.mapPins.minTextScale)
    self.pinTextScalePlus:SetEnabled(pinsAvailable and textScale < Config.mapPins.maxTextScale)
end

--- 调整图标/文字缩放并刷新。
-- @param delta number 增加或减少步长。
function MainPanel:ChangeScale(delta)
    local value = math.max(Config.location.minScale,
        math.min(Config.location.maxScale, SMK.Settings:Get("locationScale") + delta))
    local changed, message = SMK.Settings:Set("locationScale", value)
    if not changed then SMK:Print(message) end
end

function MainPanel:ChangePinTextScale(delta)
    local value = math.max(Config.mapPins.minTextScale,
        math.min(Config.mapPins.maxTextScale, SMK.Settings:Get("mapPinTextScale") + delta))
    local changed, message = SMK.Settings:Set("mapPinTextScale", value)
    if not changed then SMK:Print(message) end
    self:UpdateScaleControls()
end

function MainPanel:SetPinTextColor(r, g, b)
    local changed, message = SMK.Settings:Set("mapPinTextColor", { r = r, g = g, b = b })
    if not changed then SMK:Print(message) end
    self:UpdateScaleControls()
end

function MainPanel:OpenPinTextColorPicker()
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

function MainPanel:HideDialogs()
    SMK.ModalManager:HideAll()
end

--- 显示或隐藏面板框架。
-- @param expanded boolean
function MainPanel:SetExpanded(expanded)
    self.frame.isExpanded = expanded
    if expanded then
        self.frame:Show()
        self:Refresh()
    else
        self:HideDialogs()
        self.frame:Hide()
    end
end

function MainPanel:IsExpanded()
    return self.frame.isExpanded and self.frame:IsShown()
end

function MainPanel:SetSearchActive(active)
    self.frequentRow:SetShown(not active)
end

function MainPanel:ContainsMouseFocus(foci)
    if not DoesAncestryIncludeAny then return false end
    if self.colorPickerOpen and ColorPickerFrame and ColorPickerFrame:IsShown()
        and DoesAncestryIncludeAny(ColorPickerFrame, foci) then return true end
    return self.frame and DoesAncestryIncludeAny(self.frame, foci)
end

function MainPanel:OpenEditor(mode, entry)
    SMK.ModalManager:PrepareToShow(SMK.LocationEditor)
    if self.callbacks.onDialogOpened then self.callbacks.onDialogOpened() end
    SMK.LocationEditor:Open(mode, entry)
end

function MainPanel:OpenShare()
    SMK.ModalManager:PrepareToShow(SMK.ShareDialog)
    if self.callbacks.onDialogOpened then self.callbacks.onDialogOpened() end
    SMK.ShareDialog:Open()
end

function MainPanel:OpenBulkDelete()
    SMK.ModalManager:PrepareToShow(SMK.BulkDeleteDialog)
    if self.callbacks.onDialogOpened then self.callbacks.onDialogOpened() end
    SMK.BulkDeleteDialog:Open()
end

function MainPanel:Create(searchBar, callbacks)
    self.callbacks = callbacks or {}
    self.listWidgets, self.frequentButtons = {}, {}
    self.locationCallbacks = {
        onActivate = self.callbacks.onActivate,
        onEdit = function(entry) self:OpenEditor("edit", entry) end,
        onDelete = self.callbacks.onDelete,
    }
    local frame = CreateFrame("Frame", SMK.name .. "Panel", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(Config.panel.width, Config.panel.height)
    frame:SetPoint("TOP", searchBar, "BOTTOM", 0, -2)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(70)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(Config.panel.backgroundAtlas, false)
    frame.borderAtlas = frame:CreateTexture(nil, "BORDER", nil, 7)
    frame.borderAtlas:SetAllPoints(frame)
    frame.borderAtlas:SetAtlas(Config.panel.borderAtlas, false)
    frame.isExpanded = false
    frame:Hide()
    table.insert(UISpecialFrames, frame:GetName())

    frame.mapName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.mapName:SetPoint("TOPLEFT", 18, -17)
    frame.mapName:SetWidth(265)
    frame.mapName:SetJustifyH("LEFT")
    frame.mapName:SetWordWrap(false)
    frame.mapName:SetTextColor(unpack(Config.colors.gold))
    frame.locationCount = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.locationCount:SetPoint("LEFT", frame.mapName, "RIGHT", 6, 0)
    frame.locationCount:SetWidth(120)
    frame.locationCount:SetJustifyH("LEFT")
    frame.locationCount:SetTextColor(unpack(Config.colors.gold))

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function()
        if self.callbacks.onClose then self.callbacks.onClose() end
    end)
    local add = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    add:SetSize(56, 22)
    add:SetPoint("RIGHT", close, "LEFT", -5, 0)
    add:SetText(SMK.L.ADD)
    add:SetScript("OnClick", function() self:OpenEditor("add") end)
    local bulk = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    bulk:SetSize(70, 22)
    bulk:SetPoint("TOP", add, "BOTTOM", 0, -5)
    bulk:SetText(SMK.L.BULK_DELETE)
    bulk:SetScript("OnClick", function() self:OpenBulkDelete() end)
    local shortcut = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    self.shortcutButton = shortcut
    shortcut:SetSize(92, 22)
    shortcut:SetPoint("RIGHT", add, "LEFT", -5, 0)
    shortcut:SetText(SMK.L.SHORTCUT)
    local share = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    share:SetSize(82, 22)
    share:SetPoint("RIGHT", shortcut, "LEFT", -5, 0)
    share:SetText(SMK.L.SHARE)
    share:SetScript("OnClick", function() self:OpenShare() end)
    local scanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scanBtn:SetSize(72, 22)
    scanBtn:SetPoint("RIGHT", share, "LEFT", -5, 0)
    scanBtn:SetText(SMK.L.CHAT_IMPORT)
    local scanStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    scanStatus:SetPoint("TOP", scanBtn, "BOTTOM", 0, -3)
    scanStatus:SetTextColor(unpack(Config.colors.gold))
    scanStatus:SetText("")
    scanBtn:SetScript("OnClick", function()
        local msg = SMK.App:ScanChatForImports()
        scanStatus:SetText(msg)
        C_Timer.After(10, function()
            if scanStatus and scanStatus:GetText() == msg then
                scanStatus:SetText("")
            end
        end)
    end)

    local scaleRow = CreateFrame("Frame", nil, frame)
    scaleRow:SetPoint("TOPLEFT", 14, -43)
    scaleRow:SetPoint("TOPRIGHT", -14, -43)
    scaleRow:SetHeight(24)
    local scaleLabel = scaleRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("LEFT", 4, 0)
    scaleLabel:SetTextColor(unpack(Config.colors.gold))
    scaleLabel:SetText(SMK.L.LOCATION_SCALE)
    frame.locationScaleMinus = CreateFrame("Button", nil, scaleRow, "UIPanelButtonTemplate")
    frame.locationScaleMinus:SetSize(24, 22)
    frame.locationScaleMinus:SetPoint("LEFT", scaleLabel, "RIGHT", 8, 0)
    frame.locationScaleMinus:EnableKeyboard(false)
    frame.locationScaleMinus:SetText("-")
    frame.locationScaleMinus:SetScript("OnClick", function() self:ChangeScale(-Config.location.scaleStep) end)
    self.scaleValue = scaleRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.scaleValue:SetPoint("LEFT", frame.locationScaleMinus, "RIGHT", 4, 0)
    self.scaleValue:SetWidth(44)
    self.scaleValue:SetJustifyH("CENTER")
    frame.locationScalePlus = CreateFrame("Button", nil, scaleRow, "UIPanelButtonTemplate")
    frame.locationScalePlus:SetSize(24, 22)
    frame.locationScalePlus:SetPoint("LEFT", self.scaleValue, "RIGHT", 4, 0)
    frame.locationScalePlus:EnableKeyboard(false)
    frame.locationScalePlus:SetText("+")
    frame.locationScalePlus:SetScript("OnClick", function() self:ChangeScale(Config.location.scaleStep) end)
    self.showPinsCheck = CreateFrame("CheckButton", nil, scaleRow, "UICheckButtonTemplate")
    self.showPinsCheck:SetSize(24, 24)
    self.showPinsCheck:SetPoint("LEFT", frame.locationScalePlus, "RIGHT", 16, 0)
    self.showPinsCheck:SetChecked(SMK.Settings:Get("showMapPins"))
    local pinsLabel = scaleRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinsLabel:SetPoint("LEFT", self.showPinsCheck, "RIGHT", 4, 0)
    pinsLabel:SetText(SMK.L.SHOW_MAP_PINS)
    pinsLabel:SetTextColor(unpack(Config.colors.gold))
    if not SMK.MapPins:IsAvailable() then
        self.showPinsCheck:SetEnabled(false)
        pinsLabel:SetTextColor(unpack(Config.colors.disabled))
    end
    self.showPinsCheck:SetScript("OnClick", function()
        local changed, message = SMK.Settings:Set("showMapPins", self.showPinsCheck:GetChecked())
        if not changed then
            self.showPinsCheck:SetChecked(SMK.Settings:Get("showMapPins"))
            SMK:Print(message)
        end
    end)
    self.showPinNamesCheck = CreateFrame("CheckButton", nil, scaleRow, "UICheckButtonTemplate")
    self.showPinNamesCheck:SetSize(24, 24)
    self.showPinNamesCheck:SetPoint("LEFT", pinsLabel, "RIGHT", 16, 0)
    self.showPinNamesCheck:SetChecked(SMK.Settings:Get("showMapPinNames"))
    local pinNamesLabel = scaleRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinNamesLabel:SetPoint("LEFT", self.showPinNamesCheck, "RIGHT", 4, 0)
    pinNamesLabel:SetText(SMK.L.SHOW_MAP_PIN_NAMES)
    pinNamesLabel:SetTextColor(unpack(Config.colors.gold))
    if not SMK.MapPins:IsAvailable() then
        self.showPinNamesCheck:SetEnabled(false)
        pinNamesLabel:SetTextColor(unpack(Config.colors.disabled))
    end
    self.showPinNamesCheck:SetScript("OnClick", function()
        local changed, message = SMK.Settings:Set("showMapPinNames", self.showPinNamesCheck:GetChecked())
        if not changed then
            self.showPinNamesCheck:SetChecked(SMK.Settings:Get("showMapPinNames"))
            SMK:Print(message)
        end
    end)
    local function SetControlTooltip(control, text)
        control:SetScript("OnEnter", function()
            GameTooltip:SetOwner(control, "ANCHOR_TOP")
            GameTooltip:SetText(text)
            GameTooltip:Show()
        end)
        control:SetScript("OnLeave", GameTooltip_Hide)
    end
    self.pinTextColorButton = CreateFrame("Button", nil, scaleRow, "UIPanelButtonTemplate")
    self.pinTextColorButton:SetSize(28, 22)
    self.pinTextColorButton:SetPoint("LEFT", pinNamesLabel, "RIGHT", 8, 0)
    self.pinTextColorButton.swatch = self.pinTextColorButton:CreateTexture(nil, "ARTWORK")
    self.pinTextColorButton.swatch:SetPoint("TOPLEFT", 5, -5)
    self.pinTextColorButton.swatch:SetPoint("BOTTOMRIGHT", -5, 5)
    self.pinTextColorButton:SetScript("OnClick", function() self:OpenPinTextColorPicker() end)
    SetControlTooltip(self.pinTextColorButton, SMK.L.PIN_TEXT_COLOR)
    self.pinTextScaleMinus = CreateFrame("Button", nil, scaleRow, "UIPanelButtonTemplate")
    self.pinTextScaleMinus:SetSize(24, 22)
    self.pinTextScaleMinus:SetPoint("LEFT", self.pinTextColorButton, "RIGHT", 8, 0)
    self.pinTextScaleMinus:EnableKeyboard(false)
    self.pinTextScaleMinus:SetText("-")
    self.pinTextScaleMinus:SetScript("OnClick", function()
        self:ChangePinTextScale(-Config.mapPins.textScaleStep)
    end)
    SetControlTooltip(self.pinTextScaleMinus, SMK.L.PIN_TEXT_SIZE)
    self.pinTextScaleValue = scaleRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.pinTextScaleValue:SetPoint("LEFT", self.pinTextScaleMinus, "RIGHT", 4, 0)
    self.pinTextScaleValue:SetWidth(44)
    self.pinTextScaleValue:SetJustifyH("CENTER")
    self.pinTextScalePlus = CreateFrame("Button", nil, scaleRow, "UIPanelButtonTemplate")
    self.pinTextScalePlus:SetSize(24, 22)
    self.pinTextScalePlus:SetPoint("LEFT", self.pinTextScaleValue, "RIGHT", 4, 0)
    self.pinTextScalePlus:EnableKeyboard(false)
    self.pinTextScalePlus:SetText("+")
    self.pinTextScalePlus:SetScript("OnClick", function()
        self:ChangePinTextScale(Config.mapPins.textScaleStep)
    end)
    SetControlTooltip(self.pinTextScalePlus, SMK.L.PIN_TEXT_SIZE)
    if not SMK.MapPins:IsAvailable() then
        self.pinTextColorButton:SetEnabled(false)
        self.pinTextScaleMinus:SetEnabled(false)
        self.pinTextScalePlus:SetEnabled(false)
        self.pinTextColorButton.swatch:SetAlpha(0.45)
    end

    self.frequentRow = CreateFrame("Frame", nil, frame)
    self.frequentRow:SetPoint("TOPLEFT", 14, -75)
    self.frequentRow:SetPoint("TOPRIGHT", -14, -75)
    self.frequentRow:SetHeight(Config.location.baseHeight)
    self.frequentRow.title = self.frequentRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frequentRow.title:SetTextColor(unpack(Config.colors.gold))
    self.frequentRow.title:SetText(SMK.L.FREQUENT)
    self.frequentEmpty = self.frequentRow:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.frequentEmpty:SetTextColor(unpack(Config.colors.disabled))
    self.frequentEmpty:SetText(SMK.L.NO_FREQUENT)
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", self.frequentRow, "BOTTOMLEFT", 4, -5)
    divider:SetPoint("TOPRIGHT", self.frequentRow, "BOTTOMRIGHT", -4, -5)
    divider:SetHeight(1)
    divider:SetColorTexture(0.72, 0.52, 0.2, 0.45)
    local scroll = CreateFrame("ScrollFrame", SMK.name .. "ScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", -6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -32, 14)
    self.listContent = CreateFrame("Frame", nil, scroll)
    self.listContent:SetWidth(Config.panel.width - 46)
    self.listContent:SetHeight(100)
    scroll:SetScrollChild(self.listContent)

    SMK.LocationEditor:Create(UIParent, {
        onSave = function(mode, entry, values)
            return self.callbacks.onSaveLocation(mode, entry, values)
        end,
        onDelete = self.callbacks.onDelete,
    })
    SMK.ShareDialog:Create(frame)
    SMK.BulkDeleteDialog:Create(frame)
    SMK.ModalManager:Register(SMK.LocationEditor, { "dropdown" })
    SMK.ModalManager:Register(SMK.ShareDialog)
    SMK.ModalManager:Register(SMK.BulkDeleteDialog, { "dropdown" })
    frame:HookScript("OnHide", function()
        if self.colorPickerOpen and ColorPickerFrame and ColorPickerFrame:IsShown() then
            self.colorPickerCancelled = true
            ColorPickerFrame:Hide()
        end
        frame.isExpanded = false
        self:HideDialogs()
        if self.callbacks.onHidden then self.callbacks.onHidden() end
    end)
    if ColorPickerFrame then
        ColorPickerFrame:HookScript("OnHide", function()
            if not self.colorPickerOpen then return end
            self.colorPickerOpen = false
            if self.colorPickerCancelled then
                self:UpdateScaleControls()
            else
                self:SetPinTextColor(ColorPickerFrame:GetColorRGB())
            end
        end)
    end
    return frame
end

SMK.MainPanel = MainPanel
