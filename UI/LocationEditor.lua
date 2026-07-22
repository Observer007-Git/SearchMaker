local _, SMK = ...

local Editor = {}
local Config = SMK.Config
local Util = SMK.Util

--- 设置 Tab 键将焦点移动到下一个输入框。
-- @param input EditBox 当前字段。
-- @param target EditBox Tab 键时要聚焦的字段。
local function SetTabTarget(input, target)
    input:SetScript("OnTabPressed", function()
        target:SetFocus()
        target:HighlightText()
    end)
end

--- 在输入框下方显示错误消息。
-- @param message string|nil
function Editor:SetError(message)
    self.frame.error:SetText(message or "")
end

--- 刷新下拉框文本和图标以匹配当前类别选择。
function Editor:UpdateCategory()
    local catInfo = Config.categoryByKey[self.categoryKey]
    self.dropdown.Text:SetText(catInfo and (SMK.L[catInfo.nameKey] or catInfo.key) or self.categoryKey)
    self.dropdown.categoryIcon:SetAtlas(catInfo and catInfo.atlas or "Waypoint-MapPin-Minimap-Tracked", false)
end

--- 处理来自下拉框的类别选择。
-- @param category string 所选类别的名称。
function Editor:SelectCategory(categoryKey)
    self.categoryKey = Config.categoryByKey[categoryKey] and categoryKey or Config.defaultCategoryKey
    self:UpdateCategory()
end

--- 验证输入并保存地点。
-- 检查：mapID、坐标（0-100）、名称（非空，≤ maxNameLength）、重复。
-- 调用 onSave 回调，由 App:SaveLocation 处理。
function Editor:Save()
    local frame = self.frame
    local mapID = frame.mode == "edit" and frame.entry and frame.entry.mapID
        or SMK.State.currentMapID or SMK.Map:GetContextMapID()
    local lockedCoordinates = frame.mode == "edit" and frame.entry
    local values = {
        mapID = mapID,
        x = lockedCoordinates and frame.entry.x or tonumber(Util.Trim(self.inputs.x:GetText())),
        y = lockedCoordinates and frame.entry.y or tonumber(Util.Trim(self.inputs.y:GetText())),
        name = Util.Trim(self.inputs.name:GetText()),
        categoryKey = self.categoryKey,
        showPin = self.pinCheck:GetChecked() and 1 or 0,
        pinTextureID = tonumber(self.pinTextureID) or 1,
    }
    if not mapID then
        return self:SetError(SMK.L.ERROR_NO_MAP_ID)
    elseif not values.x or values.x < 0 or values.x > 100
        or not values.y or values.y < 0 or values.y > 100 then
        return self:SetError(SMK.L.ERROR_INVALID_COORDINATES)
    elseif values.name == "" then
        return self:SetError(SMK.L.ERROR_EMPTY_NAME)
    end
    local ok, length = pcall(strlenutf8, values.name)
    if not ok or length > Config.location.maxNameLength then
        return self:SetError(SMK.L.ERROR_NAME_TOO_LONG)
    end
    local dupEntry, dupMessage = SMK.Store:FindDuplicate(values, frame.entry)
    if dupEntry then
        return self:SetError(dupMessage)
    end
    local success, message = self.callbacks.onSave(frame.mode, frame.entry, values)
    if success == false then
        return self:SetError(message or SMK.L.SAVE_FAILED)
    end
    frame:Hide()
end

--- 删除当前正在编辑的地点。
function Editor:Delete()
    local frame = self.frame
    if frame.mode ~= "edit" or not frame.entry or not self.callbacks.onDelete then return end
    if self.callbacks.onDelete(frame.entry) ~= false then frame:Hide() end
end

--- 读取玩家当前位置并填入 X/Y 字段。
function Editor:FillCoordinates()
    local frame = self.frame
    if frame.mode == "edit" then return end
    local mapID = frame.mode == "edit" and frame.entry and frame.entry.mapID
        or SMK.State.currentMapID or SMK.Map:GetContextMapID()
    local x, y = SMK.Map:GetPlayerCoordinates(mapID)
    if not x or not y then
        return self:SetError(SMK.L.ERROR_COORDS_READ_FAILED)
    end
    self.inputs.x:SetText(string.format("%.2f", x))
    self.inputs.y:SetText(string.format("%.2f", y))
    self:SetError()
end

function Editor:Create(parent, callbacks)
    self.callbacks = callbacks or {}
    local frame = CreateFrame("Frame", SMK.name .. "LocationForm", parent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(216, 370)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(500)
    frame:EnableMouse(true)
    frame:SetBackdrop(Config.panelBackdrop)
    frame:SetBackdropColor(0.08, 0.055, 0.025, 0.5)
    frame:SetBackdropBorderColor(unpack(Config.colors.panelBorder))
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -18)
    frame.title:SetTextColor(unpack(Config.colors.gold))
    frame.mapName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.mapName:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)

    -- Category row
    local categoryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, -80)
    categoryLabel:SetTextColor(unpack(Config.colors.gold))
    categoryLabel:SetText(SMK.L.CATEGORY_LABEL)
    self.dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    self.dropdown:SetSize(140, 24)
    self.dropdown:SetPoint("LEFT", categoryLabel, "RIGHT", 8, 0)
    self.dropdown:SetDefaultText(SMK.L.CAT_OTHER or Config.defaultCategoryKey)
    local _, fontSize = self.dropdown.Text:GetFont()
    local iconSize = math.max(10, math.floor((fontSize or 12) + 0.5))
    self.dropdown.categoryIcon = self.dropdown:CreateTexture(nil, "OVERLAY")
    self.dropdown.categoryIcon:SetSize(iconSize, iconSize)
    self.dropdown.categoryIcon:SetPoint("LEFT", self.dropdown, "LEFT", 8, -1)
    self.dropdown.Text:ClearAllPoints()
    self.dropdown.Text:SetPoint("LEFT", self.dropdown.categoryIcon, "RIGHT", 3, 0)
    self.dropdown.Text:SetPoint("RIGHT", self.dropdown.Arrow, "LEFT", -1, 0)
    self.dropdown:SetSelectionText(function()
        local catInfo = Config.categoryByKey[self.categoryKey]
        return catInfo and (SMK.L[catInfo.nameKey] or catInfo.key) or self.categoryKey
    end)
    self.dropdown:SetupMenu(function(_, root)
        for _, category in ipairs(Config.categories) do
            local catDisplay = SMK.L[category.nameKey] or category.key
            local radio = root:CreateRadio(catDisplay,
                function(value) return self.categoryKey == value end,
                function(value) self:SelectCategory(value) end,
                category.key)
            radio:AddInitializer(function(button)
                local _, menuFontSize = button.fontString:GetFont()
                local menuIconSize = math.max(10, math.floor((menuFontSize or 12) + 0.5))
                local icon = button:AttachTexture()
                icon:SetSize(menuIconSize, menuIconSize)
                icon:SetAtlas(category.atlas, false)
                icon:SetPoint("LEFT", button.leftTexture1, "RIGHT", 1, 0)
                button.fontString:ClearAllPoints()
                button.fontString:SetPoint("LEFT", icon, "RIGHT", 3, 0)
            end)
        end
    end)

    -- Input fields: X and Y on the same row
    local xInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    xInput:SetSize(60, 24)
    xInput:SetAutoFocus(false)
    xInput:SetMaxLetters(Config.location.maxCoordinateLength)
    xInput:SetTextColor(1, 1, 1)
    local yInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    yInput:SetSize(60, 24)
    yInput:SetAutoFocus(false)
    yInput:SetMaxLetters(Config.location.maxCoordinateLength)
    yInput:SetTextColor(1, 1, 1)
    -- Name: label left of input
    local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, -105)
    nameLabel:SetTextColor(unpack(Config.colors.gold))
    nameLabel:SetText(SMK.L.NAME_LABEL)
    local nameInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameInput:SetSize(140, 24)
    nameInput:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(Config.location.maxNameLength)
    nameInput:SetTextColor(1, 1, 1)
    -- X/Y on the same row, labels above inputs
    local xLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xLabel:SetPoint("LEFT", frame, "TOPLEFT", 56, -130)
    xLabel:SetTextColor(unpack(Config.colors.gold))
    xLabel:SetText(SMK.L.X_LABEL)
    local yLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yLabel:SetPoint("LEFT", frame, "TOPLEFT", 126, -130)
    yLabel:SetTextColor(unpack(Config.colors.gold))
    yLabel:SetText(SMK.L.Y_LABEL)
    xInput:SetPoint("TOPLEFT", frame, "TOPLEFT", 56, -148)
    yInput:SetPoint("TOPLEFT", frame, "TOPLEFT", 126, -148)
    self.inputs = { name = nameInput, x = xInput, y = yInput }
    for _, input in pairs(self.inputs) do
        input:SetScript("OnEnterPressed", function() self:Save() end)
    end
    SetTabTarget(self.inputs.name, self.inputs.x)
    SetTabTarget(self.inputs.x, self.inputs.y)
    SetTabTarget(self.inputs.y, self.inputs.name)

    local coordinateButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    self.coordinateButton = coordinateButton
    coordinateButton:SetSize(120, 24)
    coordinateButton:SetPoint("TOP", frame, "TOP", 0, -188)
    coordinateButton:SetText(SMK.L.READ_COORDINATES)
    coordinateButton:SetScript("OnClick", function() self:FillCoordinates() end)
    frame.error = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    frame.error:SetPoint("TOP", frame, "TOP", 0, -215)
    -- 地图标记复选框
    self.pinCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.pinCheck:SetSize(24, 24)
    self.pinCheck:SetPoint("LEFT", frame, "TOPLEFT", 18, -238)
    self.pinCheck:SetChecked(false)
    local pinCheckLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinCheckLabel:SetPoint("LEFT", self.pinCheck, "RIGHT", 4, 0)
    pinCheckLabel:SetText(SMK.L.SHOW_MAP_PINS)
    pinCheckLabel:SetTextColor(unpack(Config.colors.gold))
    -- 标记材质下拉框
    local pinTexLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinTexLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, -265)
    pinTexLabel:SetTextColor(unpack(Config.colors.gold))
    pinTexLabel:SetText(SMK.L.PIN_TEXTURE_LABEL)
    self.pinDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    self.pinDropdown:SetSize(120, 24)
    self.pinDropdown:SetPoint("LEFT", pinTexLabel, "RIGHT", 8, 0)
    self.pinDropdown:SetDefaultText("")
    self.pinDropdown.Text:SetText("")
    local pinTexIcon = self.pinDropdown:CreateTexture(nil, "OVERLAY")
    pinTexIcon:SetSize(20, 20)
    pinTexIcon:SetPoint("LEFT", self.pinDropdown, "LEFT", 4, 0)
    self.pinDropdown.pinTexIcon = pinTexIcon
    local function UpdatePinDropdown()
        local checked = self.pinCheck:GetChecked()
        local tex = checked and SMK.PinTextureByID[self.pinTextureID or 1]
        pinTexLabel:SetTextColor(unpack(checked and Config.colors.gold or Config.colors.disabled))
        self.pinDropdown:SetEnabled(checked)
        if tex then
            pinTexIcon:SetAtlas(tex.atlas, true)
        else
            pinTexIcon:SetTexture()
        end
    end
    self.UpdatePinDropdown = UpdatePinDropdown
    self.pinCheck:SetScript("OnClick", function()
        self:UpdatePinDropdown()
    end)
    self.pinDropdown:SetupMenu(function(_, root)
        local checked = self.pinCheck:GetChecked()
        if not checked then return end
        for _, tex in ipairs(SMK.PinTextures) do
            local radio = root:CreateRadio(tostring(tex.id),
                function(value) return value == tonumber(self.pinTextureID or 1) end,
                function(value)
                    self.pinTextureID = value
                    local newTex = SMK.PinTextureByID[value]
                    if newTex then pinTexIcon:SetAtlas(newTex.atlas, true) end
                end,
                tex.id)
            radio:AddInitializer(function(button)
                button.fontString:SetText("")
                local icon = button:AttachTexture()
                icon:SetSize(20, 20)
                icon:SetAtlas(tex.atlas, true)
                icon:SetPoint("LEFT", button.leftTexture1, "RIGHT", 2, 0)
            end)
        end
    end)
    
    local save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    save:SetSize(60, 24)
    save:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 15)
    save:SetText(SMK.L.SAVE)
    save:SetScript("OnClick", function() self:Save() end)
    self.deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    self.deleteButton:SetSize(60, 24)
    self.deleteButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
    self.deleteButton:SetText(SMK.L.DELETE)
    self.deleteButton:SetScript("OnClick", function() self:Delete() end)
    local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancel:SetSize(60, 24)
    cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 15)
    cancel:SetText(SMK.L.CANCEL)
    cancel:SetScript("OnClick", function() frame:Hide() end)
    frame:SetScript("OnHide", function()
        SMK.Map:ClearTemporaryWaypoint()
        for _, input in pairs(self.inputs) do input:ClearFocus() end
    end)
    frame:Hide()
    return frame
end

--- 打开编辑器对话框，编辑现有条目时预填字段。
-- @param mode string "add" 或 "edit"。
-- @param entry table|nil 现有条目（编辑模式）。
function Editor:Open(mode, entry)
    local frame = self.frame
    frame.mode, frame.entry = mode, entry
    frame.title:SetText(mode == "edit" and SMK.L.EDIT_TITLE or SMK.L.ADD_TITLE)
    local mapID = mode == "edit" and entry.mapID or SMK.State.currentMapID or SMK.Map:GetContextMapID()
    frame.mapName:SetText(mapID and string.format(SMK.L.MAP_FORMAT, SMK.Map:GetMapName(mapID), mapID) or SMK.L.UNKNOWN_MAP)
    self.inputs.name:SetText(entry and entry.name or "")
    self.inputs.x:SetText(entry and tostring(entry.x) or "")
    self.inputs.y:SetText(entry and tostring(entry.y) or "")
    local coordinatesEditable = mode ~= "edit"
    self.inputs.x:SetEnabled(coordinatesEditable)
    self.inputs.y:SetEnabled(coordinatesEditable)
    self.coordinateButton:SetEnabled(coordinatesEditable)
    local coordinateColor = coordinatesEditable and { 1, 1, 1 } or Config.colors.disabled
    self.inputs.x:SetTextColor(unpack(coordinateColor))
    self.inputs.y:SetTextColor(unpack(coordinateColor))
    SetTabTarget(self.inputs.name, coordinatesEditable and self.inputs.x or self.inputs.name)
    self.deleteButton:SetShown(mode == "edit")
    self.categoryKey = entry and Config.GetCategoryKey(entry.categoryKey)
        or Config.defaultCategoryKey
    self:UpdateCategory()
    self.pinCheck:SetChecked(entry and entry.showPin == 1 or false)
    self.pinTextureID = entry and tonumber(entry.pinTextureID) or 1
    if not SMK.PinTextureByID[self.pinTextureID] then self.pinTextureID = 1 end
    self:UpdatePinDropdown()
    self:SetError()
    frame:Show()
    self.inputs.name:SetFocus()
end

function Editor:Hide()
    if self.frame then self.frame:Hide() end
end

SMK.LocationEditor = Editor
