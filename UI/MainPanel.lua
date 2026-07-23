local _, SMK = ...

local MainPanel = {}
local Config = SMK.Config
local Widgets = SMK.Widgets
local PanelLayout = Config.GetPanelLayout()

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
            heading:SetSize(math.max(1,
                self.listContent:GetWidth() - Config.panel.layout.contentInset * 2), headingHeight)
            Widgets:SetCategory(heading, SMK.L[categoryInfo.nameKey] or categoryInfo.key, categoryInfo.key)
            heading:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", Config.panel.layout.contentInset, -y)
            local startX = PanelLayout.sidePadding
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
    local startX = PanelLayout.sidePadding
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
        self.frame.mapName:SetWidth(math.min(Config.panel.layout.headerMapMaxWidth,
            math.ceil(self.frame.mapName:GetUnboundedStringWidth())))
    end
    self.frame.locationCount:SetText(string.format(SMK.L.LOCATION_COUNT,
        #SMK.State.currentEntries, SMK.State.totalLocationCount))
end

--- 全面板刷新：头部、地点列表、常用列表和显示设置。
function MainPanel:Refresh()
    self:RefreshHeader()
    self:RenderList()
    self:RenderFrequent()
    if SMK.PanelSettings:IsShown() then SMK.PanelSettings:Refresh() end
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

function MainPanel:ToggleSettings()
    if SMK.PanelSettings:IsShown() then
        SMK.PanelSettings:Hide()
    else
        SMK.ModalManager:PrepareToShow(SMK.PanelSettings)
        SMK.PanelSettings:Open()
    end
end

function MainPanel:ToggleMoreMenu()
    if self.moreMenu:IsShown() then
        self.moreMenu:Hide()
    else
        SMK.ModalManager:PrepareToShow(self.moreMenu)
        self.moreMenu:Open()
    end
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
    frame.mapName:SetWidth(Config.panel.layout.headerMapMaxWidth)
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

    local buttonGap = Config.panel.controls.buttonGap
    local settings = Widgets:CreatePanelButton(frame, SMK.L.SETTINGS)
    settings:SetPoint("RIGHT", close, "LEFT", -buttonGap, 0)
    settings:SetScript("OnClick", function() self:ToggleSettings() end)
    local more = Widgets:CreatePanelButton(frame, SMK.L.MORE)
    more:SetPoint("RIGHT", settings, "LEFT", -buttonGap, 0)
    more:SetScript("OnClick", function() self:ToggleMoreMenu() end)
    local share = Widgets:CreatePanelButton(frame, SMK.L.SHARE)
    share:SetPoint("RIGHT", more, "LEFT", -buttonGap, 0)
    share:SetScript("OnClick", function() self:OpenShare() end)
    local add = Widgets:CreatePanelButton(frame, SMK.L.ADD)
    add:SetPoint("RIGHT", share, "LEFT", -buttonGap, 0)
    add:SetScript("OnClick", function() self:OpenEditor("add") end)

    SMK.PanelSettings:Create(settings)
    self.shortcutButton = SMK.PanelSettings.shortcutButton

    local moreMenu = {}
    local moreFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    moreMenu.frame = moreFrame
    moreFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    moreFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
    moreFrame:SetClampedToScreen(true)
    moreFrame:EnableMouse(true)
    moreFrame:SetBackdrop(Config.panelBackdrop)
    moreFrame:SetBackdropColor(unpack(Config.colors.dialogBackground))
    moreFrame:SetBackdropBorderColor(unpack(Config.colors.panelBorder))
    moreFrame:SetPoint("TOPRIGHT", more, "BOTTOMRIGHT", 0, -4)
    local scan = Widgets:CreatePanelButton(moreFrame, SMK.L.CHAT_IMPORT)
    local bulk = Widgets:CreatePanelButton(moreFrame, SMK.L.BULK_DELETE)
    local popupPadding = Config.panel.controls.popupPadding
    local menuWidth = math.max(scan:GetWidth(), bulk:GetWidth())
    scan:SetWidth(menuWidth)
    bulk:SetWidth(menuWidth)
    scan:SetPoint("TOPLEFT", popupPadding, -popupPadding)
    bulk:SetPoint("TOPLEFT", scan, "BOTTOMLEFT", 0, -buttonGap)
    moreFrame:SetSize(menuWidth + popupPadding * 2,
        Config.panel.controls.buttonHeight * 2 + buttonGap + popupPadding * 2)
    scan:SetScript("OnClick", function()
        moreMenu:Hide()
        SMK.App:ScanChatForImports()
    end)
    bulk:SetScript("OnClick", function()
        moreMenu:Hide()
        self:OpenBulkDelete()
    end)
    function moreMenu:Open() moreFrame:Show() end
    function moreMenu:Hide() moreFrame:Hide() end
    function moreMenu:IsShown() return moreFrame:IsShown() end
    moreFrame:Hide()
    self.moreMenu = moreMenu

    local headerDivider = frame:CreateTexture(nil, "ARTWORK")
    headerDivider:SetPoint("TOPLEFT", Config.panel.layout.outerInset,
        -Config.panel.layout.headerHeight)
    headerDivider:SetPoint("TOPRIGHT", -Config.panel.layout.outerInset,
        -Config.panel.layout.headerHeight)
    headerDivider:SetHeight(1)
    headerDivider:SetColorTexture(0.72, 0.52, 0.2, 0.45)

    self.frequentRow = CreateFrame("Frame", nil, frame)
    self.frequentRow:SetPoint("TOPLEFT", headerDivider, "BOTTOMLEFT", 0,
        -Config.panel.layout.contentTopGap)
    self.frequentRow:SetPoint("TOPRIGHT", headerDivider, "BOTTOMRIGHT", 0,
        -Config.panel.layout.contentTopGap)
    self.frequentRow:SetHeight(Config.location.baseHeight)
    self.frequentRow.title = self.frequentRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frequentRow.title:SetTextColor(unpack(Config.colors.gold))
    self.frequentRow.title:SetText(SMK.L.FREQUENT)
    self.frequentEmpty = self.frequentRow:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.frequentEmpty:SetTextColor(unpack(Config.colors.disabled))
    self.frequentEmpty:SetText(SMK.L.NO_FREQUENT)
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", self.frequentRow, "BOTTOMLEFT", Config.panel.layout.dividerInset, -5)
    divider:SetPoint("TOPRIGHT", self.frequentRow, "BOTTOMRIGHT", -Config.panel.layout.dividerInset, -5)
    divider:SetHeight(1)
    divider:SetColorTexture(0.72, 0.52, 0.2, 0.45)
    local scroll = CreateFrame("ScrollFrame", SMK.name .. "ScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", -Config.panel.layout.scrollLeftOutset, -6)
    scroll:SetPoint("BOTTOMRIGHT", -Config.panel.layout.scrollbarReserve, Config.panel.layout.outerInset)
    self.listContent = CreateFrame("Frame", nil, scroll)
    self.listContent:SetWidth(PanelLayout.contentWidth)
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
    SMK.ModalManager:Register(SMK.PanelSettings)
    SMK.ModalManager:Register(self.moreMenu)
    SMK.ModalManager:Register(SMK.LocationEditor, { "dropdown" })
    SMK.ModalManager:Register(SMK.ShareDialog)
    SMK.ModalManager:Register(SMK.BulkDeleteDialog, { "dropdown" })
    frame:HookScript("OnHide", function()
        frame.isExpanded = false
        self:HideDialogs()
        if self.callbacks.onHidden then self.callbacks.onHidden() end
    end)
    return frame
end

SMK.MainPanel = MainPanel
