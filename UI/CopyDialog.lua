local _, SMK = ...

local Dialog = {}

function Dialog:Create(parent)
    local frame = CreateFrame(
        "Frame", SMK.name .. "CopyFrame", parent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(440, 142)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(520)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(SMK.Config.panel.backgroundAtlas, false)
    SMK.Widgets:ApplyPanelBorder(frame)
    self.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOP", 0, -18)
    self.title:SetTextColor(unpack(SMK.Config.colors.gold))
    local close = SMK.Widgets:CreateCloseButton(frame)
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() frame:Hide() end)
    self.textBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.textBox:SetPoint("TOPLEFT", 24, -58)
    self.textBox:SetPoint("TOPRIGHT", -24, -58)
    self.textBox:SetHeight(26)
    self.textBox:SetAutoFocus(false)
    self.textBox:SetTextColor(1, 1, 1)
    self.textBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    self.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.hint:SetPoint("TOP", self.textBox, "BOTTOM", 0, -10)
    self.hint:SetText(SMK.L.COPY_HINT)
    frame:SetScript("OnHide", function() self.textBox:ClearFocus() end)
    frame:Hide()
end

function Dialog:Open(title, text)
    self.title:SetText(title)
    self.textBox:SetText(text or "")
    self.frame:Show()
    self.textBox:SetFocus()
    self.textBox:HighlightText()
end

function Dialog:Hide()
    if self.frame then self.frame:Hide() end
end

function Dialog:IsShown()
    return self.frame and self.frame:IsShown()
end

SMK.CopyDialog = Dialog
