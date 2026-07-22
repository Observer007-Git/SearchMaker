local _, SMK = ...

local SearchResults = {}
SearchResults.__index = SearchResults

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
    frame:SetWidth(box:GetWidth())
    frame:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
    frame:SetFrameLevel(parent:GetFrameLevel() + 20)
    frame:SetBackdrop(SMK.Config.resultBackdrop)
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
        onEnter = function(button) view:Select(button) end,
    }
    return view
end

function SearchResults:NotifyVisibilityChanged()
    if self.callbacks.onVisibilityChanged then self.callbacks.onVisibilityChanged() end
end

function SearchResults:IsShown()
    return self.frame:IsShown()
end

function SearchResults:Hide()
    self.selectedIndex, self.visibleCount = 0, 0
    self.frame:Hide()
    self.empty:Hide()
    for _, button in ipairs(self.widgets) do
        button.isSearchSelected = false
        button.highlight:Hide()
        button.label:SetTextColor(unpack(SMK.Config.colors.locationNormal))
        button:Hide()
    end
    self:NotifyVisibilityChanged()
end

function SearchResults:UpdateSelection()
    for index, button in ipairs(self.widgets) do
        button.isSearchSelected = index == self.selectedIndex
            and index <= self.visibleCount and button:IsShown()
        button.highlight:SetShown(button.isSearchSelected)
        button.label:SetTextColor(unpack(button.isSearchSelected
            and SMK.Config.colors.locationHover or SMK.Config.colors.locationNormal))
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

--- 渲染已归一化查询的搜索结果。
function SearchResults:Render(source, query, allMaps)
    local matches = SMK.Search:Find(source, query, allMaps)
    self.matches = matches
    local visible = #matches
    if visible == 0 then
        self.selectedIndex, self.visibleCount = 0, 0
        for _, button in ipairs(self.widgets) do button:Hide() end
        self.empty:Show()
        self.frame:SetWidth(self.box:GetWidth())
        self.frame:SetHeight(SMK.Config.location.baseHeight + 8)
        self.frame:Show()
        self:NotifyVisibilityChanged()
        return
    end

    self.empty:Hide()
    self.visibleCount, self.selectedIndex = visible, 1
    local y = 4
    local width = math.max(1, self.box:GetWidth() - 8)
    for index, match in ipairs(matches) do
        local button = self.widgets[index]
        if not button then
            button = SMK.Widgets:CreateLocationButton(self.frame, self.widgetCallbacks)
            self.widgets[index] = button
        end
        button:ClearAllPoints()
        button.background:Show()
        local display
        if match.isMapPortal then
            display = match.entry.name .. SMK.L.MAP_PORTAL_SUFFIX
        elseif allMaps then
            display = string.format(SMK.L.SEARCH_RESULT_FORMAT, match.mapName, match.entry.name)
        end
        SMK.Widgets:SetLocationEntry(button, match.entry, display)
        SMK.Widgets:StretchSearchResult(button, width)
        button.isSearchResult, button.resultIndex = true, index
        button:SetPoint("TOPLEFT", 4, -y)
        y = y + button:GetHeight() + SMK.Config.location.verticalGap
    end
    for index = visible + 1, #self.widgets do self.widgets[index]:Hide() end
    self.frame:SetWidth(self.box:GetWidth())
    self.frame:SetHeight(y + 2)
    self.frame:Show()
    self:UpdateSelection()
    self:NotifyVisibilityChanged()
end

SMK.SearchResults = SearchResults
