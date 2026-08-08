local _, SMK = ...

local Dialog = {}

function Dialog:SetStatus(message, isError)
    self.status:SetText(message or "")
    self.status:SetTextColor(isError and 1 or 0.35,
        isError and 0.3 or 1, isError and 0.3 or 0.45)
end

function Dialog:Import()
    local saved, errorMessage = SMK.App:ImportRouteText(self.textBox:GetText())
    if not saved then return self:SetStatus(errorMessage, true) end
    self:Hide()
    SMK.ModalManager:PrepareToShow(SMK.RouteDialog)
    SMK.RouteDialog:OpenSaved(saved)
end

function Dialog:Create(parent)
    local frame = CreateFrame(
        "Frame", SMK.name .. "RouteImportFrame", parent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(500, 176)
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
    title:SetText(SMK.L.ROUTE_IMPORT_TITLE)
    local close = SMK.Widgets:CreateCloseButton(frame)
    close:SetScript("OnClick", function() self:Hide() end)

    self.textBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.textBox:SetPoint("TOPLEFT", 24, -58)
    self.textBox:SetPoint("TOPRIGHT", -24, -58)
    self.textBox:SetHeight(26)
    self.textBox:SetMaxLetters(100000)
    self.textBox:SetAutoFocus(false)
    self.textBox:SetTextColor(1, 1, 1)
    self.textBox:SetScript("OnEnterPressed", function() self:Import() end)
    self.textBox:SetScript("OnEscapePressed", function() self:Hide() end)

    self.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.status:SetPoint("TOPLEFT", self.textBox, "BOTTOMLEFT", 0, -10)
    self.status:SetPoint("RIGHT", self.textBox, "RIGHT")
    self.status:SetJustifyH("LEFT")

    local import = SMK.Widgets:CreatePanelButton(
        frame, SMK.L.ROUTE_IMPORT_ACTION, { width = 86 })
    import:SetPoint("BOTTOMRIGHT", -116, 22)
    import:SetScript("OnClick", function() self:Import() end)
    local cancel = SMK.Widgets:CreatePanelButton(
        frame, SMK.L.CANCEL, { width = 80 })
    cancel:SetPoint("LEFT", import, "RIGHT", 8, 0)
    cancel:SetScript("OnClick", function() self:Hide() end)
    frame:SetScript("OnHide", function() self.textBox:ClearFocus() end)
    frame:Hide()
end

function Dialog:Open()
    self.textBox:SetText("")
    self:SetStatus(SMK.L.ROUTE_IMPORT_HINT)
    self.frame:Show()
    self.textBox:SetFocus()
end

function Dialog:Hide()
    if self.frame then self.frame:Hide() end
end

function Dialog:IsShown()
    return self.frame and self.frame:IsShown()
end

SMK.RouteImportDialog = Dialog
