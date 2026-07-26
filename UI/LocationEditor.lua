local _, SMK = ...

local Editor = {}
local Config = SMK.Config
local Util = SMK.Util
local Widgets = SMK.Widgets
local EditorConfig = Config.locationEditor

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
    self.dropdown.categoryIcon:SetAtlas(catInfo and catInfo.atlas or "Waypoint-MapPin-Tracked", false)
end

--- 处理来自下拉框的类别选择。
-- @param category string 所选类别的名称。
function Editor:SelectCategory(categoryKey)
    self.categoryKey = Config.categoryByKey[categoryKey] and categoryKey or Config.defaultCategoryKey
    self:UpdateCategory()
end

function Editor:SelectPinTexture(textureID)
    if not SMK.PinTextureByID[textureID] then return end
    self.pinTextureID = textureID
    self:UpdatePinTexturePanel()
end

--- 验证输入并保存地点。
-- 检查：mapID、坐标（0-100）、名称（非空且不超过显示宽度限制）、重复。
-- 调用 onSave 回调，由 App:SaveLocation 处理。
function Editor:Save()
    local frame = self.frame
    local mapID = frame.mapID
    local values = {
        mapID = mapID,
        x = tonumber(Util.Trim(self.inputs.x:GetText())),
        y = tonumber(Util.Trim(self.inputs.y:GetText())),
        name = Util.Trim(self.inputs.name:GetText()),
        categoryKey = self.categoryKey,
        showPin = (self.pinColorCheck:GetChecked() or self.pinCheck:GetChecked()) and 1 or 0,
        showPinName = self.pinColorCheck:GetChecked() and 1 or 0,
        showPinTexture = self.pinCheck:GetChecked() and 1 or 0,
        pinTextureID = tonumber(self.pinTextureID) or SMK.DefaultPinTextureID,
        pinColor = self.pinColor,
    }
    if not mapID then
        return self:SetError(SMK.L.ERROR_NO_MAP_ID)
    elseif not values.x or values.x < 0 or values.x > 100
        or not values.y or values.y < 0 or values.y > 100 then
        return self:SetError(SMK.L.ERROR_INVALID_COORDINATES)
    elseif values.name == "" then
        return self:SetError(SMK.L.ERROR_EMPTY_NAME)
    end
    local nameWidth = Util.GetTextWidth(values.name)
    if not nameWidth or nameWidth > Config.location.maxNameWidth then
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
    self.saved = true
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
    local mapID = frame.mapID
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
    local frame = CreateFrame("Frame", SMK.name .. "LocationForm", parent)
    self.frame = frame
    frame:SetSize(EditorConfig.width, EditorConfig.height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(500)
    frame:EnableMouse(true)
    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(Config.panel.backgroundAtlas, false)
    frame.borderAtlas = frame:CreateTexture(nil, "BORDER", nil, 7)
    frame.borderAtlas:SetAllPoints(frame)
    frame.borderAtlas:SetAtlas(Config.panel.borderAtlas, false)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, EditorConfig.titleOffsetY)
    frame.title:SetTextColor(unpack(Config.colors.gold))
    frame.mapName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.mapName:SetPoint("TOP", frame.title, "BOTTOM", 0, EditorConfig.mapNameOffsetY)

    -- Category row
    local categoryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.categoryRowY)
    categoryLabel:SetTextColor(unpack(Config.colors.gold))
    categoryLabel:SetText(SMK.L.CATEGORY_LABEL)
    self.dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    self.dropdown:SetSize(EditorConfig.inputWidth, EditorConfig.buttonHeight)
    self.dropdown:SetPoint("LEFT", categoryLabel, "RIGHT", EditorConfig.labelGap, 0)
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

    -- Name: label left of input
    local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.nameRowY)
    nameLabel:SetTextColor(unpack(Config.colors.gold))
    nameLabel:SetText(SMK.L.NAME_LABEL)
    local nameInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameInput:SetSize(EditorConfig.inputWidth, EditorConfig.buttonHeight)
    nameInput:SetPoint("LEFT", nameLabel, "RIGHT", EditorConfig.labelGap, 0)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(Config.location.maxNameLength)
    nameInput:SetTextColor(1, 1, 1)

    -- X coordinate
    local xLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.xRowY)
    xLabel:SetTextColor(unpack(Config.colors.gold))
    xLabel:SetText(SMK.L.X_LABEL)
    local xInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    xInput:SetSize(EditorConfig.inputWidth, EditorConfig.buttonHeight)
    xInput:SetPoint("LEFT", xLabel, "RIGHT", EditorConfig.labelGap, 0)
    xInput:SetAutoFocus(false)
    xInput:SetMaxLetters(Config.location.maxCoordinateLength)
    xInput:SetTextColor(1, 1, 1)

    -- Y coordinate
    local yLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.yRowY)
    yLabel:SetTextColor(unpack(Config.colors.gold))
    yLabel:SetText(SMK.L.Y_LABEL)
    local yInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    yInput:SetSize(EditorConfig.inputWidth, EditorConfig.buttonHeight)
    yInput:SetPoint("LEFT", yLabel, "RIGHT", EditorConfig.labelGap, 0)
    yInput:SetAutoFocus(false)
    yInput:SetMaxLetters(Config.location.maxCoordinateLength)
    yInput:SetTextColor(1, 1, 1)

    self.inputs = { name = nameInput, x = xInput, y = yInput }
    for _, input in pairs(self.inputs) do
        input:SetScript("OnEnterPressed", function() self:Save() end)
    end
    SetTabTarget(self.inputs.name, self.inputs.x)
    SetTabTarget(self.inputs.x, self.inputs.y)
    SetTabTarget(self.inputs.y, self.inputs.name)

    local coordinateButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    self.coordinateButton = coordinateButton
    coordinateButton:SetSize(EditorConfig.coordinateButtonWidth, EditorConfig.buttonHeight)
    coordinateButton:SetPoint("TOP", frame, "TOP", 0, EditorConfig.coordinateButtonY)
    coordinateButton:SetText(SMK.L.READ_COORDINATES)
    coordinateButton:SetScript("OnClick", function() self:FillCoordinates() end)
    frame.error = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    frame.error:SetPoint("TOP", frame, "TOP", 0, EditorConfig.errorY)
    -- 显示标记文字复选框
    self.pinColorCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.pinColorCheck:SetSize(24, 24)
    self.pinColorCheck:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.pinColorRowY)
    self.pinColorCheck:SetChecked(false)
    local pinColorCheckLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinColorCheckLabel:SetPoint("LEFT", self.pinColorCheck, "RIGHT", 4, 0)
    pinColorCheckLabel:SetText(SMK.L.PIN_TEXT_COLOR)
    pinColorCheckLabel:SetTextColor(unpack(Config.colors.gold))
    self.pinColorButton = Widgets:CreatePanelButton(frame, "", { width = 42 })
    self.pinColorButton:SetPoint("LEFT", pinColorCheckLabel, "RIGHT", EditorConfig.labelGap, 0)
    self.pinColorButton.swatch = self.pinColorButton:CreateTexture(nil, "ARTWORK")
    self.pinColorButton.swatch:SetPoint("TOPLEFT", 8, -6)
    self.pinColorButton.swatch:SetPoint("BOTTOMRIGHT", -8, 6)
    self.pinColor = { r = Config.colors.gold[1], g = Config.colors.gold[2], b = Config.colors.gold[3] }
    self.pinColorButton:SetScript("OnClick", function()
        if not self.pinColorCheck:GetChecked() then return end
        local previous = { r = self.pinColor.r, g = self.pinColor.g, b = self.pinColor.b }
        ColorPickerFrame:Hide()
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
        ColorPickerFrame:SetClampedToScreen(true)
        self.colorPickerOpen = true
        self.colorPickerCancelled = false
        ColorPickerFrame:SetupColorPickerAndShow({
            r = self.pinColor.r,
            g = self.pinColor.g,
            b = self.pinColor.b,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                self.pinColor = { r = r, g = g, b = b }
                self.pinColorButton.swatch:SetColorTexture(r, g, b)
                SMK.MapPins:UpdatePinPreviewColor(frame.entry, { r = r, g = g, b = b })
            end,
            cancelFunc = function()
                self.colorPickerCancelled = true
                self.pinColor = previous
                self.pinColorButton.swatch:SetColorTexture(previous.r, previous.g, previous.b)
                SMK.MapPins:UpdatePinPreviewColor(frame.entry, previous)
            end,
        })
    end)
    self.pinColorCheck:SetScript("OnClick", function()
        local checked = self.pinColorCheck:GetChecked()
        self.pinColorButton:SetEnabled(checked)
        pinColorCheckLabel:SetTextColor(unpack(checked and Config.colors.gold or Config.colors.disabled))
        self.pinColorButton.swatch:SetAlpha(checked and 1 or 0.3)
        SMK.MapPins:UpdatePinVisibility(frame.entry, checked, self.pinCheck:GetChecked())
    end)
    if ColorPickerFrame then
        ColorPickerFrame:HookScript("OnHide", function()
            if not self.colorPickerOpen then return end
            self.colorPickerOpen = false
            if not self.colorPickerCancelled then
                local r, g, b = ColorPickerFrame:GetColorRGB()
                self.pinColor = { r = r, g = g, b = b }
                self.pinColorButton.swatch:SetColorTexture(r, g, b)
            end
        end)
    end
    self.pinColorButton.swatch:SetColorTexture(self.pinColor.r, self.pinColor.g, self.pinColor.b)
    self.pinColorButton:SetEnabled(false)
    self.pinColorButton.swatch:SetAlpha(0.3)

    -- 显示标记材质复选框
    self.pinCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.pinCheck:SetSize(24, 24)
    self.pinCheck:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.pinTextureRowY)
    self.pinCheck:SetChecked(false)
    local pinCheckLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinCheckLabel:SetPoint("LEFT", self.pinCheck, "RIGHT", 4, 0)
    pinCheckLabel:SetText(SMK.L.SHOW_PIN_TEXTURES)
    pinCheckLabel:SetTextColor(unpack(Config.colors.gold))
    -- 标记材质单选面板
    local pinTexLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinTexLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.pinTextureLabelY)
    pinTexLabel:SetTextColor(unpack(Config.colors.gold))
    pinTexLabel:SetText(SMK.L.PIN_TEXTURE_LABEL)
    self.pinTexturePanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    self.pinTexturePanel:SetSize(180, 136)
    self.pinTexturePanel:SetPoint("TOP", frame, "TOP", 0, EditorConfig.pinTexturePanelY)
    self.pinTexturePanel:SetBackdrop(Config.resultBackdrop)
    self.pinTexturePanel:SetBackdropColor(0.04, 0.03, 0.02, 0.7)
    self.pinTexturePanel:SetBackdropBorderColor(unpack(Config.colors.panelBorder))
    self.pinTextureButtons = {}
    for index, texture in ipairs(SMK.PinTextures) do
        local button = CreateFrame("Button", nil, self.pinTexturePanel)
        button:SetSize(28, 28)
        local column = (index - 1) % 5
        local row = math.floor((index - 1) / 5)
        button:SetPoint("TOPLEFT", 8 + column * 34, -7 - row * 31)
        button.textureID = texture.id
        button.atlas = texture.atlas
        button.selection = button:CreateTexture(nil, "BACKGROUND")
        button.selection:SetAllPoints(button)
        button.selection:SetColorTexture(unpack(Config.colors.gold))
        button.selection:SetAlpha(0.45)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.icon:SetAtlas(button.atlas, false)
        button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
        button.highlight:SetAllPoints(button)
        button.highlight:SetColorTexture(1, 1, 1, 0.2)
        button:SetScript("OnClick", function() self:SelectPinTexture(button.textureID) end)
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(button.atlas)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        self.pinTextureButtons[#self.pinTextureButtons + 1] = button
    end
    local function UpdatePinTexturePanel()
        local checked = self.pinCheck:GetChecked()
        pinTexLabel:SetTextColor(unpack(checked and Config.colors.gold or Config.colors.disabled))
        for _, button in ipairs(self.pinTextureButtons) do
            button:SetEnabled(checked)
            button.icon:SetDesaturated(not checked)
            button.icon:SetAlpha(checked and 1 or 0.45)
            button.selection:SetShown(button.textureID
                == tonumber(self.pinTextureID or SMK.DefaultPinTextureID))
        end
    end
    self.UpdatePinTexturePanel = UpdatePinTexturePanel
    self.pinCheck:SetScript("OnClick", function()
        self:UpdatePinTexturePanel()
        SMK.MapPins:UpdatePinVisibility(frame.entry, self.pinColorCheck:GetChecked(), self.pinCheck:GetChecked())
    end)

    local save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    save:SetSize(EditorConfig.buttonWidth, EditorConfig.buttonHeight)
    save:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -EditorConfig.bottomButtonOffsetX, EditorConfig.bottomButtonOffsetY)
    save:SetText(SMK.L.SAVE)
    save:SetScript("OnClick", function() self:Save() end)
    self.deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    self.deleteButton:SetSize(EditorConfig.buttonWidth, EditorConfig.buttonHeight)
    self.deleteButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, EditorConfig.bottomButtonOffsetY)
    self.deleteButton:SetText(SMK.L.DELETE)
    self.deleteButton:SetScript("OnClick", function() self:Delete() end)
    local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancel:SetSize(EditorConfig.buttonWidth, EditorConfig.buttonHeight)
    cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", EditorConfig.bottomButtonOffsetX, EditorConfig.bottomButtonOffsetY)
    cancel:SetText(SMK.L.CANCEL)
    cancel:SetScript("OnClick", function() frame:Hide() end)
    frame:SetScript("OnHide", function()
        if self.colorPickerOpen and ColorPickerFrame and ColorPickerFrame:IsShown() then
            if not self.saved then self.colorPickerCancelled = true end
            ColorPickerFrame:Hide()
        end
        SMK.Map:ClearTemporaryWaypoint()
        if not self.saved then
            SMK.MapPins:UpdatePinPreviewColor(frame.entry, self.originalPinColor)
            SMK.MapPins:UpdatePinVisibility(frame.entry, self.originalShowPinName, self.originalShowPinTexture)
        end
        self.saved = false
        for _, input in pairs(self.inputs) do input:ClearFocus() end
    end)
    frame:Hide()
    return frame
end

--- 打开编辑器对话框，编辑现有条目时预填字段。
-- @param mode string "add" 或 "edit"。
-- @param entry table|nil 现有条目（编辑模式）。
-- @param position table|nil 屏幕坐标 {x, y}，从 Alt+点击地图时传入，用于动态定位面板。
function Editor:Open(mode, entry, position)
    local frame = self.frame
    frame:ClearAllPoints()
    if position then
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local panelWidth, panelHeight = EditorConfig.width, EditorConfig.height
        local gap = EditorConfig.positionGap
        local cursorX, cursorY = position.x, position.y
        -- 面板纵向居中于光标，并限制在屏幕范围内
        local panelY = cursorY - panelHeight / 2
        if panelY < 0 then panelY = 0 end
        if panelY + panelHeight > screenHeight then panelY = screenHeight - panelHeight end
        -- 优先放在右侧，空间不足时放左侧
        if cursorX + gap + panelWidth <= screenWidth then
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cursorX + gap, panelY)
        else
            frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", cursorX - gap, panelY)
        end
    else
        frame:SetPoint("CENTER")
    end
    frame.mode, frame.entry = mode, entry
    frame.title:SetText(mode == "edit" and SMK.L.EDIT_TITLE or SMK.L.ADD_TITLE)
    local mapID = entry and tonumber(entry.mapID)
        or SMK.MapContext:GetMapID() or SMK.Map:GetContextMapID()
    frame.mapID = mapID
    frame.mapName:SetText(mapID and string.format(SMK.L.MAP_FORMAT, SMK.Map:GetMapName(mapID), mapID) or SMK.L.UNKNOWN_MAP)
    self.inputs.name:SetText(entry and entry.name or "")
    self.inputs.x:SetText(entry and tostring(entry.x) or "")
    self.inputs.y:SetText(entry and tostring(entry.y) or "")
    self.deleteButton:SetShown(mode == "edit")
    self.categoryKey = entry and Config.GetCategoryKey(entry.categoryKey)
        or Config.defaultCategoryKey
    self:UpdateCategory()
    self.pinCheck:SetChecked(entry and entry.showPinTexture == 1 or false)
    self.pinTextureID = entry and tonumber(entry.pinTextureID) or SMK.DefaultPinTextureID
    if not SMK.PinTextureByID[self.pinTextureID] then
        self.pinTextureID = SMK.DefaultPinTextureID
    end
    self:UpdatePinTexturePanel()
    local showPinName = entry and entry.showPinName == 1 or false
    self.pinColorCheck:SetChecked(showPinName)
    local color = (entry and entry.pinColor) or Config.colors.gold
    self.pinColor = { r = color.r or color[1], g = color.g or color[2], b = color.b or color[3] }
    self.originalPinColor = entry and entry.pinColor and
        { r = entry.pinColor.r, g = entry.pinColor.g, b = entry.pinColor.b } or nil
    self.saved = false
    self.pinColorButton.swatch:SetColorTexture(self.pinColor.r, self.pinColor.g, self.pinColor.b)
    self.pinColorButton:SetEnabled(showPinName)
    self.pinColorButton.swatch:SetAlpha(showPinName and 1 or 0.3)
    self.originalShowPinName = entry and entry.showPinName == 1 or false
    self.originalShowPinTexture = entry and entry.showPinTexture == 1 or false
    self:SetError()
    frame:Show()
    self.inputs.name:SetFocus()
end

function Editor:Hide()
    if self.frame then self.frame:Hide() end
end

function Editor:ContainsMouseFocus(foci)
    return self.colorPickerOpen and ColorPickerFrame and ColorPickerFrame:IsShown()
        and DoesAncestryIncludeAny(ColorPickerFrame, foci)
end

function Editor:IsMenuOpen()
    return self.dropdown and self.dropdown.IsMenuOpen and self.dropdown:IsMenuOpen() or false
end

SMK.LocationEditor = Editor
