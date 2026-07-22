local _, SMK = ...

BINDING_HEADER_SEARCHMAKER = SMK.L.BINDING_HEADER
BINDING_NAME_SEARCHMAKER_TOGGLE_SEARCH = SMK.L.BINDING_NAME

local App = {}

local RefreshProfiles = {
    initialize = { context = true, panel = true, instructions = true },
    visible = { context = true, instructions = true },
    map = { context = true, panel = true, instructions = true, resetSearch = true },
    data = {
        context = true, panel = true, pins = true, instructions = true,
        search = true, geometry = true,
    },
    search = { search = true },
    scale = { panel = true, search = true },
    pins = { pins = true },
    scope = { searchIcon = true, instructions = true, search = true },
    usage = { panel = true },
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
    if flags.geometry then SMK.Widgets:ClearGeometryCache() end
    if flags.context then self:LoadContext() end
    if flags.pins then SMK.MapPins:Refresh() end
    if not self.initialized then return end

    if flags.panel and SMK.MainPanel:IsExpanded() then SMK.MainPanel:Refresh() end
    if flags.searchIcon then SMK.SearchBar:UpdateSearchIcon() end
    if not SMK.SearchBar:IsVisible() then return end
    if flags.resetSearch then
        SMK.SearchBar:RefreshContext()
    else
        if flags.instructions then SMK.SearchBar:UpdateInstructions() end
        if flags.search then SMK.SearchBar:RefreshResultsIfVisible() end
    end
end

function App:StoreChanged(reason)
    self:RequestRefresh(reason == "usage" and "usage" or "data")
end

function App:SettingChanged(key)
    if key == "locationScale" then
        self:RequestRefresh("scale")
    elseif key == "showMapPins" then
        self:RequestRefresh("pins")
    elseif key == "showMapPinNames" or key == "mapPinTextColor"
        or key == "mapPinTextScale" then
        self:RequestRefresh("pins")
    elseif key == "searchAllMaps" then
        self:RequestRefresh("scope")
    end
end

--- 刷新当前地图上下文：更新 currentMapID、currentEntries 和总数。
-- 在地图切换、数据变更和启动时调用。
function App:LoadContext()
    local mapID = SMK.Map:GetContextMapID()
    local current = SMK.Store:GetByMap(mapID)
    local total = #SMK.Store:GetAll()
    SMK.State.currentMapID = mapID
    SMK.State.currentEntries = current
    SMK.State.totalLocationCount = total
end

--- 激活地点：为用户条目设置路径点，或为地图传送门跳转到目标地图。
-- 如果来自搜索结果且为全图搜索模式，先打开目标地图再设路径点。
-- @param entry table 地点条目或地图传送门条目。
-- @param fromSearchResult boolean 是否来自搜索结果下拉框。
function App:Activate(entry, fromSearchResult)
    if entry.isMapPortal then
        if SMK.Map:OpenMap(entry.mapID) then
            -- 播放传送门音效
            PlaySound(875)
            SMK.SearchBar:ClosePanel()
            if SMK.SearchBar:IsVisible() then SMK.SearchBar:Focus() end
        end
        return
    end
    if fromSearchResult and SMK.Settings:Get("searchAllMaps")
        and SMK.SearchBar:IsMapMode()
        and WorldMapFrame:IsShown() then
        SMK.Map:OpenMap(entry.mapID)
    end
    local marked, message = SMK.Map:SetWaypoint(entry)
    GameTooltip_Hide()
    if marked then
        PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON)
        SMK.Store:RecordUsage(entry)
    else
        PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_BUTTON_CLICK_OFF)
        if message then SMK:Print(message) end
    end
    SMK.SearchBar:ClosePanel()
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
        if not SMK.Store:Update(entry, values) then
            return false, SMK.L.EDIT_NOT_FOUND
        end
        SMK:Print(string.format(SMK.L.EDIT_SUCCESS, values.name, values.x, values.y))
    else
        local added = SMK.Store:Add(values)
        if not added then return false, SMK.L.SAVE_FAILED end
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

--- 响应数据变更：重新加载上下文，清除缓存，更新界面。
function App:DataChanged()
    self:RequestRefresh("data")
end

--- 初始化整个界面：搜索栏、主面板、对话框和世界地图钩子。
-- 在 Blizzard_WorldMap 的 ADDON_LOADED 事件时调用一次（如果已加载则立即调用）。
function App:CreateUI()
    if self.initialized then return end
    SMK.DB:Initialize()
    SMK.Store:SetChangeHandler(function(reason) self:StoreChanged(reason) end)
    SMK.Settings:SetChangeHandler(function(key) self:SettingChanged(key) end)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage and not self.warnedReadOnlyDatabase then
        self.warnedReadOnlyDatabase = true
        SMK:Print(readOnlyMessage)
    end
    local initializedPins, pinsReady = pcall(SMK.MapPins.Initialize, SMK.MapPins, WorldMapFrame, {
        onEdit = function(entry) SMK.MainPanel:OpenEditor("edit", entry) end,
    })
    if not initializedPins or not pinsReady then
        SMK:Print(SMK.L.ERROR_MAP_PINS_UNAVAILABLE)
    end
    local bar = SMK.SearchBar:Create({
        onShown = function() self:RequestRefresh("visible") end,
        onActivate = function(entry, result) self:Activate(entry, result) end,
        onEdit = function(entry) SMK.MainPanel:OpenEditor("edit", entry) end,
        onDelete = function(entry) self:DeleteLocation(entry) end,
    })
    SMK.MainPanel:Create(bar, {
        onActivate = function(entry, result) self:Activate(entry, result) end,
        onDelete = function(entry) self:DeleteLocation(entry) end,
        onSaveLocation = function(mode, entry, values) return self:SaveLocation(mode, entry, values) end,
        onDialogOpened = function() SMK.SearchBar:PrepareForDialog() end,
        onClose = function() SMK.SearchBar:ClosePanel() end,
        onHidden = function() SMK.SearchBar:OnPanelHidden() end,
    })
    SMK.SearchBar:AttachPanel(SMK.MainPanel)
    self.initialized = true
    self:RequestRefresh("initialize")
    SMK.WorldMapController:Initialize({
        onShown = function()
            SMK.SearchBar:ShowForMap()
            self:RequestRefresh("map")
        end,
        onHidden = function()
            SMK.SearchBar:HandleWorldMapHidden()
            self:RequestRefresh("map")
        end,
        onMapChanged = function() self:RequestRefresh("map") end,
        onReady = function() SMK.SearchBar:RestoreVisibility() end,
        onAltClick = function(mapID, x, y)
            local marked, message = SMK.Map:BeginTemporaryWaypoint({ mapID = mapID, x = x, y = y })
            if not marked then
                if message then SMK:Print(message) end
                return
            end
            SMK.MainPanel:OpenEditor("add", { mapID = mapID, x = x, y = y })
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


function App:ScanChatForImports()
    local collected = {}
    local invalidTotal = 0
    local sawTruncated = false
    local sawShareCode = false
    for i = 1, NUM_CHAT_WINDOWS or 7 do
        local cf = _G["ChatFrame" .. i]
        if cf then
            local num = cf:GetNumMessages()
            local start = math.max(1, num - 49)
            for j = start, num do
                -- cf:GetMessageInfo returns different formats across WoW versions:
                -- old: first return = string message; new: returns include a table with message data
                local allReturns = { cf:GetMessageInfo(j) }
                local sharePart
                for _, val in ipairs(allReturns) do
                    if type(val) == "string" then
                        sharePart = SMK.ShareCodec:FindShareText(val)
                        if sharePart then break end
                    elseif type(val) == "table" then
                        for _, field in ipairs(val) do
                            if type(field) == "string" then
                                sharePart = SMK.ShareCodec:FindShareText(field)
                                if sharePart then break end
                            end
                        end
                        if sharePart then break end
                    end
                end
                if sharePart then
                    sawShareCode = true
                    local entries, _, invalid = SMK.ShareCodec:Decode(sharePart)
                    if entries then
                        invalidTotal = invalidTotal + (invalid or 0)
                        if invalid and invalid > 0 then sawTruncated = true end
                        for _, entry in ipairs(entries) do collected[#collected + 1] = entry end
                    else
                        invalidTotal = invalidTotal + 1
                        sawTruncated = true
                    end
                end
            end
        end
    end
    if not sawShareCode then
        SMK:Print(SMK.L.CHAT_IMPORT_NONE)
        return SMK.L.CHAT_IMPORT_NONE
    end
    local result, importError = SMK.Import:ImportEntries(collected, invalidTotal)
    if not result then
        SMK:Print(importError)
        return importError
    end
    local truncMsg = sawTruncated and " " .. SMK.L.CHAT_IMPORT_TRUNCATED or ""
    local msg
    if result.imported > 0 then
        msg = string.format(SMK.L.CHAT_IMPORT_SUCCESS, result.imported) .. truncMsg
    else
        msg = SMK.L.CHAT_IMPORT_ALL_DUPLICATES .. truncMsg
    end
    SMK:Print(msg)
    return msg
end

SMK.App = App

function SearchMaker_ToggleSearch()
    App:ToggleSearch()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
local loadedSearchMaker = false
loader:SetScript("OnEvent", function(self, _, addonName)
    if addonName == SMK.name then
        loadedSearchMaker = true
        SMK.DB:Initialize()
        if App.initialized then
            SMK.Store:InvalidateCache()
            SMK.SearchBar:UpdateSearchIcon()
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
