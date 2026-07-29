local _, SMK = ...

local Dialog = {}
local ROW_HEIGHT = 30

local function CreateButton(parent, text, width)
    return SMK.Widgets:CreatePanelButton(parent, text, {
        width = width,
        height = 22,
    })
end

function Dialog:Refresh()
    local items = SMK.Route:GetItems()
    local current = SMK.Route:GetCurrentIndex()
    self.count:SetText(string.format(SMK.L.ROUTE_COUNT, #items, SMK.Config.route.maxEntries))
    self.empty:SetShown(#items == 0)
    for index, row in ipairs(self.rows) do
        local entry = items[index]
        row:SetShown(entry ~= nil)
        if entry then
            row.index = index
            row.name:SetText(entry.name)
            local color = index == current and SMK.Config.colors.routeCurrent
                or SMK.Config.colors.locationNormal
            row.name:SetTextColor(color[1], color[2], color[3])
            row.details:SetText(string.format("%s  %.2f,%.2f",
                SMK.Map:GetMapName(entry.mapID), entry.x, entry.y))
            local hasPersistent = SMK.MapPins:HasPersistentMarker(entry)
            local hasTemporary = not hasPersistent
                and SMK.MapPins:HasTemporaryRoutePin(entry)
            row.mark:SetText(hasPersistent and SMK.L.ROUTE_TEMP_PIN_PERSISTENT_STATE
                or hasTemporary and SMK.L.ROUTE_TEMP_PIN_ACTIVE
                or SMK.L.ROUTE_TEMP_PIN)
            row.mark:SetEnabled(not hasPersistent and not hasTemporary)
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #items)
        end
    end
    self.content:SetHeight(math.max(1, #items * ROW_HEIGHT))
    self.start:SetEnabled(#items > 0)
    self.complete:SetEnabled(current > 0)
    self.clear:SetEnabled(#items > 0)
end

function Dialog:AddTemporaryPin(entry)
    local added, reason = SMK.MapPins:AddTemporaryRoutePin(entry)
    if added then
        if self.frame then self:Refresh() end
        SMK:Print(string.format(SMK.L.ROUTE_TEMP_PIN_ADDED, entry.name))
        return true
    end
    local message = reason == "PERSISTENT_EXISTS" and SMK.L.ROUTE_TEMP_PIN_PERSISTENT
        or reason == "TEMPORARY_EXISTS" and SMK.L.ROUTE_TEMP_PIN_EXISTS
        or reason == "UNAVAILABLE" and SMK.L.ERROR_MAP_PINS_UNAVAILABLE
        or SMK.L.SAVE_FAILED
    SMK:Print(message)
    return false
end

function Dialog:Create(parent)
    local frame = CreateFrame(
        "Frame", SMK.name .. "RouteFrame", parent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(620, 410)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(510)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(SMK.Config.panel.backgroundAtlas, false)
    SMK.Widgets:ApplyPanelBorder(frame)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetTextColor(unpack(SMK.Config.colors.gold))
    title:SetText(SMK.L.ROUTE_TITLE)
    self.count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.count:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -1, -1)
    close:SetFrameLevel(frame:GetFrameLevel() + 20)
    close:RegisterForClicks("LeftButtonUp")
    close:SetScript("OnClick", function() self:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -70)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
        -SMK.Config.panel.layout.scrollFrameRightInset, 58)
    self.content = CreateFrame("Frame", nil, scroll)
    self.content:SetWidth(540)
    scroll:SetScrollChild(self.content)
    self.empty = self.content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.empty:SetPoint("TOP", 0, -20)
    self.empty:SetText(SMK.L.ROUTE_EMPTY)
    self.rows = {}
    for index = 1, SMK.Config.route.maxEntries do
        local row = CreateFrame("Frame", nil, self.content)
        row:SetSize(540, ROW_HEIGHT - 2)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT", 4, 6)
        row.name:SetWidth(280)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.details = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.details:SetPoint("LEFT", 4, -7)
        row.details:SetWidth(285)
        row.details:SetJustifyH("LEFT")
        row.activate = CreateButton(row, SMK.L.ROUTE_LOCATE, 48)
        row.mark = CreateButton(row, SMK.L.ROUTE_TEMP_PIN, 96)
        row.up = CreateButton(row, "↑", 24)
        row.down = CreateButton(row, "↓", 24)
        row.remove = CreateButton(row, "×", 24)
        row.remove:SetPoint("RIGHT", -4, 0)
        row.down:SetPoint("RIGHT", row.remove, "LEFT", -3, 0)
        row.up:SetPoint("RIGHT", row.down, "LEFT", -3, 0)
        row.mark:SetPoint("RIGHT", row.up, "LEFT", -3, 0)
        row.activate:SetPoint("RIGHT", row.mark, "LEFT", -3, 0)
        row.activate:SetScript("OnClick", function() SMK.Route:Activate(row.index) end)
        row.mark:SetScript("OnClick", function()
            self:AddTemporaryPin(SMK.Route:GetItems()[row.index])
        end)
        row.up:SetScript("OnClick", function() SMK.Route:Move(row.index, -1) end)
        row.down:SetScript("OnClick", function() SMK.Route:Move(row.index, 1) end)
        row.remove:SetScript("OnClick", function() SMK.Route:Remove(row.index) end)
        self.rows[index] = row
    end

    self.start = CreateButton(frame, SMK.L.ROUTE_START, 100)
    self.start:SetPoint("BOTTOMLEFT", 28, 24)
    self.start:SetScript("OnClick", function()
        local current = SMK.Route:GetCurrentIndex()
        SMK.Route:Activate(current > 0 and current or 1)
    end)
    self.complete = CreateButton(frame, SMK.L.ROUTE_COMPLETE_NEXT, 120)
    self.complete:SetPoint("LEFT", self.start, "RIGHT", 8, 0)
    self.complete:SetScript("OnClick", function() SMK.Route:CompleteCurrent() end)
    self.clear = CreateButton(frame, SMK.L.ROUTE_CLEAR, 80)
    self.clear:SetPoint("LEFT", self.complete, "RIGHT", 8, 0)
    self.clear:SetScript("OnClick", function() SMK.Route:Clear() end)
    local done = CreateButton(frame, SMK.L.CLOSE, 80)
    done:SetPoint("BOTTOMRIGHT", -28, 24)
    done:SetScript("OnClick", function() frame:Hide() end)
    frame:Hide()
end

function Dialog:Open()
    self:Refresh()
    self.frame:Show()
end

function Dialog:Hide()
    if self.frame then self.frame:Hide() end
end

function Dialog:IsShown()
    return self.frame and self.frame:IsShown()
end

SMK.RouteDialog = Dialog
