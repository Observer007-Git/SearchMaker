local _, SMK = ...

local HelpDialog = {}
local Config = SMK.Config

function HelpDialog:Create(parent)
    local frame = CreateFrame(
        "Frame", SMK.name .. "HelpFrame", parent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(600, 430)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetFrameLevel(parent:GetFrameLevel() + 40)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(Config.panel.backgroundAtlas, false)
    SMK.Widgets:ApplyPanelBorder(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetTextColor(unpack(Config.colors.gold))
    title:SetText(SMK.L.HELP_TITLE)

    local close = SMK.Widgets:CreateCloseButton(frame)
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() self:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 30, -58)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
        -Config.panel.layout.scrollFrameRightInset, 28)
    self.content = CreateFrame("Frame", nil, scroll)
    self.content:SetWidth(500)
    scroll:SetScrollChild(self.content)

    local body = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.body = body
    body:SetPoint("TOPLEFT")
    body:SetWidth(500)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetWordWrap(true)
    body:SetIndentedWordWrap(true)
    body:SetSpacing(2)
    body:SetText(SMK.L.HELP_TEXT)

    frame:Hide()
    return frame
end

function HelpDialog:Open()
    self.content:SetHeight(math.max(1, self.body:GetStringHeight() + 8))
    self.frame:Show()
end

function HelpDialog:Hide()
    if self.frame then self.frame:Hide() end
end

function HelpDialog:IsShown()
    return self.frame and self.frame:IsShown()
end

SMK.HelpDialog = HelpDialog
