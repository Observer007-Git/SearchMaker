local _, SMK = ...

local SearchBar = {}
local Config = SMK.Config
local Art = Config.art
local Util = SMK.Util

local function IsAllMaps()
    return SMK.Settings:Get("searchAllMaps")
end

local function GetAtlasDimensions(atlas, styles)
    local info = C_Texture and C_Texture.GetAtlasInfo
        and C_Texture.GetAtlasInfo(atlas)
    if info and info.width and info.width > 0
        and info.height and info.height > 0 then
        return info.width, info.height
    end
    return styles.atlasWidth, styles.atlasHeight
end

--- 创建插件搜索框材质；暴雪原生部件由 SearchBoxTemplate 提供。
function SearchBar:ApplyArt()
    local box = self.box
    local verticalScale = Config.search.boxHeight / Art.buttonArtHeight
    local leftWidth = Art.textLeft * verticalScale
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        if box[key] then box[key]:Hide() end
    end
    if box.searchIcon then box.searchIcon:Hide() end
    local clearButton = box.clearButton or box.ClearButton
    if clearButton then clearButton:Hide() end
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
    box.factionBackground = box:CreateTexture(nil, "BACKGROUND")
    box.factionBackground:SetAllPoints()
    box.locationIcon = box:CreateTexture(nil, "ARTWORK")
    box.locationIcon:SetPoint("TOPLEFT", Art.iconLeft * verticalScale, -Art.iconTop * verticalScale)
    box.locationIcon:SetSize(Art.iconWidth * verticalScale, Art.iconHeight * verticalScale)
    self:UpdateSearchIcon()
    box:SetTextColor(unpack(Config.colors.gold))
    box:SetClipsChildren(true)
    self.portraitTextInset = leftWidth + 1
    self:ApplyStyle()
end

function SearchBar:UpdateNativeClearButton()
    if not self.box then return end
    local clearButton = self.box.clearButton or self.box.ClearButton
    if not clearButton then return end
    local styles = Config.search.appearance.styles
    local native = SMK.Settings:Get("searchBarStyle") == styles.blizzard
    clearButton:SetShown(native
        and (self.box:HasFocus() or self.box:GetText() ~= ""))
end

function SearchBar:ApplyStyle()
    if not self.box then return end
    local box = self.box
    local styles = Config.search.appearance.styles
    local style = SMK.Settings:Get("searchBarStyle")
    local portrait = style == styles.portrait
    local noPortrait = style == styles.noPortrait
    local blizzard = style == styles.blizzard
    box.backgroundLeft:SetShown(portrait)
    box.backgroundRight:SetShown(portrait)
    box.locationIcon:SetShown(portrait)
    box.factionBackground:SetShown(noPortrait)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        if box[key] then box[key]:SetShown(blizzard) end
    end
    if box.searchIcon then box.searchIcon:SetShown(blizzard) end
    box:SetClipsChildren(not blizzard)
    local leftInset, rightInset, verticalInset = self.portraitTextInset, 20, 0
    local boxWidth, boxHeight = Config.search.boxWidth, Config.search.boxHeight
    local barWidth, barHeight = Config.search.barWidth, Config.search.barHeight
    local boxOffsetX = 0
    if noPortrait then
        local faction = UnitFactionGroup("player")
        local atlas = faction == "Horde"
            and styles.hordeAtlas or styles.allianceAtlas
        local atlasWidth, atlasHeight = GetAtlasDimensions(atlas, styles)
        boxWidth = boxHeight * atlasWidth / atlasHeight
        barWidth = Config.search.barWidth + boxWidth - Config.search.boxWidth
        box.factionBackground:SetAtlas(atlas, false)
        leftInset = atlasHeight * boxWidth / atlasWidth + styles.circleGap
        rightInset = styles.rightInset
        verticalInset = styles.verticalInset
    elseif blizzard then
        local resultWidth = Config.search.boxWidth
            - Config.search.resultFrameInset * 2
        boxWidth = resultWidth - styles.blizzardLeftOutset
        boxHeight = styles.blizzardHeight
        barWidth = resultWidth
        barHeight = Config.search.barHeight
            + boxHeight - Config.search.boxHeight
        boxOffsetX = styles.blizzardLeftOutset / 2
        leftInset, rightInset = 16, 20
    end
    box:SetSize(boxWidth, boxHeight)
    box:ClearAllPoints()
    box:SetPoint("CENTER", boxOffsetX, 0)
    if self.bar then self.bar:SetSize(barWidth, barHeight) end
    box:SetTextInsets(leftInset, rightInset, verticalInset, verticalInset)
    if blizzard then
        box:SetTextColor(1, 1, 1)
    else
        local color = Config.colors.gold
        box:SetTextColor(color[1], color[2], color[3])
    end
    if box.Instructions then
        box.Instructions:ClearAllPoints()
        box.Instructions:SetPoint("LEFT", leftInset, 0)
        box.Instructions:SetPoint("RIGHT", -rightInset, 0)
        box.Instructions:SetJustifyH("LEFT")
        if blizzard then
            box.Instructions:SetTextColor(0.35, 0.35, 0.35)
        else
            box.Instructions:SetTextColor(0.7, 0.62, 0.42)
        end
    end
    self:UpdateNativeClearButton()
    if self.searchResults then self.searchResults:RefreshStyleAlignment() end
end

--- 切换搜索框图标：当前地图模式 ↔ 全图搜索模式。
function SearchBar:UpdateSearchIcon()
    self.box.locationIcon:SetTexture(IsAllMaps() and Art.searchAllMapsIcon or Art.searchIcon)
    self.box.locationIcon:SetTexCoord(0, 1, 0, 1)
end

--- 更新搜索框上方的提示文字（"搜索 X" / "全图搜索"）。
function SearchBar:UpdateInstructions()
    if not self.box.Instructions then return end
    self.box.Instructions:SetText(IsAllMaps() and SMK.L.SEARCH_ALL_MAPS
        or string.format(SMK.L.SEARCH_CURRENT_MAP,
            SMK.Map:GetMapName(SMK.MapContext:GetMapID())))
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

function SearchBar:ApplyScale()
    local scale = SMK.Settings:Get("searchBarScale") or 1
    self.bar:SetScale(scale)
end

function SearchBar:ApplyOpacity()
    local opacity = SMK.Settings:Get("searchBarOpacity") or 1
    if self.bar then self.bar:SetAlpha(1) end
    if self.box then self.box:SetAlpha(opacity) end
    if self.box and self.box.moveHint then self.box.moveHint:SetAlpha(opacity) end
end

--- 定位搜索栏：在世界地图上或作为浮动快捷方式。
-- @param mode string "map" 或 "shortcut"。
function SearchBar:ApplyPosition(mode)
    self.positionController:Apply(mode)
end

function SearchBar:StartDrag()
    if not self.positionController:StartDrag() then return end
    self:CancelPendingSearch()
    self:HideResults()
end

function SearchBar:StopDrag()
    self.positionController:StopDrag()
end

function SearchBar:HideResults()
    self.searchResults:Hide()
end

function SearchBar:DismissResults()
    self:CancelPendingSearch()
    self:HideResults()
    self:ClearFocus()
    if self.panel and self.panel:IsExpanded() then
        self.panel:SetSearchActive(false)
    end
    self:UpdateOutsideListener()
end

function SearchBar:SetQuery(text)
    self.suppressTextChanged = true
    self.box:SetText(text or "")
    self.suppressTextChanged = false
end

function SearchBar:CancelPendingSearch()
    self.searchToken = (self.searchToken or 0) + 1
    if self.searchTimer then
        self.searchTimer:Cancel()
        self.searchTimer = nil
    end
end

function SearchBar:ScheduleResults()
    self:CancelPendingSearch()
    local token = self.searchToken
    self.searchTimer = C_Timer.NewTimer(0.05, function()
        if self.searchToken ~= token then return end
        self.searchTimer = nil
        self:UpdateResults()
    end)
end

function SearchBar:RefreshResultsIfVisible()
    if not self.bar:IsShown() then return end
    local query = Util.Normalize(self.box:GetText())
    if query ~= "" or self.searchResults:IsShown() then self:UpdateResults() end
end

function SearchBar:ShowHistory()
    self._lastQuery = ""
    if self.panel and self.panel:IsExpanded() then
        self.panel:SetSearchActive(false)
        self:HideResults()
        return
    end
    self.searchResults:RenderHistory(SMK.SearchHistory:GetQueries())
end

function SearchBar:ActivateEntry(entry, fromSearchResult)
    if entry.isSearchHistory then
        SMK.SearchHistory:RecordQuery(entry.query)
        self:SetQuery(entry.query)
        self:UpdateResults()
        self.box:SetFocus()
        return
    end
    local query = Util.Trim(self.box:GetText())
    if query ~= "" then SMK.SearchHistory:RecordQuery(query) end
    if self.callbacks.onActivate then
        self.callbacks.onActivate(entry, fromSearchResult)
    end
end

--- 执行搜索并填充结果下拉框。
-- 文本变更时防抖 50ms。
function SearchBar:UpdateResults()
    local query = Util.Trim(self.box:GetText())
    self._lastQuery = Util.Normalize(query)
    if query == "" then
        if self.box:HasFocus() then
            self:ShowHistory()
        else
            self:HideResults()
            if self.panel and self.panel:IsExpanded() then
                self.panel:SetSearchActive(false)
            end
        end
        return
    end
    if self.panel then self.panel:SetSearchActive(true) end
    local source = SMK.MapContext:GetSearchEntries(IsAllMaps())
    self.searchResults:Render(source, query, IsAllMaps())
end

function SearchBar:RefreshPlayerContext()
    if IsAllMaps() or (WorldMapFrame and WorldMapFrame:IsShown()) then return end
    if self.callbacks.onPlayerContextRequested then
        self.callbacks.onPlayerContextRequested()
    end
end

--- 切换当前地图/全图搜索模式。
function SearchBar:ToggleScope()
    local changed, message = SMK.Settings:Set("searchAllMaps", not IsAllMaps())
    if not changed then return SMK:Print(message) end
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
    self.panelController:SetExpanded(expanded)
end

function SearchBar:OpenPanel()
    self.panelController:Open()
end

--- 关闭主面板和搜索结果，并清空搜索框。
function SearchBar:ClosePanel()
    self.panelController:Close()
end

--- 根据界面可见性注册或注销 GLOBAL_MOUSE_DOWN 监听器。
function SearchBar:UpdateOutsideListener()
    self.panelController:UpdateOutsideListener()
end


function SearchBar:OnPanelHidden()
    self.panelController:OnPanelHidden()
end

function SearchBar:StopShortcutCapture()
    if self.shortcutController then self.shortcutController:StopCapture() end
end

function SearchBar:AttachPanel(panel)
    self.panel = panel
    self.panelController:AttachPanel(panel)
    self.shortcutButton = panel.shortcutButton
    self.shortcutController = SMK.ShortcutController:New(self.shortcutButton, {
        onChanged = function() self:UpdateMoveHint() end,
    })
end

function SearchBar:IsVisible()
    return self.bar and self.bar:IsShown()
end

function SearchBar:IsMapMode()
    return self.bar and self.bar.positionMode == "map"
end

function SearchBar:GetQuery()
    return self.box and self.box:GetText() or ""
end

function SearchBar:Focus()
    if self.box then self.box:SetFocus() end
end

function SearchBar:ClearFocus()
    if self.box then self.box:ClearFocus() end
end

function SearchBar:PrepareForDialog()
    self:HideResults()
    self:SetQuery("")
    self:ClearFocus()
end

function SearchBar:ShowForMap()
    self:ApplyPosition("map")
    if not self:IsVisible() then self.bar:Show() end
    self:SetPanelExpanded(false)
end

function SearchBar:HandleWorldMapHidden()
    if SMK.Settings:Get("searchBarMapOnly") then
        self.bar:Hide()
    elseif SMK.Settings:Get("shortcutSearchVisible") then
        self:ApplyPosition("shortcut")
        self:SetPanelExpanded(false)
    else
        self.bar:Hide()
    end
end

function SearchBar:RestoreVisibility()
    if WorldMapFrame:IsShown() then
        self:ShowForMap()
    elseif SMK.Settings:Get("searchBarMapOnly") then
        self.bar:Hide()
    elseif SMK.Settings:Get("shortcutSearchVisible") then
        self:ApplyPosition("shortcut")
        self.bar:Show()
    else
        self.bar:Hide()
    end
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
    if SMK.Settings:Get("searchBarMapOnly") then
        if self.bar:IsShown() then self.bar:Hide() end
        return
    end
    if self.bar:IsShown() then
        local changed, message = SMK.Settings:Set("shortcutSearchVisible", false)
        if not changed then return SMK:Print(message) end
        self.bar:Hide()
    else
        local changed, message = SMK.Settings:Set("shortcutSearchVisible", true)
        if not changed then return SMK:Print(message) end
        self:ApplyPosition("shortcut")
        self.bar:Show()
        self.box:SetFocus()
    end
end

--- 创建搜索框框架、编辑框和结果下拉框。
-- 这是整个插件界面的主要入口点。
-- @param callbacks table { onShown, onPlayerContextRequested, onActivate, onContext }。
-- @return Frame 搜索栏框架。
function SearchBar:Create(callbacks)
    self.callbacks = callbacks or {}
    self.panelController = SMK.PanelController:New(self)
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
    self.box:HookScript("OnMouseDown", function(box, button)
        box.moveHint:Hide()
        if button == "LeftButton" or button == "RightButton" then
            self:RefreshPlayerContext()
        end
        if button == "RightButton" then
            self:OpenPanel()
        elseif button == "MiddleButton" then
            ToggleWorldMap()
        elseif button == "LeftButton" and not IsShiftKeyDown()
            and Util.Trim(box:GetText()) == "" then
            self:ShowHistory()
        end
    end)
    self.box:HookScript("OnLeave", function(box) box.moveHint:Hide() end)

    self.searchResults = SMK.SearchResults:New(bar, self.box, {
        onActivate = function(entry, fromSearchResult)
            self:ActivateEntry(entry, fromSearchResult)
        end,
        onHistory = function(query)
            self:ActivateEntry({ isSearchHistory = true, query = query })
        end,
        onContext = self.callbacks.onContext,
        onVisibilityChanged = function() self:UpdateOutsideListener() end,
    })
    self.results = self.searchResults.frame

    self.box:HookScript("OnTextChanged", function()
        self:UpdateNativeClearButton()
        if not self.suppressTextChanged then self:ScheduleResults() end
    end)
    self.box:HookScript("OnEditFocusGained", function()
        self:UpdateNativeClearButton()
        self:StopShortcutCapture()
        self.box.moveHint:Hide()
        if IsShiftKeyDown() then
            self:CancelPendingSearch()
            self:HideResults()
        else
            self:UpdateResults()
        end
    end)
    self.box:HookScript("OnEditFocusLost", function()
        self:UpdateNativeClearButton()
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
        if match then self:ActivateEntry(match.entry, true) end
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
    self.outsideListener:SetScript("OnEvent", function(_, _, button)
        self.panelController:HandleGlobalMouseDown(button)
    end)

    bar:SetScript("OnShow", function()
        self:RefreshContext()
        self:SetPanelExpanded(false)
        if self.callbacks.onShown then self.callbacks.onShown() end
    end)
    bar:SetScript("OnHide", function()
        self:StopDrag()
        self.box.moveHint:Hide()
        self:ClosePanel()
    end)
    bar:Hide()
    self:ApplyScale()
    self:ApplyOpacity()
    return bar
end

SMK.SearchBar = SearchBar
