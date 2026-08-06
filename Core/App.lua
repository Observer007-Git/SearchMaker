local _, SMK = ...

BINDING_HEADER_SEARCHMAKER = SMK.L.BINDING_HEADER
BINDING_NAME_SEARCHMAKER_TOGGLE_SEARCH = SMK.L.BINDING_NAME

local App = {}

local function GetStoreErrorMessage(errorMessage)
    if errorMessage == "READ_ONLY" then return SMK.DB:GetReadOnlyMessage() end
    if errorMessage == "INVALID_LOCATION" then return SMK.L.SAVE_FAILED end
    return errorMessage
end

local RefreshProfiles = {
    initialize = { context = true, panel = true, instructions = true },
    visible = { context = true, instructions = true },
    map = { context = true, panel = true, instructions = true, resetSearch = true },
    data = {
        context = true, panel = true, pins = true, instructions = true,
        search = true,
    },
    search = { search = true },
    scale = { panel = true, search = true },
    pins = { pins = true },
    scope = { searchIcon = true, instructions = true, search = true },
    external = { context = true, instructions = true, search = true, recent = true },
    usage = { frequent = true },
    history = { recent = true },
}

function App:GetRefreshCoordinator()
    if not self.refreshCoordinator then
        self.refreshCoordinator = SMK.RefreshCoordinator:New(
            function(flags) self:FlushRefresh(flags) end,
            function(callback) C_Timer.After(0, callback) end)
    end
    return self.refreshCoordinator
end

--- 请求一次合并刷新。相邻地图事件会在下一帧统一处理。
function App:RequestRefresh(reason)
    local flags = RefreshProfiles[reason]
    if flags then self:GetRefreshCoordinator():Request(flags) end
end

function App:FlushRefresh(flags)
    if flags.context then
        local mapID = self.pendingContextMapID
        local forceExternal = self.pendingForceExternal == true
        self.pendingContextMapID, self.pendingForceExternal = nil, false
        self:LoadContext(mapID, forceExternal)
    end
    if flags.pins then SMK.MapPins:Refresh() end
    if not self.initialized then return end

    if SMK.MainPanel:IsExpanded() then
        if flags.panel then
            SMK.MainPanel:Refresh()
        else
            if flags.frequent then SMK.MainPanel:RenderFrequent() end
            if flags.recent then SMK.MainPanel:RenderRecentSearchResults() end
        end
    end
    if flags.searchIcon then SMK.SearchBar:UpdateSearchIcon() end
    if not SMK.SearchBar:IsVisible() then return end
    if flags.resetSearch then
        SMK.SearchBar:RefreshContext()
    else
        if flags.instructions then SMK.SearchBar:UpdateInstructions() end
        if flags.search then SMK.SearchBar:RefreshResultsIfVisible() end
    end
end

function App:RequestMapRefresh(mapID, forceExternal)
    self.pendingContextMapID = tonumber(mapID) or self.pendingContextMapID
    self.pendingForceExternal = self.pendingForceExternal or forceExternal == true
    self:RequestRefresh("map")
end

--- 外部地点缓存失效或构建完成时刷新当前上下文，不清空现有搜索词。
function App:ExternalDataChanged(mapID)
    local currentMapID = SMK.MapContext:GetMapID()
    mapID = tonumber(mapID)
    if mapID and currentMapID and mapID ~= currentMapID then return end
    self.pendingContextMapID = currentMapID or mapID
    self:RequestRefresh("external")
end

function App:StoreChanged(reason)
    if reason == "locations" and SMK.Route then
        SMK.Route:RefreshSavedEntries()
    end
    self:RequestRefresh(reason == "usage" and "usage" or "data")
end

function App:SettingChanged(key)
    if key == "locationScale" then
        self:RequestRefresh("scale")
    elseif key == "mapPinTextScale" or key == "mapPinNameOffsetX"
        or key == "mapPinNameOffsetY" or key == "pinTextureScale" then
        self:RequestRefresh("pins")
    elseif key == "searchAllMaps" then
        self:RequestRefresh("scope")
    elseif key == "searchBarMapOnly" then
        SMK.SearchBar:RestoreVisibility()
    elseif key == "thirdPartySearchEnabled" then
        SMK.HandyNotesProvider:SetEnabled(
            SMK.Settings:Get("thirdPartySearchEnabled") == true)
        self.pendingContextMapID = SMK.MapContext:GetMapID()
        self:RequestRefresh("external")
    end
end

--- 刷新当前地图上下文快照。
-- 在地图切换、数据变更和启动时调用。
function App:LoadContext(mapID, forceExternal)
    SMK.MapContext:Refresh(mapID, forceExternal)
end

--- 浮动搜索框被点击时同步角色当前地图及其外部地点缓存。
function App:RefreshPlayerSearchContext()
    if SMK.Settings:Get("searchAllMaps")
        or (WorldMapFrame and WorldMapFrame:IsShown()) then return end
    local mapID = SMK.Map:GetPlayerMapID()
    if not mapID then return end
    self:LoadContext(mapID, false)
    SMK.SearchBar:UpdateInstructions()
end

--- 激活地点：为用户条目设置路径点，或为地图传送门跳转到目标地图。
-- 全图搜索中的跨地图自建地点会先打开目标地图，再设置路径点并延迟高亮。
-- @param entry table 地点条目或地图传送门条目。
-- @param fromSearchResult boolean 是否来自搜索结果下拉框。
function App:Activate(entry, fromSearchResult, keepPanelOpen)
    if entry.isSavedRoute then
        local opened = self:OpenSavedRoute(entry)
        if opened and fromSearchResult then SMK.SearchHistory:RecordResult(entry) end
        return opened
    end
    if entry.isMapPortal then
        if SMK.Map:OpenMap(entry.mapID) then
            if fromSearchResult then SMK.SearchHistory:RecordResult(entry) end
            -- 播放传送门音效
            PlaySound(SMK.Config.share.portalSoundID)
            if not keepPanelOpen then SMK.SearchBar:ClosePanel() end
            SMK.SearchBar:ShowForMap()
            SMK.SearchBar:Focus()
        end
        return
    end
    local openedTargetMap = false
    local isAllMapsSavedResult = fromSearchResult
        and SMK.Settings:Get("searchAllMaps")
        and entry.source == "saved"
    local playerMapID = isAllMapsSavedResult and SMK.Map:GetPlayerMapID() or nil
    if playerMapID and tonumber(entry.mapID) ~= tonumber(playerMapID) then
        openedTargetMap = SMK.Map:OpenMap(entry.mapID)
    elseif isAllMapsSavedResult
        and SMK.SearchBar:IsMapMode()
        and WorldMapFrame:IsShown() then
        SMK.Map:OpenMap(entry.mapID)
    end
    local marked, message = SMK.Map:SetWaypoint(entry)
    GameTooltip_Hide()
    if marked then
        if fromSearchResult then SMK.SearchHistory:RecordResult(entry) end
        PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON)
        SMK.Store:RecordUsage(entry)
        if openedTargetMap then
            self:QueueLocationHighlight(entry)
        else
            SMK.MapPins:ShowTargetHighlight(entry)
        end
    else
        PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_BUTTON_CLICK_OFF)
        if message then SMK:Print(message) end
    end
    if not keepPanelOpen then SMK.SearchBar:ClosePanel() end
    return marked
end

local function FormatCoordinate(value)
    return (string.format("%.2f", tonumber(value) or 0)
        :gsub("0+$", ""):gsub("%.$", ""))
end

function App:CopyCoordinates(entry)
    SMK.ModalManager:PrepareToShow(SMK.CopyDialog)
    SMK.CopyDialog:Open(SMK.L.COPY_COORDINATES_TITLE,
        FormatCoordinate(entry.x) .. "," .. FormatCoordinate(entry.y))
end

function App:GetShareEntry(entry)
    if not entry.isExternal then return entry end
    return SMK.LocationModel:Normalize({
        mapID = entry.mapID,
        x = entry.x,
        y = entry.y,
        name = entry.name,
        categoryKey = SMK.Config.defaultCategoryKey,
        note = entry.note,
    })
end

function App:ShareCoordinate(entry)
    local shareEntry = self:GetShareEntry(entry)
    if not shareEntry then return SMK:Print(SMK.L.SAVE_FAILED) end
    SMK.ModalManager:PrepareToShow(SMK.CopyDialog)
    SMK.CopyDialog:Open(SMK.L.SHARE_COORDINATE_TITLE,
        SMK.ShareCodec:Encode({ shareEntry }))
end

function App:QueueLocationHighlight(entry)
    self.locationHighlightToken = (self.locationHighlightToken or 0) + 1
    self.pendingLocationHighlight = {
        entry = entry,
        token = self.locationHighlightToken,
    }
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:ShowPendingLocationHighlight(WorldMapFrame:GetMapID())
    end
end

function App:ShowPendingLocationHighlight(mapID)
    local request = self.pendingLocationHighlight
    if not request or not WorldMapFrame or not WorldMapFrame:IsShown()
        or tonumber(mapID) ~= request.entry.mapID then return false end
    self.pendingLocationHighlight = nil
    C_Timer.After(0, function()
        if self.locationHighlightToken == request.token
            and WorldMapFrame:IsShown()
            and WorldMapFrame:GetMapID() == request.entry.mapID then
            SMK.MapPins:ShowTargetHighlight(request.entry)
        end
    end)
    return true
end

function App:OpenLocationOnMap(entry)
    if type(entry) ~= "table" or not tonumber(entry.mapID) then return false end
    self:QueueLocationHighlight(entry)
    if not SMK.Map:OpenMap(entry.mapID) then
        self.pendingLocationHighlight = nil
        return false
    end
    SMK.SearchBar:ClosePanel()
    self:ShowPendingLocationHighlight(WorldMapFrame:GetMapID())
    return true
end

function App:AddToRoute(entry)
    local added, reason = SMK.Route:Add(entry)
    if added then
        SMK:Print(string.format(SMK.L.ROUTE_ADDED, entry.name))
        return true
    end
    local message = reason == "ROUTE_DUPLICATE" and SMK.L.ROUTE_DUPLICATE
        or reason == "ROUTE_FULL" and string.format(
            SMK.L.ROUTE_FULL, SMK.Config.route.maxEntries)
        or SMK.L.SAVE_FAILED
    SMK:Print(message)
    return false
end

function App:OpenSavedRoute(route)
    local saved = SMK.RouteStore:GetByID(route and route.id)
    if not saved then
        SMK:Print(SMK.L.ROUTE_NOT_FOUND)
        return false
    end
    SMK.SearchBar:ClosePanel()
    SMK.ModalManager:PrepareToShow(SMK.RouteDialog)
    SMK.RouteDialog:OpenSaved(saved)
    return true
end

function App:ActivateSavedRoute(route)
    local saved = SMK.RouteStore:GetByID(route and route.id)
    if not saved then
        SMK:Print(SMK.L.ROUTE_NOT_FOUND)
        return false
    end
    local activated, reason = SMK.Route:ActivateSavedRoute(saved)
    if not activated then
        if reason == "ACTIVATE_FAILED" then return false end
        SMK:Print(reason == "ROUTE_ALREADY_ACTIVE"
            and SMK.L.ROUTE_ALREADY_ACTIVE or SMK.L.ROUTE_INVALID)
        return false
    end
    SMK:Print(string.format(SMK.L.ROUTE_ACTIVATED, saved.name))
    SMK.SearchBar:ClosePanel()
    return true
end

function App:SaveRoute(name, items)
    local saved, reason = SMK.RouteStore:Add({ name = name, items = items })
    if not saved then
        local message = reason == "READ_ONLY" and SMK.DB:GetReadOnlyMessage()
            or reason == "DUPLICATE_ROUTE_NAME" and SMK.L.ROUTE_DUPLICATE_NAME
            or SMK.L.ROUTE_INVALID
        SMK:Print(message)
        return nil, message
    end
    SMK:Print(string.format(SMK.L.ROUTE_SAVED, saved.name))
    return saved
end

function App:ShareSavedRoute(route)
    local saved = SMK.RouteStore:GetByID(route and route.id)
    local text = saved and SMK.RouteCodec:Encode(saved)
    if not text then return SMK:Print(SMK.L.ROUTE_NOT_FOUND) end
    SMK.ModalManager:PrepareToShow(SMK.CopyDialog)
    SMK.CopyDialog:Open(SMK.L.SHARE_ROUTE_TITLE, text)
end

function App:DeleteSavedRoute(route)
    local deleted, reason = SMK.RouteStore:Delete(route)
    if deleted == 0 then
        SMK:Print(reason == "READ_ONLY" and SMK.DB:GetReadOnlyMessage()
            or SMK.L.ROUTE_NOT_FOUND)
        return false
    end
    SMK.Route:SavedRouteDeleted(route)
    if SMK.RouteDialog:IsOpenRoute(route) then SMK.RouteDialog:Hide() end
    SMK:Print(string.format(SMK.L.ROUTE_DELETED, route.name))
    return true
end

function App:ImportRouteText(text)
    local route, errorMessage = SMK.RouteCodec:Decode(text)
    if not route then return nil, errorMessage end
    local saved, reason = SMK.RouteStore:Add(route)
    if not saved then
        return nil, reason == "READ_ONLY" and SMK.DB:GetReadOnlyMessage()
            or reason == "DUPLICATE_ROUTE_NAME" and SMK.L.ROUTE_DUPLICATE_NAME
            or SMK.L.ROUTE_INVALID
    end
    SMK:Print(string.format(SMK.L.ROUTE_IMPORTED, saved.name))
    return saved
end

function App:OpenLocationContext(entry, owner, fromSearchResult)
    SMK.LocationContextMenu:Open(entry, owner, fromSearchResult)
end

function App:ActivateRoute(entry)
    return self:Activate(entry, false, true)
end

--- 从编辑器保存或更新地点。
-- 成功时清除临时地图路径点。
-- @param mode string "add" 或 "edit"。
-- @param entry table|nil 原始条目（编辑模式）。
-- @param values table 编辑器表单值。
-- @return boolean|nil, string|nil 成功标志或错误消息。
function App:SaveLocation(mode, entry, values)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage then return false, readOnlyMessage end
    if mode == "edit" then
        local updated, errorMessage = SMK.Store:Update(entry, values)
        if not updated then
            if errorMessage == "NOT_FOUND" then errorMessage = SMK.L.EDIT_NOT_FOUND end
            return false, GetStoreErrorMessage(errorMessage) or SMK.L.SAVE_FAILED
        end
        SMK:Print(string.format(SMK.L.EDIT_SUCCESS, values.name, values.x, values.y))
    else
        local added, errorMessage = SMK.Store:Add(values)
        if not added then
            return false, GetStoreErrorMessage(errorMessage) or SMK.L.SAVE_FAILED
        end
        SMK:Print(string.format(SMK.L.ADD_SUCCESS, values.name, values.x, values.y))
    end
    return true
end

--- 从编辑器或右键菜单删除单个地点。
-- 保留当前搜索词，删除后重新聚焦搜索框。
-- @param entry table
function App:DeleteLocation(entry)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage then
        SMK:Print(readOnlyMessage)
        return false
    end
    if type(entry) ~= "table" then
        SMK:Print(SMK.L.DELETE_INVALID)
        return false
    end
    GameTooltip_Hide()
    local query = SMK.SearchBar:GetQuery()
    local deleted = SMK.Store:Delete(entry)
    if deleted == 0 then
        SMK:Print(SMK.L.DELETE_UNKNOWN_SOURCE)
        return false
    end
    SMK:Print(string.format(SMK.L.DELETE_SUCCESS, entry.name, entry.x, entry.y))
    if query ~= "" then
        SMK.SearchBar:SetQuery(query)
        SMK.SearchBar:Focus()
    end
    return true
end

function App:FavoriteExternal(entry, categoryKey)
    local added, errorMessage = SMK.Store:AddExternal(entry, categoryKey)
    if not added then
        if errorMessage == "READ_ONLY" then
            errorMessage = SMK.DB:GetReadOnlyMessage()
        elseif errorMessage == "INVALID_LOCATION" then
            errorMessage = SMK.L.SAVE_FAILED
        end
        SMK:Print(errorMessage or SMK.L.SAVE_FAILED)
        return false
    end
    SMK:Print(string.format(SMK.L.ADD_SUCCESS, added.name, added.x, added.y))
    return true
end

--- 响应数据变更：重新加载上下文，清除缓存，更新界面。
function App:DataChanged()
    self:RequestRefresh("data")
end

function App:InitializeMinimapPins()
    local called, ready = pcall(SMK.MinimapPins.Initialize, SMK.MinimapPins)
    if called and ready then return true end
    if not self.warnedMinimapPins then
        self.warnedMinimapPins = true
        SMK:Print(SMK.L.ERROR_MINIMAP_PINS_UNAVAILABLE)
    end
    return false
end

--- 初始化整个界面：搜索栏、主面板、对话框和世界地图钩子。
-- 在 Blizzard_WorldMap 的 ADDON_LOADED 事件时调用一次（如果已加载则立即调用）。
function App:CreateUI()
    if self.initialized then return end
    SMK.DB:Initialize()
    SMK.SearchHistory:SetChangeHandler(function(kind)
        if kind == "result" then self:RequestRefresh("history") end
    end)
    SMK.Store:SetChangeHandler(function(reason) self:StoreChanged(reason) end)
    SMK.RouteStore:SetChangeHandler(function() self:RequestRefresh("search") end)
    SMK.Settings:SetChangeHandler(function(key) self:SettingChanged(key) end)
    SMK.HandyNotesProvider:SetChangeHandler(function(_, mapID)
        self:ExternalDataChanged(mapID)
    end)
    SMK.HandyNotesProvider:SetEnabled(
        SMK.Settings:Get("thirdPartySearchEnabled") == true)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage and not self.warnedReadOnlyDatabase then
        self.warnedReadOnlyDatabase = true
        SMK:Print(readOnlyMessage)
    end
    local initializedPins, pinsReady = pcall(SMK.MapPins.Initialize, SMK.MapPins, WorldMapFrame, {
        onEdit = function(entry, screenX, screenY)
            SMK.MainPanel:OpenEditor("edit", entry, { x = screenX, y = screenY })
        end,
        onContext = function(entry, owner)
            self:OpenLocationContext(entry, owner)
        end,
    })
    if not initializedPins or not pinsReady then
        SMK:Print(SMK.L.ERROR_MAP_PINS_UNAVAILABLE)
    end
    self:InitializeMinimapPins()
    local bar = SMK.SearchBar:Create({
        onShown = function() self:RequestRefresh("visible") end,
        onPlayerContextRequested = function() self:RefreshPlayerSearchContext() end,
        onActivate = function(entry, result) self:Activate(entry, result) end,
        onContext = function(entry, owner)
            self:OpenLocationContext(entry, owner, true)
        end,
    })
    SMK.MainPanel:Create(bar, {
        onActivate = function(entry, result) self:Activate(entry, result) end,
        onContext = function(entry, owner) self:OpenLocationContext(entry, owner) end,
        onDelete = function(entry) self:DeleteLocation(entry) end,
        onSaveLocation = function(mode, entry, values) return self:SaveLocation(mode, entry, values) end,
        onDialogOpened = function() SMK.SearchBar:PrepareForDialog() end,
        onClose = function() SMK.SearchBar:ClosePanel() end,
        onHidden = function() SMK.SearchBar:OnPanelHidden() end,
    })
    SMK.LocationContextMenu:Initialize({
        onFavorite = function(entry)
            self:FavoriteExternal(entry)
        end,
        onCopy = function(entry) self:CopyCoordinates(entry) end,
        onShare = function(entry) self:ShareCoordinate(entry) end,
        onOpenMap = function(entry) self:OpenLocationOnMap(entry) end,
        onEdit = function(entry) SMK.MainPanel:OpenEditor("edit", entry) end,
        onDelete = function(entry) self:DeleteLocation(entry) end,
        onRoute = function(entry) self:AddToRoute(entry) end,
        onTemporaryPin = function(entry) SMK.RouteDialog:AddTemporaryPin(entry) end,
        onOpenRoute = function(route) self:OpenSavedRoute(route) end,
        onActivateRoute = function(route) self:ActivateSavedRoute(route) end,
        isRouteActive = function(route) return SMK.Route:IsSavedRouteActive(route) end,
        onShareRoute = function(route) self:ShareSavedRoute(route) end,
        onDeleteRoute = function(route) self:DeleteSavedRoute(route) end,
    })
    SMK.Route:SetChangeHandler(function()
        if SMK.RouteDialog:IsShown() then SMK.RouteDialog:Refresh() end
    end)
    SMK.Route:SetActivateHandler(function(entry) return self:ActivateRoute(entry) end)
    SMK.SearchBar:AttachPanel(SMK.MainPanel)
    self.initialized = true
    self:RequestRefresh("initialize")
    SMK.WorldMapController:Initialize({
        onShown = function(mapID)
            SMK.SearchBar:ShowForMap()
            self:RequestMapRefresh(mapID, false)
            self:ShowPendingLocationHighlight(mapID)
        end,
        onHidden = function(mapID)
            SMK.SearchBar:HandleWorldMapHidden()
            self:RequestMapRefresh(mapID, false)
        end,
        onMapChanged = function(mapID, forceExternal)
            self:RequestMapRefresh(mapID, forceExternal)
            self:ShowPendingLocationHighlight(mapID)
        end,
        onMapIndexReady = function()
            self:RequestRefresh("search")
        end,
        onReady = function() SMK.SearchBar:RestoreVisibility() end,
        onAltClick = function(mapID, x, y, screenX, screenY)
            local marked, message = SMK.Map:BeginTemporaryWaypoint({ mapID = mapID, x = x, y = y })
            if not marked then
                if message then SMK:Print(message) end
                return
            end
            SMK.MainPanel:OpenEditor("add", { mapID = mapID, x = x, y = y }, { x = screenX, y = screenY })
        end,
    })
end

--- 切换浮动搜索栏的显示（由快捷键触发）。
-- 如果插件尚未初始化，按需加载 Blizzard_WorldMap。
function App:ToggleSearch()
    if not self.initialized then
        local loaded, reason = C_AddOns.LoadAddOn("Blizzard_WorldMap")
        if not loaded and not C_AddOns.IsAddOnLoaded("Blizzard_WorldMap") then
            return SMK:Print(string.format(SMK.L.LOAD_WORLD_MAP_FAILED, tostring(reason or SMK.L.UNKNOWN_REASON)))
        end
    end
    if self.initialized then
        SMK.SearchBar:ToggleShortcut()
    else
        C_Timer.After(0, function()
            if self.initialized then SMK.SearchBar:ToggleShortcut() end
        end)
    end
end


SMK.App = App

function SearchMaker_ToggleSearch()
    App:ToggleSearch()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
for event in pairs(SMK.WhisperInbox.events) do loader:RegisterEvent(event) end
local loadedSearchMaker = false
loader:SetScript("OnEvent", function(self, event, firstArgument)
    if SMK.WhisperInbox.events[event] then
        SMK.WhisperInbox:Capture(firstArgument)
        return
    end
    local addonName = firstArgument
    if addonName == SMK.name then
        loadedSearchMaker = true
        SMK.DB:Initialize()
        App:InitializeMinimapPins()
        if App.initialized then
            SMK.Store:InvalidateCache()
            SMK.RouteStore:InvalidateCache()
            SMK.HandyNotesProvider:SetEnabled(
                SMK.Settings:Get("thirdPartySearchEnabled") == true)
            SMK.SearchBar:ApplyStyle()
            SMK.SearchBar:ApplyScale()
            SMK.SearchBar:ApplyOpacity()
            SMK.SearchBar:UpdateSearchIcon()
            SMK.SearchBar:RestoreVisibility()
            App:DataChanged()
        end
    elseif addonName == "Blizzard_WorldMap" then
        App:CreateUI()
    end
    if loadedSearchMaker and App.initialized then
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

if C_AddOns.IsAddOnLoaded("Blizzard_WorldMap") then
    App:CreateUI()
end
