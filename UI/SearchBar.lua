local _, SMK = ...

local SearchBar = {}
local Config = SMK.Config
local Art = Config.art
local Util = SMK.Util

local function IsAllMaps()
    return SMK.DB:Get().searchAllMaps
end

--- 检查已保存的栏位置表是否包含有效坐标。
-- @param position table
-- @return boolean
local function IsSavedPosition(position)
    return type(position) == "table" and type(position.x) == "number" and type(position.y) == "number"
end

--- 获取框架锚点的屏幕坐标，考虑缩放比例。
-- @param frame Frame
-- @param point string "TOP" 或 "CENTER"。
-- @return number, number 屏幕坐标 x, y。
local function GetScaledAnchorPoint(frame, point)
    local left, bottom, width, height = frame:GetScaledRect()
    if not left then return end
    if point == "TOP" then return left + width / 2, bottom + height end
    return left + width / 2, bottom + height / 2
end

function SearchBar:ApplyArt()
    local box = self.box
    local verticalScale = Config.search.boxHeight / Art.buttonArtHeight
    local leftWidth = Art.textLeft * verticalScale
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        if box[key] then box[key]:Hide() end
    end
    if box.searchIcon then box.searchIcon:Hide() end
    box.backgroundLeft = box:CreateTexture(nil, "BACKGROUND")
    box.backgroundLeft:SetPoint("TOPLEFT")
    box.backgroundLeft:SetPoint("BOTTOMLEFT")
    box.backgroundLeft:SetWidth(leftWidth)
    box.backgroundLeft:SetTexture(Art.button)
    box.backgroundLeft:SetTexCoord(0, Art.textLeft / Art.buttonTextureWidth,
        0, Art.buttonArtHeight / Art.buttonTextureHeight)
    box.backgroundRight = box:CreateTexture(nil, "BACKGROUND")
    box.backgroundRight:SetPoint("TOPLEFT", box.backgroundLeft, "TOPRIGHT")
    box.backgroundRight:SetPoint("BOTTOMRIGHT")
    box.backgroundRight:SetTexture(Art.button)
    box.backgroundRight:SetTexCoord(Art.textLeft / Art.buttonTextureWidth,
        Art.buttonArtWidth / Art.buttonTextureWidth, 0, Art.buttonArtHeight / Art.buttonTextureHeight)
    box.locationIcon = box:CreateTexture(nil, "ARTWORK")
    box.locationIcon:SetPoint("TOPLEFT", Art.iconLeft * verticalScale, -Art.iconTop * verticalScale)
    box.locationIcon:SetSize(Art.iconWidth * verticalScale, Art.iconHeight * verticalScale)
    box.locationIcon:SetTexture(Art.searchIcon)
    self:UpdateSearchIcon()
    box:SetTextInsets(leftWidth + 1, 20, 0, 0)
    box:SetTextColor(unpack(Config.colors.gold))
    if box.Instructions then
        box.Instructions:ClearAllPoints()
        box.Instructions:SetPoint("LEFT", leftWidth + 1, 0)
        box.Instructions:SetPoint("RIGHT", -20, 0)
        box.Instructions:SetJustifyH("LEFT")
        box.Instructions:SetTextColor(0.7, 0.62, 0.42)
    end
end

--- 切换搜索框图标：当前地图模式 ↔ 全图搜索模式。
function SearchBar:UpdateSearchIcon()
    if IsAllMaps() then
        self.box.locationIcon:SetTexture("")
        self.box.locationIcon:SetAtlas("poi-islands-table", false)
    else
        self.box.locationIcon:SetAtlas(nil)
        self.box.locationIcon:SetTexture(Art.searchIcon)
    end
end

--- 更新搜索框上方的提示文字（"搜索 X" / "全图搜索"）。
function SearchBar:UpdateInstructions()
    if not self.box.Instructions then return end
    self.box.Instructions:SetText(IsAllMaps() and SMK.L.SEARCH_ALL_MAPS
        or string.format(SMK.L.SEARCH_CURRENT_MAP, SMK.Map:GetMapName(SMK.State.currentMapID)))
end

--- 显示搜索框下方的"按住 Shift 移动"提示。
function SearchBar:UpdateMoveHint()
    local text = SMK.L.MOVE_HINT
    if self.bar.positionMode == "shortcut" then
        local key = GetBindingKey(Config.shortcutAction)
        text = string.format(SMK.L.MOVE_HINT_SHORTCUT, key and GetBindingText(key) or SMK.L.NO_KEY_BOUND)
    end
    self.box.moveHint:SetText(text)
end

--- 定位搜索栏：在世界地图上或作为浮动快捷方式。
-- @param mode string "map" 或 "shortcut"。
function SearchBar:ApplyPosition(mode)
    local database = SMK.DB:Get()
    self.bar.positionMode = mode
    self.bar:ClearAllPoints()
    if mode == "shortcut" then
        local position = database.shortcutSearchBarPosition
        if IsSavedPosition(position) then
            self.bar:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
        else
            self.bar:SetPoint("CENTER", UIParent, "CENTER", 0, Config.search.shortcutDefaultOffsetY)
        end
    else
        local position = database.mapSearchBarPosition
        if IsSavedPosition(position) then
            if position.relativePoint == "CENTER" then
                self.bar:SetPoint("CENTER", WorldMapFrame, "CENTER", position.x, position.y)
                if WorldMapFrame:IsShown() then
                    C_Timer.After(0, function()
                        if self.bar and self.bar.positionMode == "map" then self:SavePosition() end
                    end)
                end
            else
                self.bar:SetPoint("CENTER", WorldMapFrame, "TOP", position.x, position.y)
            end
        else
            self.bar:SetPoint("CENTER", WorldMapFrame, "TOP", 0, 0)
        end
    end
    self:UpdateMoveHint()
end

function SearchBar:SavePosition()
    local shortcut = self.bar.positionMode == "shortcut"
    local anchor, relativePoint = shortcut and UIParent or WorldMapFrame, shortcut and "CENTER" or "TOP"
    local sx, sy = GetScaledAnchorPoint(self.bar, "CENTER")
    local ax, ay = GetScaledAnchorPoint(anchor, relativePoint)
    local scale = self.bar:GetEffectiveScale()
    if not sx or not sy or not ax or not ay or not scale or scale == 0 then return end
    local position = { x = (sx - ax) / scale, y = (sy - ay) / scale, relativePoint = relativePoint }
    local database = SMK.DB:Get()
    database[shortcut and "shortcutSearchBarPosition" or "mapSearchBarPosition"] = position
    self.bar:ClearAllPoints()
    self.bar:SetPoint("CENTER", anchor, relativePoint, position.x, position.y)
end

function SearchBar:StartDrag()
    if not IsShiftKeyDown() then return end
    self.bar.isDragging = true
    self.box:ClearFocus()
    self.bar:StartMoving()
end

function SearchBar:StopDrag()
    if not self.bar.isDragging then return end
    self.bar:StopMovingOrSizing()
    self.bar.isDragging = false
    self:SavePosition()
end

--- 隐藏搜索结果下拉框并重置选择。
function SearchBar:HideResults()
    self.selectedIndex, self.visibleCount = 0, 0
    self.results:Hide()
    self.empty:Hide()
    for _, button in ipairs(self.resultWidgets) do
        button.isSearchSelected = false
        button.highlight:Hide()
        button.label:SetTextColor(unpack(Config.colors.locationNormal))
        button:Hide()
    end
    self:UpdateOutsideListener()
end

function SearchBar:UpdateSelection()
    for index, button in ipairs(self.resultWidgets) do
        button.isSearchSelected = index == self.selectedIndex and index <= self.visibleCount and button:IsShown()
        button.highlight:SetShown(button.isSearchSelected)
        button.label:SetTextColor(unpack(button.isSearchSelected
            and Config.colors.locationHover or Config.colors.locationNormal))
    end
end

--- 执行搜索并填充结果下拉框。
-- 文本变更时防抖 50ms。
function SearchBar:UpdateResults()
    local query = Util.Normalize(self.box:GetText())
    self._lastQuery = query
    if query == "" then
        self:HideResults()
        if self.panel and self.panel:IsExpanded() then
            self.panel.frequentRow:Show()
            self.panel:RenderFrequent()
        end
        return
    end
    if self.panel then self.panel.frequentRow:Hide() end
    local source = IsAllMaps() and SMK.Store:GetAll() or SMK.State.currentEntries
    local matches = SMK.Search:Find(source, query, IsAllMaps())
    self.matches = matches
    local visible = #matches
    if visible == 0 then
        self.selectedIndex, self.visibleCount = 0, 0
        for _, button in ipairs(self.resultWidgets) do button:Hide() end
        self.empty:Show()
        self.results:SetWidth(self.box:GetWidth())
        self.results:SetHeight(Config.location.baseHeight + 8)
        self.results:Show()
        return
    end
    self.empty:Hide()
    self.visibleCount, self.selectedIndex = visible, 1
    local y = 4
    local width = math.max(1, self.box:GetWidth() - 8)
    for index, match in ipairs(matches) do
        local button = self.resultWidgets[index]
        if not button then
            button = SMK.Widgets:CreateLocationButton(self.results, self.resultCallbacks)
            self.resultWidgets[index] = button
        end
        button:ClearAllPoints()
        button.background:Show()
        local display
        if match.isMapPortal then
            display = match.entry.name .. SMK.L.MAP_PORTAL_SUFFIX
        elseif IsAllMaps() then
            display = string.format(SMK.L.SEARCH_RESULT_FORMAT, match.mapName, match.entry.name)
        end
        SMK.Widgets:SetLocationEntry(button, match.entry, display)
        SMK.Widgets:StretchSearchResult(button, width)
        button.isSearchResult, button.resultIndex = true, index
        button:SetPoint("TOPLEFT", 4, -y)
        y = y + button:GetHeight() + Config.location.verticalGap
    end
    for index = visible + 1, #self.resultWidgets do self.resultWidgets[index]:Hide() end
    self.results:SetWidth(self.box:GetWidth())
    self.results:SetHeight(y + 2)
    self.results:Show()
    self:UpdateSelection()
    self:UpdateOutsideListener()
end

function SearchBar:SelectResult(button)
    if button.resultIndex then
        self.selectedIndex = button.resultIndex
        self:UpdateSelection()
    end
end

--- 切换当前地图/全图搜索模式。
function SearchBar:ToggleScope()
    local database = SMK.DB:Get()
    database.searchAllMaps = not database.searchAllMaps
    self:UpdateSearchIcon()
    self.box:SetText("")
    self:UpdateInstructions()
    self:UpdateResults()
    self.box:SetFocus()
end

--- 上下移动选中的结果。
-- @param key string "UP" 或 "DOWN"。
function SearchBar:MoveSelection(key)
    if self.visibleCount == 0 or not self.results:IsShown() then return end
    if key == "UP" then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then self.selectedIndex = self.visibleCount end
    elseif key == "DOWN" then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > self.visibleCount then self.selectedIndex = 1 end
    else
        return
    end
    self:UpdateSelection()
end

function SearchBar:SetPanelExpanded(expanded)
    if not self.panel then return end
    self.suppressPanelHidden = not expanded
    self.panel:SetExpanded(expanded)
    self.suppressPanelHidden = false
    if not expanded then self:UpdateResults() end
    self:UpdateOutsideListener()
end

function SearchBar:UpdateModeButton()
    self.modeButton:SetText(SMK.DB:Get().showFullPanel and SMK.L.HIDE_PANEL or SMK.L.SHOW_PANEL)
end

--- 关闭结果面板，清空搜索框，隐藏模式按钮。
function SearchBar:ClosePanel()
    self.suppressPanelHidden = true
    if self.panel then self.panel:SetExpanded(false) end
    self.suppressPanelHidden = false
    self:HideResults()
    self.box:SetText("")
    self.box:ClearFocus()
    self.modeButton:Hide()
    self:UpdateOutsideListener()
end

--- 根据界面可见性注册或注销 GLOBAL_MOUSE_DOWN 监听器。
function SearchBar:UpdateOutsideListener()
    local needs = (self.panel and self.panel:IsExpanded()) or self.results:IsShown() or self.modeButton:IsShown()
    if needs then
        self.outsideListener:RegisterEvent("GLOBAL_MOUSE_DOWN")
    else
        self.outsideListener:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    end
end


function SearchBar:OnPanelHidden()
    if not self.suppressPanelHidden then self:ClosePanel() end
end

function SearchBar:StopShortcutCapture()
    local button = self.shortcutButton
    if not button then return end
    button.isCapturing = false
    if not InCombatLockdown() and button.SetPropagateKeyboardInput then
        button:SetPropagateKeyboardInput(true)
    end
    button:EnableKeyboard(false)
    button:SetText(SMK.L.SHORTCUT)
    self:UpdateMoveHint()
end

--- 设置切换搜索栏的新快捷键。
-- @param newKey string 按键组合（如 "CTRL-SPACE"）。
function SearchBar:ApplyShortcut(newKey)
    local action = GetBindingAction(newKey)
    if action and action ~= "" and action ~= Config.shortcutAction then
        self:StopShortcutCapture()
        return SMK:Print(string.format(SMK.L.KEY_ALREADY_BOUND,
            GetBindingText(newKey), GetBindingName(action)))
    end
    local old1, old2 = GetBindingKey(Config.shortcutAction)
    if old1 then SetBinding(old1) end
    if old2 then SetBinding(old2) end
    if not SetBinding(newKey, Config.shortcutAction) then
        if old1 then SetBinding(old1, Config.shortcutAction) end
        if old2 then SetBinding(old2, Config.shortcutAction) end
        self:StopShortcutCapture()
        return SMK:Print(SMK.L.KEY_BIND_FAILED)
    end
    SaveBindings(GetCurrentBindingSet())
    self:StopShortcutCapture()
    SMK:Print(string.format(SMK.L.KEY_BIND_UPDATED, GetBindingText(newKey)))
end

function SearchBar:StartShortcutCapture()
    if InCombatLockdown() then return SMK:Print(SMK.L.KEY_BIND_IN_COMBAT) end
    self.shortcutButton.isCapturing = true
    self.shortcutButton:SetText(SMK.L.CAPTURE_SHORTCUT)
    GameTooltip_Hide()
    self.shortcutButton:EnableKeyboard(true)
    if self.shortcutButton.SetPropagateKeyboardInput then
        self.shortcutButton:SetPropagateKeyboardInput(false)
    end
end

function SearchBar:AttachPanel(panel)
    self.panel = panel
    self.shortcutButton = panel.shortcutButton
    local button = self.shortcutButton
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function()
        if button.isCapturing then self:StopShortcutCapture() else self:StartShortcutCapture() end
    end)
    button:SetScript("OnKeyDown", function(_, key)
        if not button.isCapturing then return end
        key = GetConvertedKeyOrButton(key)
        if not IsKeyPressIgnoredForBinding(key) then
            self:ApplyShortcut(CreateKeyChordStringUsingMetaKeyState(key))
        end
    end)
    button:SetScript("OnEnter", function(owner)
        local key = GetBindingKey(Config.shortcutAction)
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:SetText(SMK.L.SHORTCUT_TOOLTIP_TITLE)
        GameTooltip:AddLine(string.format(SMK.L.SHORTCUT_TOOLTIP_CURRENT, key and GetBindingText(key) or SMK.L.NO_KEY_BOUND), 1, 1, 1)
        GameTooltip:AddLine(SMK.L.SHORTCUT_TOOLTIP_HINT, 0.35, 0.85, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    self:StopShortcutCapture()
end

function SearchBar:RefreshContext()
    if self.callbacks.onRefreshContext then self.callbacks.onRefreshContext() end
    self:UpdateInstructions()
    self.box:SetText("")
    self.box:ClearFocus()
    self:HideResults()
end

--- 切换浮动搜索栏的可见性（通过快捷键触发）。
function SearchBar:ToggleShortcut()
    if WorldMapFrame:IsShown() then
        self:ApplyPosition("map")
        if not self.bar:IsShown() then self.bar:Show() end
        self.box:SetFocus()
        return
    end
    local database = SMK.DB:Get()
    if self.bar:IsShown() then
        database.shortcutSearchVisible = false
        self.bar:Hide()
    else
        database.shortcutSearchVisible = true
        self:ApplyPosition("shortcut")
        self.bar:Show()
        self.box:SetFocus()
    end
end

--- 创建搜索框框架、编辑框、模式按钮和结果下拉框。
-- 这是整个插件界面的主要入口点。
-- @param callbacks table { onRefreshContext, onActivate, onEdit, onDelete }。
-- @return Frame 搜索栏框架。
function SearchBar:Create(callbacks)
    self.callbacks = callbacks or {}
    self.resultWidgets, self.matches = {}, {}
    self.selectedIndex, self.visibleCount = 0, 0
    local bar = CreateFrame("Frame", SMK.name .. "SearchBar", UIParent)
    self.bar = bar
    bar:SetSize(Config.search.barWidth, Config.search.barHeight)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:SetFrameLevel(70)
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() self:StartDrag() end)
    bar:SetScript("OnDragStop", function() self:StopDrag() end)

    self.box = CreateFrame("EditBox", SMK.name .. "SearchBox", bar, "SearchBoxTemplate")
    self.box:SetSize(Config.search.boxWidth, Config.search.boxHeight)
    self.box:SetPoint("CENTER")
    self.box:SetAutoFocus(false)
    self:ApplyArt()
    self.box:RegisterForDrag("LeftButton")
    self.box:HookScript("OnDragStart", function() self:StartDrag() end)
    self.box:HookScript("OnDragStop", function() self:StopDrag() end)
    self.box.moveHint = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.box.moveHint:SetPoint("BOTTOM", self.box, "TOP", 0, 3)
    self.box.moveHint:SetTextColor(unpack(Config.colors.gold))
    self.box.moveHint:Hide()
    self.box:HookScript("OnEnter", function(box)
        if not box:HasFocus() then box.moveHint:Show() end
    end)
    self.box:HookScript("OnMouseDown", function(box) box.moveHint:Hide() end)
    self.box:HookScript("OnLeave", function(box) box.moveHint:Hide() end)

    self.modeButton = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    self.modeButton:SetSize(Config.search.modeButtonWidth, 22)
    self.modeButton:SetPoint("LEFT", self.box, "RIGHT", 4, 0)
    self.modeButton:SetFrameLevel(bar:GetFrameLevel() + 5)
    self.modeButton:EnableKeyboard(false)
    self.modeButton:SetScript("OnClick", function()
        local database = SMK.DB:Get()
        database.showFullPanel = not database.showFullPanel
        self:UpdateModeButton()
        self:SetPanelExpanded(database.showFullPanel)
        self:UpdateResults()
        self.box:SetFocus()
    end)
    self:UpdateModeButton()
    self.modeButton:Hide()

    self.results = CreateFrame("Frame", SMK.name .. "SearchResults", bar, "BackdropTemplate")
    self.results:SetWidth(self.box:GetWidth())
    self.results:SetPoint("TOPLEFT", self.box, "BOTTOMLEFT", 0, -4)
    self.results:SetFrameLevel(bar:GetFrameLevel() + 20)
    self.results:SetBackdrop(Config.resultBackdrop)
    self.results:SetBackdropColor(0.02, 0.02, 0.02, 1)
    self.results:Hide()
    self.empty = self.results:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.empty:SetPoint("LEFT", 8, 0)
    self.empty:SetTextColor(0.65, 0.65, 0.65)
    self.empty:SetText(SMK.L.NO_MATCH)
    self.empty:Hide()
    self.resultCallbacks = {
        onActivate = self.callbacks.onActivate,
        onEdit = self.callbacks.onEdit,
        onDelete = self.callbacks.onDelete,
        onEnter = function(button) self:SelectResult(button) end,
    }

    local searchTimer
    self.box:HookScript("OnTextChanged", function()
        if searchTimer then searchTimer:Cancel() end
        searchTimer = C_Timer.After(0.05, function()
            searchTimer = nil
            self:UpdateResults()
        end)
    end)
    self.box:HookScript("OnEditFocusGained", function()
        self:StopShortcutCapture()
        self.box.moveHint:Hide()
        self.modeButton:Show()
        self:UpdateModeButton()
        self:SetPanelExpanded(SMK.DB:Get().showFullPanel)
        self:UpdateResults()
    end)
    self.box:SetScript("OnTabPressed", function() self:ToggleScope() end)
    self.box:HookScript("OnArrowPressed", function(_, key)
        if key ~= "UP" and key ~= "DOWN" then return end
        if searchTimer then searchTimer:Cancel() searchTimer = nil end
        -- 仅在查询文本变化或结果未显示时才重新搜索
        local query = Util.Normalize(self.box:GetText())
        if not self.results:IsShown() or not self.matches or query ~= (self._lastQuery or "") then
            self:UpdateResults()
        end
        self:MoveSelection(key)
    end)
    self.box:SetScript("OnEnterPressed", function()
        if searchTimer then searchTimer:Cancel() searchTimer = nil end
        -- 先保存当前选中的索引，再刷新结果（UpdateResults 会重置 selectedIndex）
        local index = self.selectedIndex
        self:UpdateResults()
        local match = self.matches[index > 0 and index or 1]
        if match and self.callbacks.onActivate then self.callbacks.onActivate(match.entry, true) end
    end)
    self.box:SetScript("OnEscapePressed", function()
        if self.panel and self.panel:IsExpanded() then
            self:ClosePanel()
        else
            self.box:ClearFocus()
        end
    end)
    self.box:ClearFocus()

    self.outsideListener = CreateFrame("Frame")
    self.outsideListener:SetScript("OnEvent", function()
        if SMK.ModalManager:IsMenuOpen() then return end
        if not (self.panel and self.panel:IsExpanded()) and not self.results:IsShown()
            and not self.modeButton:IsShown() then return end
        local foci = GetMouseFoci()
        if DoesAncestryIncludeAny(self.panel.frame, foci) or DoesAncestryIncludeAny(bar, foci)
            or SMK.ModalManager:ContainsMouseFocus(foci) then return end
        self:ClosePanel()
    end)

    bar:SetScript("OnShow", function()
        self:RefreshContext()
        self:SetPanelExpanded(false)
        self.modeButton:Hide()
    end)
    bar:SetScript("OnHide", function()
        self:StopDrag()
        self.box.moveHint:Hide()
        self:ClosePanel()
    end)
    bar:Hide()
    return bar
end

SMK.SearchBar = SearchBar
