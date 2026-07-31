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
    Config.ApplyCategoryIcon(self.dropdown.categoryIcon, self.categoryKey)
end

--- 处理来自下拉框的类别选择。
-- @param category string 所选类别的名称。
function Editor:SelectCategory(categoryKey)
    self.categoryKey = Config.categoryByKey[categoryKey] and categoryKey or Config.defaultCategoryKey
    self:UpdateCategory()
end

function Editor:SelectPinTexture(textureID)
    textureID = tonumber(textureID)
    if not SMK.PinTextureByID[textureID] then return end
    self.pinTextureID = textureID
    self:UpdatePinTexturePanel()
    self.pinTexturePicker:Hide()
end

function Editor:SelectCustomIcon(iconID)
    if not SMK.IconCatalog:Get(iconID) then return end
    self.customIconID = tonumber(iconID)
    self:UpdateCustomIconControl()
    self.customIconPicker:Hide()
end

function Editor:UpdateCustomIconControl()
    local checked = self.customIconCheck:GetChecked()
    self.customIconButton:SetEnabled(checked)
    self.customIconLabel:SetTextColor(unpack(
        checked and Config.colors.gold or Config.colors.disabled))
    self.customIconButton.preview:SetAlpha(checked and 1 or 0.35)
    self.customIconButton.preview:SetDesaturated(not checked)
    SMK.IconCatalog:Apply(self.customIconButton.preview,
        self.customIconID or SMK.DefaultCustomIconID)
    self.customIconGrid:SetSelected(self.customIconID)
    self.customIconGrid:SetEnabled(checked)
    if not checked then self.customIconPicker:Hide() end
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
        note = Util.Trim(self.inputs.note:GetText()),
        categoryKey = self.categoryKey,
        showPinName = self.pinNameCheck:GetChecked() and 1 or 0,
        showPinTexture = self.pinCheck:GetChecked() and 1 or 0,
        pinTextureID = self.pinTextureID or SMK.DefaultPinTextureID,
        pinColor = self.pinColorOverrideCheck:GetChecked() and self.pinColor or nil,
        customIconID = self.customIconCheck:GetChecked()
            and tonumber(self.customIconID) or nil,
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
    local noteWidth = Util.GetTextWidth(values.note)
    if not noteWidth or noteWidth > Config.location.maxNoteWidth then
        return self:SetError(SMK.L.ERROR_NOTE_TOO_LONG)
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
function Editor:CanReadPlayerCoordinates(mapID)
    mapID = tonumber(mapID)
    local playerMapID = tonumber(SMK.Map:GetPlayerMapID())
    return mapID ~= nil and playerMapID == mapID
end

function Editor:UpdateCoordinateButton()
    if self.coordinateButton then
        self.coordinateButton:SetEnabled(
            self:CanReadPlayerCoordinates(self.frame and self.frame.mapID))
    end
end

function Editor:FillCoordinates()
    local frame = self.frame
    local mapID = frame.mapID
    if not self:CanReadPlayerCoordinates(mapID) then
        return self:SetError(SMK.L.ERROR_COORDS_READ_FAILED)
    end
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
    local frame = CreateFrame(
        "Frame", SMK.name .. "LocationForm", parent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(EditorConfig.width, EditorConfig.height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(500)
    frame:EnableMouse(true)
    frame.backgroundAtlas = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.backgroundAtlas:SetAllPoints(frame)
    frame.backgroundAtlas:SetAtlas(Config.panel.backgroundAtlas, false)
    Widgets:ApplyPanelBorder(frame)
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
    local dropdownOutset = EditorConfig.dropdownBorderOutset
    self.dropdown:SetSize(
        EditorConfig.inputWidth + dropdownOutset * 2, EditorConfig.buttonHeight)
    self.dropdown:SetPoint("RIGHT", frame, "TOPRIGHT",
        -18 + dropdownOutset, EditorConfig.categoryRowY)
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
                Config.ApplyCategoryIcon(icon, category.key)
                icon:SetPoint("LEFT", button.leftTexture1, "RIGHT", 1, 0)
                button.fontString:ClearAllPoints()
                button.fontString:SetPoint("LEFT", icon, "RIGHT", 3, 0)
            end)
        end
    end)

    -- 自定义地点图标；未启用时继续使用分组或来源的默认图标。
    self.customIconCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.customIconCheck:SetSize(24, 24)
    self.customIconCheck:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.customIconRowY)
    local customIconLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.customIconLabel = customIconLabel
    customIconLabel:SetPoint("LEFT", self.customIconCheck, "RIGHT", 4, 0)
    customIconLabel:SetText(SMK.L.CUSTOM_ICON)
    customIconLabel:SetTextColor(unpack(Config.colors.gold))
    self.customIconButton = Widgets:CreatePanelButton(frame, "",
        { width = EditorConfig.previewButtonSize, height = EditorConfig.previewButtonSize })
    self.customIconButton:SetPoint("RIGHT", frame, "TOPRIGHT", -18, EditorConfig.customIconRowY)
    self.customIconButton.preview = self.customIconButton:CreateTexture(nil, "ARTWORK")
    self.customIconButton.preview:SetPoint("TOPLEFT", 3, -3)
    self.customIconButton.preview:SetPoint("BOTTOMRIGHT", -3, 3)

    self.customIconGrid = SMK.IconGridPicker:Create(frame, {
        entries = SMK.IconCatalog.all,
        columns = EditorConfig.customIconPickerColumns,
        cellSize = EditorConfig.customIconPickerCellSize,
        gap = EditorConfig.customIconPickerGap,
        padding = EditorConfig.customIconPickerPadding,
        showKind = true,
        onSelect = function(iconID) self:SelectCustomIcon(iconID) end,
    })
    self.customIconPicker = self.customIconGrid.frame
    self.customIconPicker:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4,
        EditorConfig.customIconRowY + EditorConfig.previewButtonSize / 2)
    self.customIconPicker:SetFrameStrata("FULLSCREEN_DIALOG")
    self.customIconPicker:SetFrameLevel(frame:GetFrameLevel() + 10)
    self.customIconPicker:SetClampedToScreen(true)
    self.customIconPicker:Hide()
    self.customIconButton:SetScript("OnClick", function()
        if not self.customIconCheck:GetChecked() then return end
        if self.pinTexturePicker then self.pinTexturePicker:Hide() end
        self.customIconPicker:SetShown(not self.customIconPicker:IsShown())
    end)
    self.customIconCheck:SetScript("OnClick", function()
        if self.customIconCheck:GetChecked()
            and not SMK.IconCatalog:Get(self.customIconID) then
            self.customIconID = SMK.DefaultCustomIconID
        end
        self:UpdateCustomIconControl()
    end)

    -- Name: label left of input
    local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.nameRowY)
    nameLabel:SetTextColor(unpack(Config.colors.gold))
    nameLabel:SetText(SMK.L.NAME_LABEL)
    local nameInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameInput:SetSize(EditorConfig.inputWidth, EditorConfig.buttonHeight)
    nameInput:SetPoint("RIGHT", frame, "TOPRIGHT", -18, EditorConfig.nameRowY)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(Config.location.maxNameLength)
    nameInput:SetTextColor(1, 1, 1)

    -- Optional note
    local noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.noteRowY)
    noteLabel:SetTextColor(unpack(Config.colors.gold))
    noteLabel:SetText(SMK.L.NOTE_LABEL)
    local noteInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    noteInput:SetSize(EditorConfig.inputWidth, EditorConfig.buttonHeight)
    noteInput:SetPoint("RIGHT", frame, "TOPRIGHT", -18, EditorConfig.noteRowY)
    noteInput:SetAutoFocus(false)
    noteInput:SetMaxLetters(Config.location.maxNoteLength)
    noteInput:SetTextColor(1, 1, 1)

    -- X coordinate
    local xLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.xRowY)
    xLabel:SetTextColor(unpack(Config.colors.gold))
    xLabel:SetText(SMK.L.X_LABEL)
    local xInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    xInput:SetSize(EditorConfig.inputWidth, EditorConfig.buttonHeight)
    xInput:SetPoint("RIGHT", frame, "TOPRIGHT", -18, EditorConfig.xRowY)
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
    yInput:SetPoint("RIGHT", frame, "TOPRIGHT", -18, EditorConfig.yRowY)
    yInput:SetAutoFocus(false)
    yInput:SetMaxLetters(Config.location.maxCoordinateLength)
    yInput:SetTextColor(1, 1, 1)

    self.inputs = { name = nameInput, note = noteInput, x = xInput, y = yInput }
    for _, input in pairs(self.inputs) do
        input:SetScript("OnEnterPressed", function() self:Save() end)
    end
    SetTabTarget(self.inputs.name, self.inputs.note)
    SetTabTarget(self.inputs.note, self.inputs.x)
    SetTabTarget(self.inputs.x, self.inputs.y)
    SetTabTarget(self.inputs.y, self.inputs.name)

    local coordinateButton = Widgets:CreatePanelButton(
        frame, SMK.L.READ_COORDINATES, {
            width = EditorConfig.coordinateButtonWidth,
            height = EditorConfig.buttonHeight,
        })
    self.coordinateButton = coordinateButton
    coordinateButton:SetPoint("TOP", frame, "TOP", 0, EditorConfig.coordinateButtonY)
    coordinateButton:SetScript("OnClick", function() self:FillCoordinates() end)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", function()
        if frame:IsShown() then self:UpdateCoordinateButton() end
    end)
    frame.error = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    frame.error:SetPoint("TOP", frame, "TOP", 0, EditorConfig.errorY)
    local pinSettingsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinSettingsLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.pinSettingsLabelY)
    pinSettingsLabel:SetText(SMK.L.MAP_PIN_SETTINGS_LABEL)
    pinSettingsLabel:SetTextColor(unpack(Config.colors.gold))
    -- 是否显示该地点的标记名称。
    self.pinNameCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.pinNameCheck:SetSize(24, 24)
    self.pinNameCheck:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.pinNameRowY)
    self.pinNameCheck:SetChecked(false)
    local pinNameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinNameLabel:SetPoint("LEFT", self.pinNameCheck, "RIGHT", 4, 0)
    pinNameLabel:SetText(SMK.L.PIN_TEXT_COLOR)
    pinNameLabel:SetTextColor(unpack(Config.colors.gold))
    self.pinNameCheck:SetScript("OnClick", function()
        local checked = self.pinNameCheck:GetChecked()
        self.pinColorOverrideCheck:SetEnabled(checked)
        SMK.MapPins:UpdatePinVisibility(frame.entry, checked, self.pinCheck:GetChecked())
        self:UpdatePinColorControl()
    end)

    -- 可选的单地点文字颜色；未启用时使用默认金色。
    self.pinColorOverrideCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.pinColorOverrideCheck:SetSize(24, 24)
    self.pinColorOverrideCheck:SetPoint("LEFT", frame, "TOPLEFT", 18, EditorConfig.pinColorRowY)
    self.pinColorOverrideCheck:SetChecked(false)
    local pinColorLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.pinColorLabel = pinColorLabel
    pinColorLabel:SetPoint("LEFT", self.pinColorOverrideCheck, "RIGHT", 4, 0)
    pinColorLabel:SetText(SMK.L.CUSTOM_PIN_COLOR)
    pinColorLabel:SetTextColor(unpack(Config.colors.gold))
    self.pinColorButton = Widgets:CreatePanelButton(frame, "", {
        width = EditorConfig.previewButtonSize,
        height = EditorConfig.previewButtonSize,
    })
    self.pinColorButton:SetPoint("RIGHT", frame, "TOPRIGHT", -18, EditorConfig.pinColorRowY)
    self.pinColorButton.swatch = self.pinColorButton:CreateTexture(nil, "ARTWORK")
    self.pinColorButton.swatch:SetPoint("TOPLEFT", 6, -6)
    self.pinColorButton.swatch:SetPoint("BOTTOMRIGHT", -6, 6)
    self.pinColor = { r = Config.colors.gold[1], g = Config.colors.gold[2], b = Config.colors.gold[3] }
    self.pinColorButton:SetScript("OnClick", function()
        if not self.pinColorOverrideCheck:GetChecked() then return end
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
    function self:UpdatePinColorControl()
        local enabled = self.pinNameCheck:GetChecked()
        local checked = enabled and self.pinColorOverrideCheck:GetChecked()
        self.pinColorOverrideCheck:SetEnabled(enabled)
        self.pinColorButton:SetEnabled(checked)
        pinColorLabel:SetTextColor(unpack(enabled and Config.colors.gold or Config.colors.disabled))
        self.pinColorButton.swatch:SetAlpha(checked and 1 or 0.3)
        if frame.entry then
            SMK.MapPins:UpdatePinPreviewColor(frame.entry, checked and self.pinColor or nil)
        end
    end
    self.pinColorOverrideCheck:SetScript("OnClick", function()
        self:UpdatePinColorControl()
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
    self.pinTextureButton = Widgets:CreatePanelButton(frame, "",
        { width = EditorConfig.previewButtonSize, height = EditorConfig.previewButtonSize })
    self.pinTextureButton:SetPoint("RIGHT", frame, "TOPRIGHT", -18, EditorConfig.pinTextureRowY)
    self.pinTextureButton.preview = self.pinTextureButton:CreateTexture(nil, "ARTWORK")
    self.pinTextureButton.preview:SetPoint("TOPLEFT", 3, -3)
    self.pinTextureButton.preview:SetPoint("BOTTOMRIGHT", -3, 3)
    self.pinTextureGrid = SMK.IconGridPicker:Create(frame, {
        entries = SMK.PinTextures,
        columns = EditorConfig.pinTexturePickerColumns,
        cellSize = EditorConfig.pinTexturePickerCellSize,
        columnGap = EditorConfig.pinTexturePickerColumnGap,
        rowGap = EditorConfig.pinTexturePickerRowGap,
        padding = EditorConfig.pinTexturePickerPadding,
        getValue = function(texture) return texture.id end,
        applyIcon = function(icon, texture) icon:SetAtlas(texture.atlas, false) end,
        getTooltip = function(texture) return texture.atlas end,
        onSelect = function(textureID) self:SelectPinTexture(textureID) end,
    })
    self.pinTexturePicker = self.pinTextureGrid.frame
    self.pinTexturePicker:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4,
        EditorConfig.pinTextureRowY + EditorConfig.previewButtonSize / 2)
    self.pinTexturePicker:SetFrameStrata("FULLSCREEN_DIALOG")
    self.pinTexturePicker:SetFrameLevel(frame:GetFrameLevel() + 10)
    self.pinTexturePicker:SetClampedToScreen(true)
    self.pinTexturePicker:Hide()
    self.pinTextureButton:SetScript("OnClick", function()
        if not self.pinCheck:GetChecked() then return end
        self.customIconPicker:Hide()
        self.pinTexturePicker:SetShown(not self.pinTexturePicker:IsShown())
    end)
    local function UpdatePinTexturePanel()
        local checked = self.pinCheck:GetChecked()
        local texture = SMK.PinTextureByID[self.pinTextureID]
            or SMK.PinTextureByID[SMK.DefaultPinTextureID]
        self.pinTextureButton:SetEnabled(checked)
        self.pinTextureButton.preview:SetAtlas(texture.atlas, false)
        self.pinTextureButton.preview:SetAlpha(checked and 1 or 0.35)
        self.pinTextureButton.preview:SetDesaturated(not checked)
        self.pinTextureGrid:SetSelected(texture.id)
        self.pinTextureGrid:SetEnabled(checked)
        if not checked then self.pinTexturePicker:Hide() end
    end
    self.UpdatePinTexturePanel = UpdatePinTexturePanel
    self.pinCheck:SetScript("OnClick", function()
        self:UpdatePinTexturePanel()
        SMK.MapPins:UpdatePinVisibility(frame.entry, self.pinNameCheck:GetChecked(), self.pinCheck:GetChecked())
    end)

    local save = Widgets:CreatePanelButton(frame, SMK.L.SAVE, {
        width = EditorConfig.buttonWidth,
        height = EditorConfig.buttonHeight,
    })
    save:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -EditorConfig.bottomButtonOffsetX, EditorConfig.bottomButtonOffsetY)
    save:SetScript("OnClick", function() self:Save() end)
    self.deleteButton = Widgets:CreatePanelButton(frame, SMK.L.DELETE, {
        width = EditorConfig.buttonWidth,
        height = EditorConfig.buttonHeight,
    })
    self.deleteButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, EditorConfig.bottomButtonOffsetY)
    self.deleteButton:SetScript("OnClick", function() self:Delete() end)
    local cancel = Widgets:CreatePanelButton(frame, SMK.L.CANCEL, {
        width = EditorConfig.buttonWidth,
        height = EditorConfig.buttonHeight,
    })
    cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", EditorConfig.bottomButtonOffsetX, EditorConfig.bottomButtonOffsetY)
    cancel:SetScript("OnClick", function() frame:Hide() end)
    frame:SetScript("OnHide", function()
        self.customIconPicker:Hide()
        self.pinTexturePicker:Hide()
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

--- 计算地图点位附近的编辑器位置。
-- 优先选择点位到地图左右边缘空间更大且能完整容纳面板的一侧。
function Editor:CalculateMapPointPlacement(position, mapLeft, mapRight, screenWidth, screenHeight)
    local panelWidth, panelHeight = EditorConfig.width, EditorConfig.height
    local gap = EditorConfig.positionGap
    local pointX = tonumber(position and position.x) or screenWidth / 2
    local pointY = tonumber(position and position.y) or screenHeight / 2
    mapLeft = tonumber(mapLeft) or 0
    mapRight = tonumber(mapRight) or screenWidth

    local leftSpace = pointX - mapLeft
    local rightSpace = mapRight - pointX
    local leftFits = leftSpace >= panelWidth + gap
    local rightFits = rightSpace >= panelWidth + gap
    local placeRight
    if rightFits ~= leftFits then
        placeRight = rightFits
    else
        placeRight = rightSpace >= leftSpace
    end

    local panelX = placeRight and pointX + gap or pointX - gap - panelWidth
    panelX = math.max(0, math.min(screenWidth - panelWidth, panelX))
    local panelY = math.max(0, math.min(screenHeight - panelHeight,
        pointY - panelHeight / 2))
    return panelX, panelY, placeRight and "RIGHT" or "LEFT"
end

--- 打开编辑器对话框，编辑现有条目时预填字段。
-- @param mode string "add" 或 "edit"。
-- @param entry table|nil 现有条目（编辑模式）。
-- @param position table|nil 地图点击的屏幕坐标 {x, y}，用于避开点位动态定位面板。
function Editor:Open(mode, entry, position)
    local frame = self.frame
    frame:ClearAllPoints()
    if position then
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local mapCanvas = WorldMapFrame and WorldMapFrame:IsShown()
            and (WorldMapFrame.ScrollContainer or WorldMapFrame) or nil
        local mapLeft = mapCanvas and mapCanvas:GetLeft() or 0
        local mapRight = mapCanvas and mapCanvas:GetRight() or screenWidth
        local panelX, panelY = self:CalculateMapPointPlacement(
            position, mapLeft, mapRight, screenWidth, screenHeight)
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", panelX, panelY)
    else
        frame:SetPoint("CENTER")
    end
    frame.mode, frame.entry = mode, entry
    frame.title:SetText(mode == "edit" and SMK.L.EDIT_TITLE or SMK.L.ADD_TITLE)
    local mapID = entry and tonumber(entry.mapID)
        or SMK.MapContext:GetMapID() or SMK.Map:GetContextMapID()
    frame.mapID = mapID
    self:UpdateCoordinateButton()
    frame.mapName:SetText(mapID and string.format(SMK.L.MAP_FORMAT, SMK.Map:GetMapName(mapID), mapID) or SMK.L.UNKNOWN_MAP)
    self.inputs.name:SetText(entry and entry.name or "")
    self.inputs.note:SetText(entry and entry.note or "")
    self.inputs.x:SetText(entry and tostring(entry.x) or "")
    self.inputs.y:SetText(entry and tostring(entry.y) or "")
    self.deleteButton:SetShown(mode == "edit")
    self.categoryKey = entry and Config.GetCategoryKey(entry.categoryKey)
        or Config.defaultCategoryKey
    self:UpdateCategory()
    local customIconID = entry and tonumber(entry.customIconID) or nil
    local hasCustomIcon = customIconID and SMK.IconCatalog:Get(customIconID) ~= nil
    self.customIconCheck:SetChecked(hasCustomIcon)
    self.customIconID = hasCustomIcon and customIconID or SMK.DefaultCustomIconID
    self:UpdateCustomIconControl()
    self.pinCheck:SetChecked(entry and entry.showPinTexture == 1 or false)
    self.pinTextureID = entry and tonumber(entry.pinTextureID) or SMK.DefaultPinTextureID
    if not SMK.PinTextureByID[self.pinTextureID] then
        self.pinTextureID = SMK.DefaultPinTextureID
    end
    self:UpdatePinTexturePanel()
    local showPinName = entry and entry.showPinName == 1 or false
    self.pinNameCheck:SetChecked(showPinName)
    local hasPinColor = entry and type(entry.pinColor) == "table"
    self.pinColorOverrideCheck:SetChecked(hasPinColor == true)
    local color = (entry and entry.pinColor) or Config.colors.gold
    self.pinColor = { r = color.r or color[1], g = color.g or color[2], b = color.b or color[3] }
    self.originalPinColor = entry and entry.pinColor and
        { r = entry.pinColor.r, g = entry.pinColor.g, b = entry.pinColor.b } or nil
    self.saved = false
    self.pinColorButton.swatch:SetColorTexture(self.pinColor.r, self.pinColor.g, self.pinColor.b)
    self:UpdatePinColorControl()
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

function Editor:CloseTransientMenu(foci)
    if not DoesAncestryIncludeAny then return end
    local function ClosePicker(picker, button)
        if not picker or not picker:IsShown()
            or DoesAncestryIncludeAny(picker, foci)
            or DoesAncestryIncludeAny(button, foci) then return end
        picker:Hide()
    end
    ClosePicker(self.customIconPicker, self.customIconButton)
    ClosePicker(self.pinTexturePicker, self.pinTextureButton)
end

SMK.LocationEditor = Editor
