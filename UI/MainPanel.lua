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
    local pool = self.widgetPools[kind]
    local index = (self.widgetUseCounts[kind] or 0) + 1
    self.widgetUseCounts[kind] = index
    local widget = pool[index]
    if widget then
        widget:Show()
        return widget
    end
    if kind == "heading" then
        widget = Widgets:CreateCategoryHeading(self.listContent)
    elseif kind == "message" then
        widget = self.listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    else
        widget = Widgets:CreateLocationButton(self.listContent, self.locationCallbacks)
    end
    widget.kind = kind
    pool[index] = widget
    return widget
end

--- 将所有池化部件恢复为空闲状态（隐藏、清除定位点）。
function MainPanel:ReleaseWidgets()
    for kind, pool in pairs(self.widgetPools) do
        for _, widget in ipairs(pool) do
            if kind == "button" then
                Widgets:ReleaseLocationButton(widget)
            else
                widget:Hide()
                widget:ClearAllPoints()
            end
        end
        self.widgetUseCounts[kind] = 0
    end
end

local function IsVisible(item, top, bottom)
    return item.y + item.height >= top and item.y <= bottom
end

function MainPanel:SetListContentHeight(height)
    self.listContent:SetHeight(height)
    if not self.scrollFrame then return end
    local maximum = math.max(0, height - (self.scrollFrame:GetHeight() or 0))
    self.scrollFrame:SetVerticalScroll(math.min(
        self.scrollFrame:GetVerticalScroll() or 0, maximum))
end

function MainPanel:AddLayoutItem(kind, entry, categoryKey, displayName, x, y, width, height)
    self.listLayoutCount = self.listLayoutCount + 1
    local item = self.listLayout[self.listLayoutCount]
    if not item then
        item = {}
        self.listLayout[self.listLayoutCount] = item
    end
    item.kind = kind
    item.entry = entry
    item.categoryKey = categoryKey
    item.displayName = displayName
    item.x, item.y = x, y
    item.width, item.height = width, height
end

--- 构建当前地图的地点布局，只保存轻量几何数据，不为每个地点创建 Frame。
function MainPanel:BuildListLayout()
    self.buildingListLayout = true
    self.listLayout = self.listLayout or {}
    self.listLayoutCount = 0
    local entries = SMK.MapContext:GetEntries()
    local groups = self.categoryGroups or {}
    self.categoryGroups = groups
    for _, categoryInfo in ipairs(Config.categories) do
        local group = groups[categoryInfo.key]
        if group then
            for index = #group, 1, -1 do group[index] = nil end
        else
            groups[categoryInfo.key] = {}
        end
    end
    if #entries == 0 then
        self:AddLayoutItem("message", nil, nil, nil,
            nil, 28, nil, Config.location.baseHeight)
        for index = self.listLayoutCount + 1, #self.listLayout do
            local item = self.listLayout[index]
            item.entry, item.categoryKey, item.displayName = nil, nil, nil
        end
        self:SetListContentHeight(90)
        self.layoutVersion = (self.layoutVersion or 0) + 1
        self.buildingListLayout = false
        return
    end
    for _, entry in ipairs(entries) do
        local catKey = entry.categoryKey
        local group = groups[catKey]
        group[#group + 1] = entry
    end
    local y = 6
    local headingHeight = CategoryHeadingHeight()
    for _, categoryInfo in ipairs(Config.categories) do
        local categoryEntries = groups[categoryInfo.key]
        if #categoryEntries > 0 then
            table.sort(categoryEntries, function(a, b)
                local keyA = a.normalizedName or SMK.Util.SortKey(a.name)
                local keyB = b.normalizedName or SMK.Util.SortKey(b.name)
                if keyA ~= keyB then return keyA < keyB end
                return a.id < b.id
            end)
            self:AddLayoutItem("heading", nil, categoryInfo.key,
                SMK.L[categoryInfo.nameKey] or categoryInfo.key,
                Config.panel.layout.contentInset, y,
                math.max(1, self.listContent:GetWidth()
                    - Config.panel.layout.contentInset * 2), headingHeight)
            local startX = PanelLayout.sidePadding
            local rowX = startX
            local rowY = y + headingHeight + Config.location.verticalGap
            local rowHeight = 0
            for _, entry in ipairs(categoryEntries) do
                local width, height = Widgets:MeasureLocation(
                    self.measureLabel, entry.name, Config.panel.layout.showLocationIcons)
                if rowX > startX and rowX + width > self.listContent:GetWidth() - startX then
                    rowX = startX
                    rowY = rowY + rowHeight + Config.location.verticalGap
                    rowHeight = 0
                end
                self:AddLayoutItem("button", entry, nil, nil,
                    rowX, rowY, width, height)
                rowX = rowX + width + Config.location.horizontalGap
                rowHeight = math.max(rowHeight, height)
            end
            y = rowY + rowHeight + Config.location.groupGap
        end
    end
    for index = self.listLayoutCount + 1, #self.listLayout do
        local item = self.listLayout[index]
        item.entry, item.categoryKey, item.displayName = nil, nil, nil
    end
    self:SetListContentHeight(math.max(y, 100))
    self.layoutVersion = (self.layoutVersion or 0) + 1
    self.buildingListLayout = false
end

--- 仅实例化滚动区域附近的地点部件。
function MainPanel:RenderVisibleList(force)
    local layout = self.listLayout or {}
    local layoutCount = self.listLayoutCount or 0
    local scrollTop = self.scrollFrame and self.scrollFrame:GetVerticalScroll() or 0
    local viewHeight = self.scrollFrame and self.scrollFrame:GetHeight() or 0
    if viewHeight <= 0 then viewHeight = Config.panel.height end
    local buffer = Config.location.baseHeight * 2
    local visibleTop = math.max(0, scrollTop - buffer)
    local visibleBottom = scrollTop + viewHeight + buffer

    local first, last = 1, layoutCount
    while first <= last do
        local middle = math.floor((first + last) / 2)
        if layout[middle].y + layout[middle].height < visibleTop then
            first = middle + 1
        else
            last = middle - 1
        end
    end
    local visibleLast = first - 1
    for index = first, layoutCount do
        local item = layout[index]
        if item.y > visibleBottom then break end
        if IsVisible(item, visibleTop, visibleBottom) then visibleLast = index end
    end
    if not force and self.renderedLayoutVersion == self.layoutVersion
        and self.renderedFirst == first and self.renderedLast == visibleLast then
        return
    end
    self.renderedLayoutVersion = self.layoutVersion
    self.renderedFirst, self.renderedLast = first, visibleLast
    GameTooltip_Hide()
    self:ReleaseWidgets()
    for index = first, visibleLast do
        local item = layout[index]
        if IsVisible(item, visibleTop, visibleBottom) then
            local widget = self:Acquire(item.kind)
            if item.kind == "heading" then
                widget:SetSize(item.width, item.height)
                Widgets:SetCategory(widget, item.displayName, item.categoryKey)
                widget:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", item.x, -item.y)
            elseif item.kind == "message" then
                widget:SetTextColor(unpack(Config.colors.disabled))
                widget:SetText(SMK.L.NO_LOCATIONS)
                widget:SetPoint("TOP", self.listContent, "TOP", 0, -item.y)
            else
                Widgets:SetLocationEntry(widget, item.entry, nil,
                    Config.panel.layout.showLocationIcons)
                widget:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", item.x, -item.y)
            end
        end
    end
end

--- 渲染当前地图上的所有地点，按类别分组，按名称排序。
function MainPanel:RenderList()
    self:BuildListLayout()
    self:RenderVisibleList(true)
end

--- 收集使用次数不为零的地点，按使用频率排序。
-- @return table { entry, count } 数组。
function MainPanel:GetFrequent()
    local frequent = {}
    local limit = Config.location.maxFrequent
    local function IsBetter(entry, count, candidate)
        if count ~= candidate.count then return count > candidate.count end
        local keyA = entry.normalizedName or SMK.Util.SortKey(entry.name)
        local keyB = candidate.entry.normalizedName
            or SMK.Util.SortKey(candidate.entry.name)
        if keyA ~= keyB then return keyA < keyB end
        return entry.id < candidate.entry.id
    end
    for _, entry in ipairs(SMK.MapContext:GetEntries()) do
        local count = SMK.Store:GetUsage(entry)
        if count > 0 then
            if #frequent < limit then
                frequent[#frequent + 1] = { entry = entry, count = count }
            else
                local worst = 1
                for index = 2, #frequent do
                    if IsBetter(frequent[worst].entry, frequent[worst].count,
                        frequent[index]) then
                        worst = index
                    end
                end
                if IsBetter(entry, count, frequent[worst]) then
                    frequent[worst].entry = entry
                    frequent[worst].count = count
                end
            end
        end
    end
    table.sort(frequent, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        local keyA = a.entry.normalizedName or SMK.Util.SortKey(a.entry.name)
        local keyB = b.entry.normalizedName or SMK.Util.SortKey(b.entry.name)
        if keyA ~= keyB then return keyA < keyB end
        return a.entry.id < b.entry.id
    end)
    return frequent
end

--- 渲染"常用"行，显示最近使用过的地点。
function MainPanel:RenderFrequent()
    local frequent = self:GetFrequent()
    local visible = math.min(#frequent, Config.location.maxFrequent)
    self.frequentEmpty:SetShown(visible == 0)
    local startX = PanelLayout.sidePadding
    local titleHeight = Config.panel.layout.frequentTitleHeight
    local x, y, rowHeight = startX, titleHeight, 0
    local available = self.frequentRow:GetWidth() > 0 and self.frequentRow:GetWidth() or Config.panel.width - 28
    for index = 1, visible do
        local button = self.frequentButtons[index]
        if not button then
            button = Widgets:CreateLocationButton(self.frequentRow, self.locationCallbacks)
            self.frequentButtons[index] = button
        end
        button:ClearAllPoints()
        button:Show()
        Widgets:SetLocationEntry(button, frequent[index].entry, nil,
            Config.panel.layout.showLocationIcons)
        local width, height = button:GetWidth(), button:GetHeight()
        if x > startX and x + width > available - startX then
            x, y, rowHeight = startX, y + rowHeight + Config.location.verticalGap, 0
        end
        button:SetPoint("TOPLEFT", self.frequentRow, "TOPLEFT", x, -y)
        x, rowHeight = x + width + Config.location.horizontalGap, math.max(rowHeight, height)
    end
    self.frequentRow:SetHeight(visible > 0 and y + rowHeight
        or math.max(titleHeight, Config.location.baseHeight))
    self.frequentRow.title:ClearAllPoints()
    self.frequentRow.title:SetPoint("TOPLEFT", 4, 0)
    self.frequentEmpty:ClearAllPoints()
    self.frequentEmpty:SetPoint("LEFT", self.frequentRow.title, "RIGHT", 8, 0)
    for index = visible + 1, #self.frequentButtons do
        Widgets:ReleaseLocationButton(self.frequentButtons[index])
    end
end

function MainPanel:RefreshHeader()
    local mapID = SMK.MapContext:GetMapID()
    self.frame.mapName:SetText(mapID and string.format(SMK.L.MAP_FORMAT, SMK.Map:GetMapName(mapID), mapID)
        or SMK.L.UNKNOWN_MAP)
    self.frame.locationCount:SetText(string.format(SMK.L.LOCATION_COUNT,
        #SMK.MapContext:GetEntries(), SMK.MapContext:GetTotalLocationCount()))
    local scale = SMK.Settings:Get("locationScale")
    self.scaleValue:SetText(string.format("%d%%", math.floor(scale * 100 + 0.5)))
    self.scaleMinus:SetEnabled(scale > Config.location.minScale)
    self.scalePlus:SetEnabled(scale < Config.location.maxScale)
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

function MainPanel:ChangeLocationScale(delta)
    local value = math.max(Config.location.minScale,
        math.min(Config.location.maxScale, SMK.Settings:Get("locationScale") + delta))
    local changed, message = SMK.Settings:Set("locationScale", value)
    if not changed then SMK:Print(message) end
    self:RefreshHeader()
end

function MainPanel:ContainsMouseFocus(foci)
    if not DoesAncestryIncludeAny then return false end
    return self.frame and DoesAncestryIncludeAny(self.frame, foci)
end

function MainPanel:OpenEditor(mode, entry, position)
    SMK.ModalManager:PrepareToShow(SMK.LocationEditor)
    if self.callbacks.onDialogOpened then self.callbacks.onDialogOpened() end
    SMK.LocationEditor:Open(mode, entry, position)
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

function MainPanel:OpenHelp()
    SMK.ModalManager:PrepareToShow(SMK.HelpDialog)
    if self.callbacks.onDialogOpened then self.callbacks.onDialogOpened() end
    SMK.HelpDialog:Open()
end

function MainPanel:OpenRoute()
    SMK.ModalManager:PrepareToShow(SMK.RouteDialog)
    if self.callbacks.onDialogOpened then self.callbacks.onDialogOpened() end
    SMK.RouteDialog:Open()
end

function MainPanel:ToggleSettings()
    if SMK.PanelSettings:IsShown() then
        SMK.PanelSettings:Hide()
    else
        SMK.ModalManager:PrepareToShow(SMK.PanelSettings)
        SMK.PanelSettings:Open()
    end
end

function MainPanel:ToggleSearchSettings()
    if SMK.SearchBarSettings:IsShown() then
        SMK.SearchBarSettings:Hide()
    else
        SMK.ModalManager:PrepareToShow(SMK.SearchBarSettings)
        SMK.SearchBarSettings:Open()
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
    self.widgetPools = { heading = {}, button = {}, message = {} }
    self.widgetUseCounts = { heading = 0, button = 0, message = 0 }
    self.frequentButtons = {}
    self.locationCallbacks = {
        onActivate = self.callbacks.onActivate,
        onContext = self.callbacks.onContext,
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
    frame.mapName:SetPoint("RIGHT", frame, "TOPRIGHT", -190, -17)
    frame.mapName:SetJustifyH("LEFT")
    frame.mapName:SetWordWrap(false)
    frame.mapName:SetTextColor(unpack(Config.colors.gold))
    frame.locationCount = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.locationCount:SetPoint("TOPRIGHT", -44, -17)
    frame.locationCount:SetWidth(140)
    frame.locationCount:SetJustifyH("RIGHT")
    frame.locationCount:SetTextColor(unpack(Config.colors.gold))

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function()
        if self.callbacks.onClose then self.callbacks.onClose() end
    end)

    local buttonGap = Config.panel.controls.buttonGap
    local settings = Widgets:CreatePanelButton(frame, SMK.L.SETTINGS)
    settings:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -39)
    settings:SetScript("OnClick", function() self:ToggleSettings() end)
    local searchSettings = Widgets:CreatePanelButton(frame, SMK.L.SEARCH_BAR_SETTINGS)
    searchSettings:SetPoint("RIGHT", settings, "LEFT", -buttonGap, 0)
    searchSettings:SetScript("OnClick", function() self:ToggleSearchSettings() end)
    local more = Widgets:CreatePanelButton(frame, SMK.L.MORE)
    more:SetPoint("RIGHT", searchSettings, "LEFT", -buttonGap, 0)
    more:SetScript("OnClick", function() self:ToggleMoreMenu() end)
    local share = Widgets:CreatePanelButton(frame, SMK.L.SHARE)
    share:SetPoint("RIGHT", more, "LEFT", -buttonGap, 0)
    share:SetScript("OnClick", function() self:OpenShare() end)
    local add = Widgets:CreatePanelButton(frame, SMK.L.ADD)
    add:SetPoint("RIGHT", share, "LEFT", -buttonGap, 0)
    add:SetScript("OnClick", function() self:OpenEditor("add") end)

    -- 地点缩放控件
    local scaleMinus = Widgets:CreatePanelButton(frame, "-", { width = 24 })
    scaleMinus:SetPoint("RIGHT", add, "LEFT", -buttonGap, 0)
    scaleMinus:SetScript("OnClick", function()
        self:ChangeLocationScale(-Config.location.scaleStep)
    end)
    self.scaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.scaleValue:SetPoint("RIGHT", scaleMinus, "LEFT", -4, 0)
    self.scaleValue:SetWidth(36)
    self.scaleValue:SetJustifyH("CENTER")
    local scalePlus = Widgets:CreatePanelButton(frame, "+", { width = 24 })
    scalePlus:SetPoint("RIGHT", self.scaleValue, "LEFT", -4, 0)
    scalePlus:SetScript("OnClick", function()
        self:ChangeLocationScale(Config.location.scaleStep)
    end)
    local route = Widgets:CreatePanelButton(frame, SMK.L.ROUTE_TITLE)
    route:SetPoint("RIGHT", scalePlus, "LEFT", -buttonGap, 0)
    route:SetScript("OnClick", function() self:OpenRoute() end)
    self.scaleMinus = scaleMinus
    self.scalePlus = scalePlus

    SMK.PanelSettings:Create(settings)
    SMK.SearchBarSettings:Create(searchSettings)
    self.shortcutButton = SMK.SearchBarSettings.shortcutButton
    SMK.ModalManager:Register(SMK.SearchBarSettings)

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
    local bulk = Widgets:CreatePanelButton(moreFrame, SMK.L.BULK_DELETE)
    local help = Widgets:CreatePanelButton(moreFrame, SMK.L.HELP)
    local popupPadding = Config.panel.controls.popupPadding
    local menuWidth = math.max(bulk:GetWidth(), help:GetWidth())
    bulk:SetWidth(menuWidth)
    help:SetWidth(menuWidth)
    bulk:SetPoint("TOPLEFT", popupPadding, -popupPadding)
    help:SetPoint("TOPLEFT", bulk, "BOTTOMLEFT", 0, -buttonGap)
    moreFrame:SetSize(menuWidth + popupPadding * 2,
        Config.panel.controls.buttonHeight * 2 + buttonGap + popupPadding * 2)
    bulk:SetScript("OnClick", function()
        moreMenu:Hide()
        self:OpenBulkDelete()
    end)
    help:SetScript("OnClick", function()
        moreMenu:Hide()
        self:OpenHelp()
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
    self.frequentRow:SetPoint("TOPLEFT", headerDivider, "BOTTOMLEFT",
        PanelLayout.scrollLeftInset - Config.panel.layout.outerInset,
        -Config.panel.layout.contentTopGap)
    self.frequentRow:SetWidth(PanelLayout.contentWidth)
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
    scroll:SetPoint("TOPLEFT", divider, "BOTTOMLEFT",
        -Config.panel.layout.dividerInset, -6)
    scroll:SetPoint("BOTTOMRIGHT",
        -PanelLayout.scrollRightInset + Config.panel.layout.scrollbarOffsetX,
        Config.panel.layout.outerInset)
    self.listContent = CreateFrame("Frame", nil, scroll)
    self.listContent:SetWidth(PanelLayout.contentWidth)
    self.listContent:SetHeight(100)
    scroll:SetScrollChild(self.listContent)
    self.scrollFrame = scroll
    self.measureLabel = self.listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.measureLabel.baseFontPath, self.measureLabel.baseFontSize,
        self.measureLabel.baseFontFlags = self.measureLabel:GetFont()
    scroll:HookScript("OnVerticalScroll", function()
        if self.listLayout and not self.buildingListLayout then
            self:RenderVisibleList()
        end
    end)
    scroll:HookScript("OnSizeChanged", function()
        if self.listLayout and not self.buildingListLayout then
            self:RenderVisibleList()
        end
    end)

    SMK.LocationEditor:Create(UIParent, {
        onSave = function(mode, entry, values)
            return self.callbacks.onSaveLocation(mode, entry, values)
        end,
        onDelete = self.callbacks.onDelete,
    })
    SMK.CopyDialog:Create(UIParent)
    SMK.RouteDialog:Create(UIParent)
    SMK.ImportPreviewDialog:Create(UIParent)
    SMK.ShareDialog:Create(frame)
    SMK.BulkDeleteDialog:Create(frame)
    SMK.HelpDialog:Create(frame)
    SMK.ModalManager:Register(SMK.PanelSettings)
    SMK.ModalManager:Register(self.moreMenu)
    SMK.ModalManager:Register(SMK.LocationEditor)
    SMK.ModalManager:Register(SMK.CopyDialog)
    SMK.ModalManager:Register(SMK.RouteDialog)
    SMK.ModalManager:Register(SMK.ImportPreviewDialog)
    SMK.ModalManager:Register(SMK.ShareDialog)
    SMK.ModalManager:Register(SMK.BulkDeleteDialog)
    SMK.ModalManager:Register(SMK.HelpDialog)
    frame:HookScript("OnHide", function()
        frame.isExpanded = false
        self:HideDialogs()
        self.listLayout = nil
        self.listLayoutCount = 0
        self.categoryGroups = nil
        self.renderedLayoutVersion = nil
        self.renderedFirst, self.renderedLast = nil, nil
        self:ReleaseWidgets()
        for _, button in ipairs(self.frequentButtons) do
            Widgets:ReleaseLocationButton(button)
        end
        if self.callbacks.onHidden then self.callbacks.onHidden() end
    end)
    return frame
end

SMK.MainPanel = MainPanel
