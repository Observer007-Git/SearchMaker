local _, SMK = ...

local SearchResults = {}
SearchResults.__index = SearchResults

local function ColorText(text, color)
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5),
        math.floor(color[3] * 255 + 0.5), text)
end

local function GetMaximumContentWidth(frame, minimumWidth)
    local search = SMK.Config.search
    local maximumWidth = math.max(minimumWidth, search.resultMaxContentWidth)
    local frameLeft = frame:GetLeft()
    local frameScale = frame:GetEffectiveScale()
    local uiRight = UIParent:GetRight()
    local uiScale = UIParent:GetEffectiveScale()
    if frameLeft and frameScale and frameScale > 0 and uiRight and uiScale then
        local screenWidth = (uiRight * uiScale - frameLeft * frameScale) / frameScale
            - search.resultScreenMargin - 8
        maximumWidth = math.min(maximumWidth, math.floor(screenWidth))
    end
    return math.max(minimumWidth, maximumWidth)
end

function SearchResults:New(parent, box, callbacks)
    local view = setmetatable({
        box = box,
        callbacks = callbacks or {},
        widgets = {},
        matches = {},
        selectedIndex = 0,
        visibleCount = 0,
    }, self)

    local frame = CreateFrame("Frame", SMK.name .. "SearchResults", parent, "BackdropTemplate")
    view.frame = frame
    local frameInset = SMK.Config.search.resultFrameInset
    frame:SetWidth(math.max(1, box:GetWidth() - frameInset * 2))
    frame:SetPoint("TOPLEFT", box, "BOTTOMLEFT", frameInset, -SMK.Config.search.resultGap)
    frame:SetFrameLevel(parent:GetFrameLevel() + 20)
    frame:SetBackdrop(SMK.Config.searchResultBackdrop)
    frame:SetBackdropColor(0.02, 0.02, 0.02, 1)
    frame:Hide()

    view.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.empty:SetPoint("LEFT", 8, 0)
    view.empty:SetTextColor(0.65, 0.65, 0.65)
    view.empty:SetText(SMK.L.NO_MATCH)
    view.empty:Hide()
    view.widgetCallbacks = {
        onActivate = view.callbacks.onActivate,
        onEdit = view.callbacks.onEdit,
        onDelete = view.callbacks.onDelete,
        onExternalMenu = function(entry, owner) view:OpenExternalMenu(entry, owner) end,
        onEnter = function(button)
            view:Select(button)
            view:ScheduleHoverHighlight(button)
        end,
        onLeave = function(button) view:CancelHoverHighlight(button) end,
    }
    return view
end

function SearchResults:CancelHoverHighlight(button)
    if button and self.hoverButton ~= button then return end
    self.hoverButton = nil
    self.hoverToken = (self.hoverToken or 0) + 1
    SMK.MapPins:ClearHoverHighlight()
end

function SearchResults:ScheduleHoverHighlight(button)
    self:CancelHoverHighlight()
    local entry = button and button.entry
    if self.allMaps or not entry or not tonumber(entry.x) or not tonumber(entry.y)
        or not WorldMapFrame or not WorldMapFrame:IsShown()
        or WorldMapFrame:GetMapID() ~= entry.mapID then
        return
    end
    self.hoverButton = button
    local token = self.hoverToken
    C_Timer.After(SMK.Config.search.hoverHighlightDelay, function()
        if self.hoverToken ~= token or self.hoverButton ~= button or self.allMaps
            or not WorldMapFrame:IsShown() or WorldMapFrame:GetMapID() ~= entry.mapID then
            return
        end
        SMK.MapPins:ShowHoverHighlight(entry)
    end)
end

function SearchResults:IsContextMenuOpen()
    return self.contextMenu and self.contextMenu:IsShown()
end

function SearchResults:GetFavoriteOptions()
    local options = {}
    for _, category in ipairs(SMK.Config.categories) do
        options[#options + 1] = {
            key = category.key,
            label = SMK.L[category.nameKey] or category.key,
            atlas = category.atlas,
        }
    end
    return options
end

function SearchResults:OpenExternalMenu(entry, owner)
    if entry.externalSource ~= "HandyNotes_MapNotes" or not self.callbacks.onFavorite then return end
    GameTooltip_Hide()
    self.contextMenu = MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        for _, option in ipairs(self:GetFavoriteOptions()) do
            local categoryKey = option.key
            local categoryIcon = option.atlas
                and CreateAtlasMarkup(option.atlas, 16, 16) or ""
            local menuText = string.format(SMK.L.FAVORITE_TO_FORMAT,
                categoryIcon ~= "" and (categoryIcon .. " " .. option.label) or option.label)
            rootDescription:CreateButton(menuText, function()
                self.callbacks.onFavorite(entry, categoryKey)
            end)
        end
    end)
end

function SearchResults:NotifyVisibilityChanged()
    if self.callbacks.onVisibilityChanged then self.callbacks.onVisibilityChanged() end
end

function SearchResults:IsShown()
    return self.frame:IsShown()
end

function SearchResults:Hide()
    self:CancelHoverHighlight()
    self.selectedIndex, self.visibleCount = 0, 0
    self.matches = {}
    self.frame:Hide()
    self.empty:Hide()
    for _, button in ipairs(self.widgets) do
        SMK.Widgets:ReleaseLocationButton(button)
    end
    self:NotifyVisibilityChanged()
end

function SearchResults:UpdateSelection()
    for index, button in ipairs(self.widgets) do
        button.isSearchSelected = index == self.selectedIndex
            and index <= self.visibleCount and button:IsShown()
        button.highlight:SetShown(button.isSearchSelected)
        local color = button.isSearchSelected and SMK.Config.colors.locationHover
            or (button.isPinned and SMK.Config.colors.locationPinned
                or SMK.Config.colors.locationNormal)
        button.label:SetTextColor(unpack(color))
    end
end

function SearchResults:Select(button)
    if button.resultIndex then
        self.selectedIndex = button.resultIndex
        self:UpdateSelection()
    end
end

function SearchResults:MoveSelection(key)
    if self.visibleCount == 0 or not self.frame:IsShown() then return end
    if key == "UP" then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then self.selectedIndex = self.visibleCount end
    elseif key == "DOWN" then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > self.visibleCount then self.selectedIndex = 1 end
    else
        return
    end
    self:UpdateSelection()
end

function SearchResults:GetSelected()
    local index = self.selectedIndex > 0 and self.selectedIndex or 1
    return self.matches[index]
end

--- 渲染搜索结果；SearchService 负责文本归一化和坐标识别。
function SearchResults:Render(source, query, allMaps)
    self:CancelHoverHighlight()
    self.allMaps = allMaps == true
    local matches = SMK.Search:Find(source, query, allMaps,
        SMK.MapContext:GetMapID(), SMK.MapContext:GetExternalEntries())
    self.matches = matches
    local visible = #matches
    if visible == 0 then
        self.selectedIndex, self.visibleCount = 0, 0
        for _, button in ipairs(self.widgets) do
            SMK.Widgets:ReleaseLocationButton(button)
        end
        self.empty:Show()
        local frameInset = SMK.Config.search.resultFrameInset
        self.frame:SetWidth(math.max(1, self.box:GetWidth() - frameInset * 2))
        self.frame:SetHeight(SMK.Config.location.baseHeight + 8)
        self.frame:Show()
        self:NotifyVisibilityChanged()
        return
    end

    self.empty:Hide()
    self.visibleCount, self.selectedIndex = visible, 1
    local frameInset = SMK.Config.search.resultFrameInset
    local frameWidth = math.max(1, self.box:GetWidth() - frameInset * 2)
    for index, match in ipairs(matches) do
        local button = self.widgets[index]
        if not button then
            button = SMK.Widgets:CreateLocationButton(self.frame, self.widgetCallbacks)
            self.widgets[index] = button
        end
        button:ClearAllPoints()
        local display
        if match.isCoordinateResult then
            display = match.entry.name
        elseif match.isMapPortal then
            display = match.entry.name .. SMK.L.MAP_PORTAL_SUFFIX
        elseif allMaps then
            display = string.format(SMK.L.SEARCH_RESULT_FORMAT, match.mapName, match.entry.name)
        end
        if match.entry.isExternal then
            display = (display or match.entry.name) .. " "
                .. ColorText(SMK.L.HANDYNOTES_SOURCE_SUFFIX, SMK.Config.colors.externalSource)
        end
        button:Show()
        SMK.Widgets:SetLocationEntry(button, match.entry, display, true)
        button.resultIndex = index
    end
    local y = 4
    local maxWidth = math.max(1, frameWidth - 8)
    for index = 1, visible do
        maxWidth = math.max(maxWidth, self.widgets[index]:GetWidth())
    end
    maxWidth = math.min(maxWidth, GetMaximumContentWidth(self.frame, frameWidth - 8))
    for index, match in ipairs(matches) do
        local button = self.widgets[index]
        button.isSearchResult = true
        SMK.Widgets:StretchSearchResult(button, maxWidth)
        button:SetPoint("TOPLEFT", 4, -y)
        y = y + button:GetHeight() + SMK.Config.location.verticalGap
    end
    for index = visible + 1, #self.widgets do
        SMK.Widgets:ReleaseLocationButton(self.widgets[index])
    end
    self.frame:SetWidth(maxWidth + 8)
    self.frame:SetHeight(math.max(1, y) + 2)
    self.frame:Show()
    self:UpdateSelection()
    self:NotifyVisibilityChanged()
end

SMK.SearchResults = SearchResults
