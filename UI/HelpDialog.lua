local _, SMK = ...

local HelpDialog = {}
local Config = SMK.Config

function HelpDialog:Create(parent)
    local frame = CreateFrame("Frame", SMK.name .. "HelpFrame", parent)
    self.frame = frame
    frame:SetSize(600, 430)
    frame:SetPoint("CENTER", UIParent, "CENTER")
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
    title:SetPoint("TOP", 0, -20)
    title:SetTextColor(unpack(Config.colors.gold))
    title:SetText(SMK.L.HELP_TITLE)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() self:Hide() end)

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 30, -58)
    body:SetPoint("BOTTOMRIGHT", -30, 28)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetWordWrap(true)
    body:SetSpacing(2)
    body:SetText(SMK.L.HELP_TEXT)

    frame:Hide()
    return frame
end

function HelpDialog:Open()
    self.frame:Show()
end

function HelpDialog:Hide()
    if self.frame then self.frame:Hide() end
end

function HelpDialog:IsShown()
    return self.frame and self.frame:IsShown()
end

SMK.HelpDialog = HelpDialog
