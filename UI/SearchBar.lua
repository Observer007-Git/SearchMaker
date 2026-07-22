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
    self.positionController:Apply(mode)
end

function SearchBar:SavePosition()
    self.positionController:Save()
end

function SearchBar:StartDrag()
    self.positionController:StartDrag()
end

function SearchBar:StopDrag()
    self.positionController:StopDrag()
end

function SearchBar:HideResults()
    self.searchResults:Hide()
end

function SearchBar:SetQuery(text)
    self.suppressTextChanged = true
    self.box:SetText(text or "")
    self.suppressTextChanged = false
end

function SearchBar:CancelPendingSearch()
    if self.searchTimer then self.searchTimer:Cancel() self.searchTimer = nil end
end

function SearchBar:ScheduleResults()
    self:CancelPendingSearch()
    self.searchTimer = C_Timer.After(0.05, function()
        self.searchTimer = nil
        self:UpdateResults()
    end)
end

function SearchBar:RefreshResultsIfVisible()
    if not self.bar:IsShown() then return end
    local query = Util.Normalize(self.box:GetText())
    if query ~= "" or self.searchResults:IsShown() then self:UpdateResults() end
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
        end
        return
    end
    if self.panel then self.panel.frequentRow:Hide() end
    local source = IsAllMaps() and SMK.Store:GetAll() or SMK.State.currentEntries
    self.searchResults:Render(source, query, IsAllMaps())
end

--- 切换当前地图/全图搜索模式。
function SearchBar:ToggleScope()
    local database = SMK.DB:Get()
    database.searchAllMaps = not database.searchAllMaps
    self:UpdateSearchIcon()
    self:SetQuery("")
    self:HideResults()
    self:UpdateInstructions()
    self.box:SetFocus()
end

--- 上下移动选中的结果。
-- @param key string "UP" 或 "DOWN"。
function SearchBar:MoveSelection(key)
    self.searchResults:MoveSelection(key)
end

function SearchBar:SetPanelExpanded(expanded)
    if not self.panel then return end
    self.suppressPanelHidden = not expanded
    self.panel:SetExpanded(expanded)
    self.suppressPanelHidden = false
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
    self:CancelPendingSearch()
    self:SetQuery("")
    self.box:ClearFocus()
    self.modeButton:Hide()
    self:UpdateOutsideListener()
end

--- 根据界面可见性注册或注销 GLOBAL_MOUSE_DOWN 监听器。
function SearchBar:UpdateOutsideListener()
    local needs = (self.panel and self.panel:IsExpanded())
        or self.searchResults:IsShown() or self.modeButton:IsShown()
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
    if self.shortcutController then self.shortcutController:StopCapture() end
end

function SearchBar:StartShortcutCapture()
    if self.shortcutController then self.shortcutController:StartCapture() end
end

function SearchBar:AttachPanel(panel)
    self.panel = panel
    self.shortcutButton = panel.shortcutButton
    self.shortcutController = SMK.ShortcutController:New(self.shortcutButton, {
        onChanged = function() self:UpdateMoveHint() end,
    })
end

function SearchBar:RefreshContext()
    self:UpdateInstructions()
    self:CancelPendingSearch()
    self:SetQuery("")
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
-- @param callbacks table { onShown, onActivate, onEdit, onDelete }。
-- @return Frame 搜索栏框架。
function SearchBar:Create(callbacks)
    self.callbacks = callbacks or {}
    local bar = CreateFrame("Frame", SMK.name .. "SearchBar", UIParent)
    self.bar = bar
    self.positionController = SMK.SearchBarPosition:New(self)
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

    self.searchResults = SMK.SearchResults:New(bar, self.box, {
        onActivate = self.callbacks.onActivate,
        onEdit = self.callbacks.onEdit,
        onDelete = self.callbacks.onDelete,
        onVisibilityChanged = function() self:UpdateOutsideListener() end,
    })
    self.results = self.searchResults.frame

    self.box:HookScript("OnTextChanged", function()
        if not self.suppressTextChanged then self:ScheduleResults() end
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
        self:CancelPendingSearch()
        -- 仅在查询文本变化或结果未显示时才重新搜索
        local query = Util.Normalize(self.box:GetText())
        if not self.searchResults:IsShown() or query ~= (self._lastQuery or "") then
            self:UpdateResults()
        end
        self:MoveSelection(key)
    end)
    self.box:SetScript("OnEnterPressed", function()
        self:CancelPendingSearch()
        local query = Util.Normalize(self.box:GetText())
        if not self.searchResults:IsShown() or query ~= (self._lastQuery or "") then
            self:UpdateResults()
        end
        local match = self.searchResults:GetSelected()
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
        if not (self.panel and self.panel:IsExpanded()) and not self.searchResults:IsShown()
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
        if self.callbacks.onShown then self.callbacks.onShown() end
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
