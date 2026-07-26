local _, SMK = ...

local Dialog = {}
local Config = SMK.Config
local Util = SMK.Util
local POPUP_ID = "SEARCHMAKER_BULK_DELETE"

function Dialog:HideConfirmation()
    if self.popup and self.popup:IsShown() then StaticPopup_Hide(POPUP_ID) end
    self.popup = nil
end

function Dialog:ContainsMouseFocus(foci)
    return self.popup and self.popup:IsShown()
        and DoesAncestryIncludeAny(self.popup, foci) or false
end

--- 更新状态消息。
-- @param message string|nil
-- @param isError boolean|nil
function Dialog:SetStatus(message, isError)
    self.status:SetText(message or "")
    self.status:SetTextColor(isError and 1 or 0.35, isError and 0.3 or 1, isError and 0.3 or 0.45)
end

function Dialog:UpdateCategory()
    local category = Config.categoryByKey[self.categoryKey]
    self.dropdown.Text:SetText(category and (SMK.L[category.nameKey] or category.key)
        or self.categoryKey)
end

--- 构建要删除的条目列表并显示确认弹窗。
-- @param mode string "category" 或 "map"。
function Dialog:RequestDelete(mode)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage then return self:SetStatus(readOnlyMessage, true) end
    local matches, description
    if mode == "category" then
        matches = SMK.Store:FindByCategory(self.categoryKey)
        local category = Config.categoryByKey[self.categoryKey]
        local label = category and (SMK.L[category.nameKey] or category.key) or self.categoryKey
        description = string.format(SMK.L.DELETE_CATEGORY_DESC, label)
    else
        local mapID = tonumber(Util.Trim(self.mapInput:GetText()))
        if not mapID or mapID <= 0 or mapID % 1 ~= 0 then
            return self:SetStatus(SMK.L.ENTER_VALID_MAP_ID, true)
        end
        matches = SMK.Store:GetByMap(mapID)
        description = string.format(SMK.L.DELETE_MAP_DESC, mapID)
    end
    if #matches == 0 then
        return self:SetStatus(SMK.L.NO_LOCATIONS_TO_DELETE, true)
    end
    local popup = StaticPopup_Show(POPUP_ID, description, #matches)
    if popup then
        self.popup = popup
        popup.data = { entries = matches, description = description, owner = self }
        popup:SetFrameStrata(self.frame:GetFrameStrata())
        popup:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    end
end

--- 创建批量删除对话框窗口。
-- @param parent Frame 父框架。
-- @return Frame
function Dialog:Create(parent)
    local frame = CreateFrame("Frame", SMK.name .. "BulkDeleteFrame", parent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(430, 205)
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
    title:SetText(SMK.L.BULK_DELETE_TITLE)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() frame:Hide() end)

    local categoryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryLabel:SetPoint("TOPLEFT", 28, -65)
    categoryLabel:SetText(SMK.L.DELETE_BY_CATEGORY)
    self.dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    self.dropdown:SetSize(120, 24)
    self.dropdown:SetPoint("LEFT", categoryLabel, "RIGHT", 12, 0)
    self.dropdown:SetSelectionText(function()
        local category = Config.categoryByKey[self.categoryKey]
        return category and (SMK.L[category.nameKey] or category.key) or self.categoryKey
    end)
    self.dropdown:SetupMenu(function(_, root)
        for _, category in ipairs(Config.categories) do
            local name = SMK.L[category.nameKey] or category.key
            root:CreateRadio(name,
                function(value) return self.categoryKey == value end,
                function(value) self.categoryKey = value self:UpdateCategory() end,
                category.key)
        end
    end)
    local deleteCategory = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    deleteCategory:SetSize(110, 24)
    deleteCategory:SetPoint("LEFT", self.dropdown, "RIGHT", 12, 0)
    deleteCategory:SetText(SMK.L.DELETE_CATEGORY_ACTION)
    deleteCategory:SetScript("OnClick", function() self:RequestDelete("category") end)

    local mapLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mapLabel:SetPoint("TOPLEFT", 28, -108)
    mapLabel:SetText(SMK.L.DELETE_BY_MAP_ID)
    self.mapInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.mapInput:SetSize(120, 24)
    self.mapInput:SetPoint("LEFT", mapLabel, "RIGHT", 12, 0)
    self.mapInput:SetAutoFocus(false)
    self.mapInput:SetNumeric(true)
    self.mapInput:SetMaxLetters(8)
    local deleteMap = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    deleteMap:SetSize(110, 24)
    deleteMap:SetPoint("LEFT", self.mapInput, "RIGHT", 12, 0)
    deleteMap:SetText(SMK.L.DELETE_MAP_ACTION)
    deleteMap:SetScript("OnClick", function() self:RequestDelete("map") end)
    self.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.status:SetPoint("BOTTOMLEFT", 24, 18)
    self.status:SetPoint("BOTTOMRIGHT", -24, 18)
    self.status:SetJustifyH("CENTER")
    frame:SetScript("OnHide", function()
        self:HideConfirmation()
        self.mapInput:ClearFocus()
        self:SetStatus()
    end)
    frame:Hide()

    StaticPopupDialogs[POPUP_ID] = {
        text = SMK.L.CONFIRM_DELETE_FORMAT,
        button1 = SMK.L.CONFIRM_DELETE_ACTION,
        button2 = CANCEL,
        OnAccept = function(_, data)
            local deleted = SMK.Store:DeleteMany(data and data.entries or {})
            if deleted > 0 then
                SMK:Print(string.format(SMK.L.BULK_DELETE_SUCCESS, data.description, deleted))
                data.owner.popup = nil
                data.owner.frame:Hide()
            end
        end,
        timeout = 0,
        whileDead = true,
        preferredIndex = 3,
    }
    return frame
end

function Dialog:Open()
    self.categoryKey = Config.defaultCategoryKey
    self:UpdateCategory()
    self.mapInput:SetText(tostring(SMK.MapContext:GetMapID()
        or SMK.Map:GetContextMapID() or ""))
    self:SetStatus()
    self.frame:Show()
end

function Dialog:Hide()
    self:HideConfirmation()
    if self.frame then self.frame:Hide() end
end

function Dialog:IsMenuOpen()
    return self.dropdown and self.dropdown.IsMenuOpen and self.dropdown:IsMenuOpen() or false
end

SMK.BulkDeleteDialog = Dialog
