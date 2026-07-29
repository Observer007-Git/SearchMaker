local _, SMK = ...

local Dialog = {}

function Dialog:Create(parent)
    local frame = CreateFrame(
        "Frame", SMK.name .. "ImportPreviewFrame", parent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(540, 390)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(530)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(SMK.Config.panel.backgroundAtlas, false)
    SMK.Widgets:ApplyPanelBorder(frame)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetTextColor(unpack(SMK.Config.colors.gold))
    title:SetText(SMK.L.IMPORT_PREVIEW_TITLE)
    self.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.summary:SetPoint("TOP", title, "BOTTOM", 0, -8)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -1, -1)
    close:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 28, -76)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
        -SMK.Config.panel.layout.scrollFrameRightInset, 62)
    self.content = CreateFrame("Frame", nil, scroll)
    self.content:SetWidth(450)
    scroll:SetScrollChild(self.content)
    self.text = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.text:SetPoint("TOPLEFT")
    self.text:SetWidth(450)
    self.text:SetJustifyH("LEFT")
    self.text:SetJustifyV("TOP")
    self.text:SetWordWrap(false)

    self.confirm = SMK.Widgets:CreatePanelButton(
        frame, SMK.L.IMPORT_CONFIRM, { width = 100 })
    self.confirm:SetPoint("BOTTOMRIGHT", -136, 25)
    self.confirm:SetScript("OnClick", function()
        local callback = self.onConfirm
        frame:Hide()
        if callback then callback() end
    end)
    local cancel = SMK.Widgets:CreatePanelButton(
        frame, SMK.L.CANCEL, { width = 80 })
    cancel:SetPoint("LEFT", self.confirm, "RIGHT", 8, 0)
    cancel:SetScript("OnClick", function() frame:Hide() end)
    frame:SetScript("OnHide", function()
        self.onConfirm = nil
    end)
    frame:Hide()
end

function Dialog:Open(preview, onConfirm)
    self.onConfirm = onConfirm
    self.summary:SetText(string.format(SMK.L.IMPORT_PREVIEW_SUMMARY,
        preview.importable, preview.duplicates, preview.invalid))
    local lines = {}
    local maximum = SMK.Config.importPreview.maxVisibleEntries
    for index, item in ipairs(preview.items) do
        if index > maximum then
            lines[#lines + 1] = string.format(SMK.L.IMPORT_PREVIEW_MORE,
                #preview.items - maximum)
            break
        end
        local entry = item.entry
        lines[#lines + 1] = string.format("%s  %s  %s  %.2f,%.2f",
            item.duplicate and SMK.L.IMPORT_PREVIEW_DUPLICATE
                or SMK.L.IMPORT_PREVIEW_NEW,
            SMK.Map:GetMapName(entry.mapID), entry.name, entry.x, entry.y)
    end
    self.text:SetText(table.concat(lines, "\n"))
    self.content:SetHeight(math.max(1, self.text:GetStringHeight() + 8))
    self.confirm:SetEnabled(preview.importable > 0)
    self.frame:Show()
end

function Dialog:Hide()
    if self.frame then self.frame:Hide() end
end

function Dialog:IsShown()
    return self.frame and self.frame:IsShown()
end

SMK.ImportPreviewDialog = Dialog
