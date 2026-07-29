local _, SMK = ...

local Dialog = {}
local Config = SMK.Config
local Widgets = SMK.Widgets
local MAX_RETAINED_TEXT_LENGTH = 65536

--- 更新对话框底部的状态文字。
-- @param message string|nil
-- @param isError boolean|nil 若为 true，文字显示为红色。
function Dialog:SetStatus(message, isError)
    self.status:SetText(message or "")
    self.status:SetTextColor(isError and 1 or 0.35, isError and 0.3 or 1, isError and 0.3 or 0.45)
end

--- 对要导出的条目排序：按 mapID、类别顺序、名称、坐标。
local function SortEntries(entries)
    table.sort(entries, function(a, b)
        if a.mapID ~= b.mapID then return a.mapID < b.mapID end
        local ac = Config.categoryOrder[a.categoryKey] or #Config.categories
        local bc = Config.categoryOrder[b.categoryKey] or #Config.categories
        if ac ~= bc then return ac < bc end
        local nameA = a.normalizedName or SMK.Util.SortKey(a.name)
        local nameB = b.normalizedName or SMK.Util.SortKey(b.name)
        if nameA ~= nameB then return nameA < nameB end
        if a.x ~= b.x then return a.x < b.x end
        if a.y ~= b.y then return a.y < b.y end
        return (a.id or 0) < (b.id or 0)
    end)
end

function Dialog:GetBatchSize()
    return SMK.Settings:Get("exportBatchSize") or Config.export.defaultBatchSize
end

function Dialog:GetExportRanges(total)
    local batchSize = self:GetBatchSize()
    local ranges = {}
    for first = 1, total, batchSize do
        ranges[#ranges + 1] = {
            first = first,
            last = math.min(total, first + batchSize - 1),
        }
    end
    return ranges
end

function Dialog:UpdateExportRanges(total)
    self.exportRanges = self:GetExportRanges(total)
    local selected
    for _, range in ipairs(self.exportRanges) do
        if range.first == self.currentRangeStart then selected = range; break end
    end
    selected = selected or self.exportRanges[1]
    self.currentRangeStart = selected and selected.first or 1
    self.currentRangeEnd = selected and selected.last or 0
end

function Dialog:RenderExportRange()
    local entries = self.exportEntries or {}
    local sliced = {}
    for index = self.currentRangeStart, self.currentRangeEnd do
        if entries[index] then sliced[#sliced + 1] = entries[index] end
    end
    self.textBox:SetText(SMK.ShareCodec:Encode(sliced))
    self.textBox:SetFocus()
    self.textBox:HighlightText()
    if #entries > self:GetBatchSize() then
        self:SetStatus(string.format(SMK.L.EXPORT_RANGE_SUCCESS,
            #sliced, self.currentRangeStart, self.currentRangeEnd))
    else
        self:SetStatus(string.format(SMK.L.EXPORT_SUCCESS, #sliced))
    end
end

function Dialog:SetBatchSize(batchSize)
    local changed, message = SMK.Settings:Set("exportBatchSize", batchSize)
    if not changed then
        if message then SMK:Print(message) end
        return
    end
    if self.exportEntries then self:Export() end
end

function Dialog:ReleaseExportState()
    self.exportEntries, self.exportRanges = nil, nil
    self.currentRangeStart, self.currentRangeEnd = 1, 0
    if self.rangeLabel then self.rangeLabel:Hide() end
    if self.rangeDropdown then self.rangeDropdown:Hide() end
end

--- 以 SMK| 共享格式导出条目（仅当前地图或全部）。
-- 如果总数超过用户选择的单次导出数量，用户选择范围。
function Dialog:Export()
    local currentOnly = self.currentMapOnly:GetChecked()
    local mapID = currentOnly
        and (SMK.MapContext:GetMapID() or SMK.Map:GetContextMapID()) or nil
    if currentOnly and not mapID then
        return self:SetStatus(SMK.L.ERROR_NO_MAP_ID, true)
    end
    local entries = {}
    for _, entry in ipairs(SMK.Store:GetAll()) do
        if not mapID or entry.mapID == mapID then entries[#entries + 1] = entry end
    end
    SortEntries(entries)
    if #entries == 0 then
        self.exportEntries, self.exportRanges = {}, {}
        self.currentRangeStart, self.currentRangeEnd = 1, 0
        self.rangeLabel:Hide()
        self.rangeDropdown:Hide()
        self.textBox:SetText("")
        return self:SetStatus(mapID and SMK.L.EXPORT_NO_LOCATIONS or SMK.L.EXPORT_NO_LOCATIONS_ALL, true)
    end
    self.exportEntries = entries
    self.currentRangeStart = 1
    self.currentRangeEnd = #entries
    if #entries > self:GetBatchSize() then
        self:UpdateExportRanges(#entries)
        self.rangeLabel:Show()
        self.rangeDropdown:Show()
    else
        self.rangeLabel:Hide()
        self.rangeDropdown:Hide()
    end
    self:RenderExportRange()
end

--- 从文本框中的 SMK| 共享文本导入条目。
-- 跳过已存在的条目（通过 GetDuplicateKey 匹配）。
function Dialog:Import()
    return self:PreviewImport(self.textBox:GetText(), true)
end

function Dialog:PreviewImport(text, clearOnSuccess)
    local preview, errorMessage = SMK.Import:PreviewText(text)
    if not preview then return self:SetStatus(errorMessage, true) end
    SMK.ImportPreviewDialog:Open(preview, function()
        local result, commitError = SMK.Import:CommitPreview(preview)
        if not result then return self:SetStatus(commitError, true) end
        if clearOnSuccess then self.textBox:SetText("") end
        self:ShowImportResult(result)
    end)
    return preview
end

function Dialog:ShowImportResult(result)
    local summary = string.format(SMK.L.IMPORT_RESULT,
        result.imported, result.duplicates, result.invalid)
    self:SetStatus(summary, result.imported == 0 and result.invalid > 0)
    SMK:Print(summary)
    return summary
end

function Dialog:ImportWhispers()
    local text = SMK.WhisperInbox:GetImportText()
    if not text then
        self:SetStatus(SMK.L.CHAT_IMPORT_NONE, true)
        return SMK:Print(SMK.L.CHAT_IMPORT_NONE)
    end
    self.textBox:SetText(text)
    return self:PreviewImport(text, false)
end

function Dialog:Create(parent)
    local frame = CreateFrame("Frame", SMK.name .. "ShareFrame", parent)
    self.frame = frame
    frame:SetSize(600, 350)
    frame:SetPoint("CENTER")
    frame:SetFrameLevel(parent:GetFrameLevel() + 40)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(Config.panel.backgroundAtlas, false)
    frame.borderAtlas = frame:CreateTexture(nil, "BORDER", nil, 7)
    frame.borderAtlas:SetAllPoints(frame)
    frame.borderAtlas:SetAtlas(Config.panel.borderAtlas, false)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetTextColor(unpack(Config.colors.gold))
    title:SetText(SMK.L.SHARE_TITLE)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() frame:Hide() end)

    self.currentMapOnly = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.currentMapOnly:SetSize(24, 24)
    self.currentMapOnly:SetPoint("TOPLEFT", 22, -48)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", self.currentMapOnly, "RIGHT", 4, 0)
    label:SetText(SMK.L.EXPORT_CURRENT_ONLY)
    label:SetTextColor(unpack(Config.colors.gold))
    self.currentMapOnly:SetScript("OnClick", function()
        if self.exportEntries then self:Export() end
    end)

    local batchSizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    batchSizeLabel:SetPoint("LEFT", label, "RIGHT", 24, 0)
    batchSizeLabel:SetText(SMK.L.EXPORT_BATCH_SIZE)
    batchSizeLabel:SetTextColor(unpack(Config.colors.gold))
    self.batchSizeDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    self.batchSizeDropdown:SetSize(72, 24)
    self.batchSizeDropdown:SetPoint("LEFT", batchSizeLabel, "RIGHT", 6, 0)
    self.batchSizeDropdown:SetSelectionText(function()
        return tostring(self:GetBatchSize())
    end)
    self.batchSizeDropdown:SetupMenu(function(_, root)
        for _, batchSize in ipairs(Config.export.batchSizes) do
            root:CreateRadio(tostring(batchSize),
                function(value) return self:GetBatchSize() == value end,
                function(value) self:SetBatchSize(value) end,
                batchSize)
        end
    end)

    self.currentRangeStart = 1
    self.currentRangeEnd = 0
    self.rangeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.rangeLabel:SetPoint("LEFT", self.batchSizeDropdown, "RIGHT", 12, 0)
    self.rangeLabel:SetText(SMK.L.EXPORT_RANGE)
    self.rangeLabel:SetTextColor(unpack(Config.colors.gold))
    self.rangeLabel:Hide()
    self.rangeDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    self.rangeDropdown:SetSize(120, 24)
    self.rangeDropdown:SetPoint("LEFT", self.rangeLabel, "RIGHT", 4, 0)
    self.rangeDropdown:SetSelectionText(function()
        return string.format("%d-%d", self.currentRangeStart, self.currentRangeEnd)
    end)
    self.rangeDropdown:SetupMenu(function(_, root)
        for _, range in ipairs(self.exportRanges or {}) do
            local first, last = range.first, range.last
            root:CreateRadio(string.format("%d-%d", first, last),
                function(value) return self.currentRangeStart == value end,
                function(value)
                    self.currentRangeStart = value
                    self.currentRangeEnd = math.min(#(self.exportEntries or {}),
                        value + self:GetBatchSize() - 1)
                    self:RenderExportRange()
                end,
                first)
        end
    end)
    self.rangeDropdown:Hide()

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", 22, -88)
    border:SetPoint("BOTTOMRIGHT", -22, 64)
    border:SetBackdrop(Config.resultBackdrop)
    border:SetBackdropColor(0.015, 0.015, 0.015, 1)
    border:SetBackdropBorderColor(0.55, 0.42, 0.2, 1)
    local scroll = CreateFrame("ScrollFrame", nil, border, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    self.textBox = CreateFrame("EditBox", nil, scroll)
    self.textBox:SetMultiLine(true)
    self.textBox:SetAutoFocus(false)
    self.textBox:EnableMouse(true)
    self.textBox:SetFontObject(ChatFontNormal)
    self.textBox:SetTextColor(1, 1, 1)
    self.textBox:SetWidth(510)
    self.textBox:SetHeight(190)
    self.textBox:SetMaxLetters(1000000)
    self.textBox:SetTextInsets(4, 4, 4, 4)
    self.textBox:SetScript("OnTextChanged", function(editBox)
        local _, fontHeight = editBox:GetFont()
        local lines = math.max(1, editBox.GetNumLines and editBox:GetNumLines() or 1)
        local spacing = editBox.GetSpacing and editBox:GetSpacing() or 0
        local textHeight = lines * (tonumber(fontHeight) or 14) + math.max(0, lines - 1) * spacing
        editBox:SetHeight(math.max(scroll:GetHeight(), textHeight + 16))
    end)
    scroll:SetScrollChild(self.textBox)

    local export = Widgets:CreatePanelButton(
        frame, SMK.L.EXPORT_BUTTON, { width = 112 })
    export:SetPoint("BOTTOMLEFT", 59, 24)
    export:SetScript("OnClick", function() self:Export() end)
    local import = Widgets:CreatePanelButton(
        frame, SMK.L.IMPORT_BUTTON, { width = 122 })
    import:SetPoint("LEFT", export, "RIGHT", 8, 0)
    import:SetScript("OnClick", function() self:Import() end)
    local whisperImport = Widgets:CreatePanelButton(
        frame, SMK.L.CHAT_IMPORT, { width = 144 })
    whisperImport:SetPoint("LEFT", import, "RIGHT", 8, 0)
    whisperImport:SetScript("OnClick", function() self:ImportWhispers() end)
    local cancel = Widgets:CreatePanelButton(
        frame, SMK.L.CLOSE, { width = 80 })
    cancel:SetPoint("LEFT", whisperImport, "RIGHT", 8, 0)
    cancel:SetScript("OnClick", function() frame:Hide() end)
    self.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.status:SetPoint("BOTTOMLEFT", 24, 8)
    self.status:SetPoint("BOTTOMRIGHT", -24, 8)
    self.status:SetJustifyH("CENTER")
    frame:SetScript("OnHide", function()
        SMK.ImportPreviewDialog:Hide()
        self.textBox:ClearFocus()
        if #(self.textBox:GetText() or "") > MAX_RETAINED_TEXT_LENGTH then
            self.textBox:SetText("")
        end
        self:ReleaseExportState()
    end)
    frame:Hide()
    return frame
end

function Dialog:Open()
    self:SetStatus()
    self.frame:Show()
    self.textBox:SetFocus()
    self.textBox:HighlightText()
end

function Dialog:Hide()
    if self.frame then self.frame:Hide() end
end

function Dialog:IsMenuOpen()
    return self.batchSizeDropdown and self.batchSizeDropdown.IsMenuOpen
        and self.batchSizeDropdown:IsMenuOpen()
        or self.rangeDropdown and self.rangeDropdown.IsMenuOpen
        and self.rangeDropdown:IsMenuOpen()
        or false
end

SMK.ShareDialog = Dialog
