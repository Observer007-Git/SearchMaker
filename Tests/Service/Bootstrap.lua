return function(root)
    local context = {
        root = assert(root, "missing addon root"),
        activeLocale = "zhCN",
        waypoint = nil,
        superTracked = false,
        mapChildren = {},
        mapInfo = {},
        playerMapID = nil,
    }

    function GetLocale() return context.activeLocale end
    function strlenutf8(text)
        local _, count = tostring(text):gsub("[^\128-\193]", "")
        return count
    end
    function DoesAncestryIncludeAny(frame, foci)
        for _, focus in ipairs(foci or {}) do
            if focus == frame then return true end
        end
        return false
    end

    C_AddOns = {
        GetAddOnMetadata = function(_, key)
            return key == "Version" and "test" or nil
        end,
    }
    DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    Enum = {
        UIMapType = {
            Cosmic = 0,
            Phase = 6,
            AzeriteMap = 7,
            Orphan = 8,
            Zone = 3,
        },
    }
    C_Map = {
        GetMapInfo = function(mapID) return context.mapInfo[mapID] end,
        GetMapChildrenInfo = function(mapID)
            return context.mapChildren[mapID] or {}
        end,
        GetBestMapForUnit = function() return context.playerMapID end,
        CanSetUserWaypointOnMap = function() return true end,
        SetUserWaypoint = function(point) context.waypoint = point end,
        GetUserWaypoint = function() return context.waypoint end,
        ClearUserWaypoint = function() context.waypoint = nil end,
    }
    C_SuperTrack = {
        SetSuperTrackedUserWaypoint = function(value)
            context.superTracked = value
        end,
        IsSuperTrackingUserWaypoint = function()
            return context.superTracked
        end,
    }
    UiMapPoint = {
        CreateFromCoordinates = function(mapID, x, y)
            return { uiMapID = mapID, position = { x = x, y = y } }
        end,
    }

    local function LoadModule(namespace, path)
        local chunk = assert(loadfile(context.root .. "/" .. path))
        return chunk("SearchMaker", namespace)
    end

    local SMK = {}
    for _, path in ipairs({
        "Core/Namespace.lua", "Core/AtlasTextures.lua",
        "Core/PathTextures.lua", "Core/IconCatalog.lua",
        "Core/PinTextures.lua", "Config.lua", "Locales/init.lua",
        "Locales/enUS.lua", "Locales/zhCN.lua", "Core/LocationModel.lua",
        "Core/RouteStore.lua", "Core/SettingsSchema.lua",
        "Core/Database.lua", "Core/SettingsService.lua",
        "Core/LocationStore.lua", "Core/RouteService.lua",
        "Core/RouteCodec.lua", "Core/MapService.lua",
        "Core/SearchService.lua", "Core/MapIndex.lua",
        "Core/ShareCodec.lua", "Core/WhisperInbox.lua",
        "Core/HandyNotesProvider.lua", "Core/MapContextService.lua",
        "Core/ImportService.lua", "Core/MapPinPoolAdapter.lua",
        "Core/MapPinProvider.lua", "Core/RefreshCoordinator.lua",
        "UI/ShareDialog.lua", "UI/ModalManager.lua",
        "UI/BulkDeleteDialog.lua", "UI/PanelController.lua",
        "UI/HelpDialog.lua", "UI/Widgets.lua", "UI/IconGridPicker.lua",
        "UI/CopyDialog.lua", "UI/LocationContextMenu.lua",
        "UI/RouteImportDialog.lua", "UI/RouteDialog.lua",
        "UI/ImportPreviewDialog.lua", "UI/LocationEditor.lua",
        "UI/SearchResults.lua", "UI/SearchBar.lua", "UI/MainPanel.lua",
    }) do
        LoadModule(SMK, path)
    end

    context.SMK = SMK
    context.loadModule = LoadModule
    return context
end
