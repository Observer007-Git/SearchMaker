local root = assert(arg[1], "usage: lua Tests/ServiceTest.lua <addon-root>")

local activeLocale = "zhCN"
function GetLocale() return activeLocale end
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

C_AddOns = { GetAddOnMetadata = function(_, key) return key == "Version" and "test" or nil end }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
Enum = { UIMapType = { Cosmic = 0, Phase = 6, AzeriteMap = 7, Orphan = 8, Zone = 3 } }

local waypoint
local superTracked = false
local mapChildren = {}
local mapInfo = {}
local playerMapID
C_Map = {
    GetMapInfo = function(mapID) return mapInfo[mapID] end,
    GetMapChildrenInfo = function(mapID) return mapChildren[mapID] or {} end,
    GetBestMapForUnit = function() return playerMapID end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(point) waypoint = point end,
    GetUserWaypoint = function() return waypoint end,
    ClearUserWaypoint = function() waypoint = nil end,
}
C_SuperTrack = {
    SetSuperTrackedUserWaypoint = function(value) superTracked = value end,
    IsSuperTrackingUserWaypoint = function() return superTracked end,
}
UiMapPoint = {
    CreateFromCoordinates = function(mapID, x, y)
        return { uiMapID = mapID, position = { x = x, y = y } }
    end,
}

local function loadModule(namespace, path)
    local chunk = assert(loadfile(root .. "/" .. path))
    return chunk("SearchMaker", namespace)
end

local SMK = {}
for _, path in ipairs({
    "Core/Namespace.lua", "Config.lua", "Locales/init.lua", "Locales/enUS.lua", "Locales/zhCN.lua",
    "Core/PinTextures.lua", "Core/LocationModel.lua", "Core/SettingsSchema.lua",
    "Core/Database.lua", "Core/SettingsService.lua",
    "Core/LocationStore.lua", "Core/MapService.lua",
    "Core/SearchService.lua", "Core/MapIndex.lua", "Core/ShareCodec.lua", "Core/HandyNotesProvider.lua",
    "Core/MapContextService.lua", "Core/ImportService.lua",
    "Core/MapPinPoolAdapter.lua", "Core/MapPinProvider.lua",
    "Core/RefreshCoordinator.lua", "UI/ShareDialog.lua", "UI/ModalManager.lua", "UI/BulkDeleteDialog.lua",
    "UI/PanelController.lua", "UI/HelpDialog.lua",
    "UI/Widgets.lua", "UI/SearchResults.lua", "UI/SearchBar.lua",
}) do
    loadModule(SMK, path)
end

assert(#SMK.PinTextures == 20, "pin texture atlas list is incomplete")
local panelLayout = SMK.Config.GetPanelLayout()
local panelConfig = SMK.Config.panel.layout
local panelControls = SMK.Config.panel.controls
local columnsWidth = SMK.Config.location.baseWidth * panelConfig.targetColumns
    + SMK.Config.location.horizontalGap * (panelConfig.targetColumns - 1)
assert(panelConfig.targetColumns == 5 and SMK.Config.panel.width == panelLayout.panelWidth
    and panelLayout.sidePadding + columnsWidth <= panelLayout.contentWidth - panelLayout.sidePadding
    and math.abs(panelLayout.sidePadding
        - (panelLayout.contentWidth - panelLayout.sidePadding - columnsWidth)) <= 1,
    "main panel five-column margins are not symmetric")
local firstColumnLeft = panelLayout.scrollLeftInset + panelLayout.sidePadding
local fifthColumnRight = panelLayout.panelWidth
    - (panelLayout.scrollLeftInset + panelLayout.sidePadding + columnsWidth)
assert(math.abs(firstColumnLeft - fifthColumnRight) <= 1
    and panelLayout.panelWidth - panelLayout.scrollLeftInset - panelLayout.scrollRightInset
        == panelLayout.contentWidth + panelConfig.scrollChildInset,
    "main panel scrollbar reserve is not split symmetrically")
assert(panelConfig.scrollbarReserve == 48 and panelLayout.scrollRightInset == 29,
    "main panel scrollbar is not inset from the border")
assert(panelConfig.headerHeight == 40 and panelConfig.contentTopGap == 8
    and panelControls.buttonAtlas == "housefinder_neighborhood-list-item-highlight"
    and panelControls.buttonHeight == 24 and panelControls.settingsWidth == 330,
    "main panel controls are not configured")
assert(SMK.Config.searchResultBackdrop.insets.left == 1
    and SMK.Config.searchResultBackdrop.insets.right == 1
    and SMK.Config.searchResultBackdrop.insets.top == 1
    and SMK.Config.searchResultBackdrop.insets.bottom == 1,
    "search result background does not fit its rounded border")
assert(SMK.Config.art.searchIcon == "Interface\\ICONS\\VAS_NameChange"
    and SMK.Config.art.searchAllMapsIcon == "Interface\\ICONS\\Ability_Paladin_SavedByTheLight"
    and SMK.Config.art.searchResultIconFrame == "Interface\\SPELLBOOK\\RotationIconFrame"
    and SMK.Config.art.searchResultIconFrameExpand == 4,
    "search scope icon art is not configured")
assert(SMK.Config.search.resultFrameInset == 5
    and SMK.Config.search.resultGap == 2
    and SMK.Config.search.resultMaxContentWidth == 520
    and SMK.Config.search.resultScreenMargin == 12
    and SMK.Config.search.hoverHighlightDelay == 0.08
    and SMK.Config.search.boxWidth - SMK.Config.search.resultFrameInset * 2 == 230,
    "search result frame is not aligned inside the search box border")
assert(SMK.Config.mapPins.targetHighlight.atlas == "MonsterEnemy"
    and SMK.Config.mapPins.targetHighlight.ringTexture == "Interface\\Cooldown\\starburst"
    and SMK.Config.mapPins.targetHighlight.size == 32
    and SMK.Config.mapPins.targetHighlight.ringSize == 80
    and SMK.Config.mapPins.targetHighlight.duration == 3,
    "target highlight is not configured")
local locationSign = SMK.Config.art.locationSign
assert(locationSign.atlas == "housing-woodsign" and locationSign.width == 136
    and locationSign.height == 29 and locationSign.textPadding == 8
    and locationSign.textOffsetY == 1 and SMK.Config.location.baseWidth == 136
    and SMK.Config.location.horizontalGap == 4,
    "location sign art is not configured")
assert(SMK.DefaultPinTextureID == 1 and SMK.PinTextures[1].atlas == "MonsterEnemy",
    "MonsterEnemy is not the first and default pin texture")
local expectedPinAtlases = {
    "MonsterEnemy", "Ping_Map_Whole_OnMyWay", "Ping_Map_Whole_Warning", "Ping_Map_Whole_Assist",
    "VignetteEvent-SuperTracked", "ElementalStorm-Lesser-Fire", "MonsterFriend", "PlayerPartyBlip",
    "vignettekillboss-SuperTracked", "poi-traveldirections-arrow2", "poi-door-up", "poi-door-down",
    "poi-door-left", "poi-door-right", "CrossedFlags", "Professions_Tracking_Fish_Special",
    "Map-MarkedDefeated", "ElementalStorm-Boss-Fire", "XMarksTheSpot", "MiniMap-DeadArrow",
}
for id, atlas in ipairs(expectedPinAtlases) do
    assert(SMK.PinTextureByID[id].atlas == atlas, "new pin texture atlas IDs are unstable")
    assert(atlas ~= "Ping_Map_Whole_Danger" and atlas ~= "Ping_Map_Whole_Help",
        "removed pin textures are still available")
end
local defaultTextureEntry = assert(SMK.LocationModel:Normalize({
    mapID = 100, x = 1, y = 2, name = "default", categoryKey = "other", pinTextureID = 999,
}))
assert(defaultTextureEntry.pinTextureID == SMK.DefaultPinTextureID,
    "location normalization did not use the default pin texture")
local function NormalizeNamedLocation(name)
    return SMK.LocationModel:Normalize({
        mapID = 100, x = 1, y = 2, name = name, categoryKey = "other",
    })
end
assert(NormalizeNamedLocation("一二三四五六七八九十"), "ten-character Chinese name was rejected")
assert(not NormalizeNamedLocation("一二三四五六七八九十一"), "eleven-character Chinese name was accepted")
assert(NormalizeNamedLocation("abcdefghijklmnopqrst"), "twenty-letter English name was rejected")
assert(not NormalizeNamedLocation("abcdefghijklmnopqrstu"), "twenty-one-letter English name was accepted")

local popupHiddenID, dialogHidden
local popup = { IsShown = function() return true end }
SMK.BulkDeleteDialog.popup = popup
SMK.BulkDeleteDialog.frame = {
    IsShown = function() return false end,
    Hide = function() dialogHidden = true end,
}
SMK.ModalManager:Register(SMK.BulkDeleteDialog)
assert(SMK.ModalManager:ContainsMouseFocus({ popup }),
    "bulk delete confirmation was not treated as modal content")
SMK.BulkDeleteDialog.dropdown = { IsMenuOpen = function() return true end }
assert(SMK.ModalManager:IsMenuOpen(),
    "modal manager did not query the dialog's menu state interface")
SMK.BulkDeleteDialog.dropdown = nil
StaticPopup_Hide = function(id) popupHiddenID = id end
SMK.BulkDeleteDialog:Hide()
assert(popupHiddenID == "SEARCHMAKER_BULK_DELETE" and dialogHidden
    and SMK.BulkDeleteDialog.popup == nil,
    "bulk delete confirmation was not closed with its dialog")

local scheduledRefresh
local refreshCount, refreshFlags = 0
local coordinator = SMK.RefreshCoordinator:New(function(flags)
    refreshCount = refreshCount + 1
    refreshFlags = flags
end, function(callback)
    assert(not scheduledRefresh, "refresh scheduled more than once")
    scheduledRefresh = callback
end)
coordinator:Request({ context = true })
coordinator:Request({ pins = true })
assert(refreshCount == 0 and scheduledRefresh, "refresh was not deferred")
scheduledRefresh()
assert(refreshCount == 1 and refreshFlags.context and refreshFlags.pins,
    "refresh requests were not merged")

local futureDatabase = {
    schemaVersion = SMK.Config.databaseSchemaVersion + 5,
    locations = { { id = "future:1", mapID = 100, x = 1, y = 2, name = "future", categoryKey = "other" } },
    usageCounts = {},
    futureField = { preserved = true },
}
SearchMakerDB = futureDatabase
SMK.DB:Initialize()
assert(SMK.DB:IsReadOnly() and SMK.DB:GetFutureSchemaVersion() == futureDatabase.schemaVersion,
    "future database schema was not opened read-only")
assert(SMK.DB:GetReadOnlyMessage() == string.format(SMK.L.DATABASE_READ_ONLY,
    futureDatabase.schemaVersion, SMK.Config.databaseSchemaVersion),
    "future database read-only message is missing")
assert(not futureDatabase.locationScale and futureDatabase.futureField.preserved,
    "future database was modified during initialization")
assert(not SMK.Settings:Set("showPinTextures", true), "future database setting write was accepted")
assert(futureDatabase.settings == nil, "future database settings were written through runtime data")
assert(not SMK.Store:Add({ mapID = 100, x = 1, y = 2, name = "blocked", categoryKey = "other" }),
    "future database accepted a write")

SearchMakerDB = {
    schemaVersion = SMK.Config.databaseSchemaVersion,
    settings = {
        showPinTextures = true,
        showFullPanel = false,
        locationScale = 1.2,
        searchBarScale = 1.4,
        searchBarOpacity = 0.6,
        exportBatchSize = 75,
        pinTextureScale = 9,
        mapPinNameOffsetX = -80,
        mapPinNameOffsetY = 80,
    },
    locations = {
        { id = "user:4", mapID = "100", x = "12.34", y = "56.78", name = "旧地点", categoryKey = "delves", showPin = true, pinTextureID = "5", futureExtension = "keep" },
        { id = "user:4", mapID = 100, x = 20, y = 30, name = "重复ID", categoryKey = "npc" },
        { id = "invalid", mapID = 0, x = 1, y = 2, name = "损坏地点", categoryKey = "other" },
    },
    usageCounts = { ["id:user:4"] = 2, ["id:missing"] = 9 },
}
SMK.DB:Initialize()
assert(SearchMakerDB.schemaVersion == SMK.Config.databaseSchemaVersion, "database schema was not initialized")
assert(SearchMakerDB.locations[1].categoryKey == "delves", "category normalization failed")
assert(SearchMakerDB.locations[1].pinTextureID == 5, "pin texture normalization failed")
assert(SearchMakerDB.locations[2].id ~= "user:4", "duplicate ID was not repaired")
assert(#SearchMakerDB.locations == 2 and SearchMakerDB.usageCounts["id:missing"] == nil
    and SearchMakerDB.usageCounts["id:user:4"] == 2,
    "invalid locations or orphan usage counts were not pruned")
assert(SMK.Settings:Get("showPinTextures") and SMK.Settings:Get("locationScale") == 1.2,
    "nested settings were not initialized")
assert(SMK.Settings:Get("searchBarScale") == 1.4
    and SMK.Settings:Get("searchBarOpacity") == 0.6,
    "search bar appearance settings were not persisted")
assert(SMK.Settings:Get("exportBatchSize") == SMK.Config.export.defaultBatchSize,
    "export batch size default was not initialized")
assert(SMK.Settings:Get("pinTextureScale") == SMK.Config.mapPins.maxTextureScale
    and SMK.Settings:Get("mapPinNameOffsetX") == SMK.Config.mapPins.nameOffsetXMin
    and SMK.Settings:Get("mapPinNameOffsetY") == SMK.Config.mapPins.nameOffsetYMax,
    "map pin appearance settings were not clamped")
assert(SearchMakerDB.locations[1].showPinName == 1
    and SearchMakerDB.locations[1].showPinTexture == 1,
    "legacy map pin visibility was not split into name and texture flags")
assert(SearchMakerDB.settings.showFullPanel == nil, "removed panel setting was retained")
assert(SMK.Settings:Get("showMapPinNames") == false, "pin name setting default was not initialized")
local defaultTextColor = SMK.Settings:Get("mapPinTextColor")
assert(defaultTextColor.r == 1 and defaultTextColor.g == 0.82 and defaultTextColor.b == 0
    and SMK.Settings:Get("mapPinTextScale") == 1,
    "pin text appearance defaults were not initialized")
assert(SearchMakerDB.locationScale == nil and SearchMakerDB.showPinTextures == nil,
    "obsolete root settings were not removed")
local changedSetting
SMK.Settings:SetChangeHandler(function(key) changedSetting = key end)
assert(SMK.Settings:Set("locationScale", 1.3) and changedSetting == "locationScale",
    "setting change was not normalized and announced")
assert(SMK.Settings:Set("showMapPinNames", true) and changedSetting == "showMapPinNames",
    "pin name setting was not persisted and announced")
assert(SMK.Settings:Set("mapPinTextColor", { r = 0.2, g = 0.4, b = 0.6 })
    and changedSetting == "mapPinTextColor",
    "pin text color was not persisted and announced")
assert(SMK.Settings:Set("mapPinTextScale", 1.4) and changedSetting == "mapPinTextScale",
    "pin text scale was not persisted and announced")
assert(SMK.Settings:Set("shortcutSearchBarPosition", { x = 10, y = 20 })
    and SMK.Settings:Set("shortcutSearchBarPosition", { x = 30, y = 40 })
    and SMK.Settings:Get("shortcutSearchBarPosition").x == 30,
    "color comparison interfered with position settings")
assert(not SMK.Settings:Set("showMapPinNames", 1)
    and SMK.Settings:Get("showMapPinNames") == true,
    "runtime settings bypassed the shared settings schema")

local first = SMK.Store:GetAll()[1]
assert(first.categoryKey == "delves" and first.categoryLabel == "地下堡", "display projection is not localized")
assert(SMK.Store:Update(first, {
    mapID = first.mapID, x = first.x, y = first.y, name = first.name,
    categoryKey = first.categoryKey, showPin = first.showPin, pinTextureID = first.pinTextureID,
}), "location update failed")
assert(SearchMakerDB.locations[1].categoryKey == "delves", "editing changed the canonical category")
assert(SearchMakerDB.locations[1].futureExtension == "keep", "editing discarded an unknown extension field")
local sameNameDifferentPosition = {
    mapID = first.mapID, x = first.x + 1, y = first.y, name = first.name,
    categoryKey = first.categoryKey,
}
assert(not SMK.Store:FindDuplicate(sameNameDifferentPosition),
    "duplicate detection ignored coordinates")
assert(SMK.Store:FindDuplicate(first), "duplicate detection missed the same location")

local externalFavorite = {
    isExternal = true,
    externalSource = "HandyNotes_MapNotes",
    mapID = 100,
    x = 42.25,
    y = 63.5,
    name = "绷带训练师",
}
local favorite = assert(SMK.Store:AddExternal(externalFavorite, "professions"))
assert(favorite.source == "saved" and favorite.categoryKey == "professions"
    and favorite.showPinName == 0 and favorite.showPinTexture == 0,
    "external favorite was not saved to its selected category")
local duplicateFavorite, duplicateFavoriteError = SMK.Store:AddExternal(externalFavorite)
assert(not duplicateFavorite
    and duplicateFavoriteError == string.format(SMK.L.DUPLICATE_NAME, externalFavorite.name),
    "duplicate external favorite was accepted")
assert(SMK.Store:Delete(favorite) == 1, "external favorite could not be deleted")
local deleteA = assert(SMK.Store:Add({
    mapID = 200, x = 10, y = 10, name = "批量甲", categoryKey = "other",
}))
local keepB = assert(SMK.Store:Add({
    mapID = 200, x = 20, y = 20, name = "保留乙", categoryKey = "other",
}))
local deleteC = assert(SMK.Store:Add({
    mapID = 200, x = 30, y = 30, name = "批量丙", categoryKey = "other",
}))
local locationsBeforeDelete = SearchMakerDB.locations
assert(SMK.Store:DeleteMany({ deleteA, deleteC }) == 2
    and SearchMakerDB.locations ~= locationsBeforeDelete
    and #SMK.Store:GetByMap(200) == 1
    and SMK.Store:GetByMap(200)[1].id == keepB.id,
    "bulk delete did not rebuild the retained location array in one pass")

local storeChangeReason
SMK.Store:SetChangeHandler(function(reason) storeChangeReason = reason end)
for index = 1, 25 do
    assert(SMK.Store:Add({ mapID = 100, x = index, y = index, name = "精确甲" .. index, categoryKey = "other" }))
end
assert(storeChangeReason == "locations", "store mutation did not announce a data change")
SMK.Store:SetChangeHandler(nil)
assert(SMK.Store:Add({ mapID = 100, x = 90, y = 90, name = "精确", categoryKey = "other" }))
local matches = SMK.Search:Find(SMK.Store:GetAll(), "精确", true)
assert(#matches == SMK.Config.search.maxResults, "search result limit failed")
assert(matches[1].entry.name == "精确" and matches[1].score == 0, "late exact match was not ranked first")

for _, query in ipairs({
    "12 34", "12,34", "12，34", "12.3 34.56", "00.0, 99.99",
    "1 34", "5 10", "8.5 30", "3.14 59", "0 0", "12 100", "100 50",
}) do
    local coordinateMatches = SMK.Search:Find({}, query, false, 100)
    assert(#coordinateMatches == 1 and coordinateMatches[1].isCoordinateResult
        and coordinateMatches[1].entry.mapID == 100
        and coordinateMatches[1].entry.categoryKey == SMK.Config.defaultCategoryKey,
        "valid coordinate query was not recognized: " .. query)
end
for _, query in ipairs({ "123 45", "12. 34", "12.345 34", "-12 34", "0 -1", "101 50" }) do
    assert(#SMK.Search:Find({}, query, false, 100) == 0,
        "invalid coordinate query was accepted: " .. query)
end
local coordinateResult = SMK.Search:Find({}, "12.3,45.67", false, 100)[1]
assert(coordinateResult.entry.x == 12.3 and coordinateResult.entry.y == 45.67
    and coordinateResult.entry.name == "坐标：12.3，45.67",
    "coordinate result values or display text are incorrect")
assert(not SMK.Store:RecordUsage(coordinateResult.entry)
    and SearchMakerDB.usageCounts["id:nil"] == nil,
    "temporary coordinate result was written to usage storage")
assert(SMK.Map:SetWaypoint(coordinateResult.entry)
    and waypoint.uiMapID == 100
    and math.abs(waypoint.position.x - 0.123) < 0.000001
    and math.abs(waypoint.position.y - 0.4567) < 0.000001,
    "coordinate result did not use the native waypoint service")

UIParent = { GetEffectiveScale = function() return 2 end }
GetCursorPosition = function() return 400, 300 end
WorldMapFrame = {
    IsShown = function() return true end,
    ScrollContainer = {
        GetLeft = function() return 100 end,
        GetRight = function() return 300 end,
        GetTop = function() return 250 end,
        GetBottom = function() return 50 end,
    },
}
local cursorScreenX, cursorScreenY = SMK.Map:GetCursorScreenPosition()
local cursorMapX, cursorMapY = SMK.Map:GetCursorMapCoordinates()
assert(cursorScreenX == 200 and cursorScreenY == 150
    and cursorMapX == 50 and cursorMapY == 50,
    "cursor coordinates were not normalized for UI scale")

playerMapID = 100
WorldMapFrame = {
    IsShown = function() return false end,
    GetMapID = function() return nil end,
}
assert(SMK.Map:GetPlayerMapID() == 100 and SMK.Map:GetContextMapID() == 100,
    "hidden world map did not use the player's current map")
mapInfo[85] = { mapID = 85, name = "奥格瑞玛" }
local externalNodes = {
    [12345678] = { name = "English Internal Name", npcID = 9876 },
    [22334455] = { name = "", type = "Portal", mnID = 85 },
}
local externalIcons = {
    [12345678] = "Interface\\AddOns\\HandyNotes_MapNotes\\Images\\FirstAid",
}
HandyNotes_MapNotesRetailNpcCacheDB = {
    names = {
        zhCN = {
            [9876] = "卡娜莉亚\031<绷带训练师>",
        },
    },
}
local handyNotesBuilds = 0
HandyNotes = {
    plugins = {
        MapNotes = {
            GetNodes2 = function()
                handyNotesBuilds = handyNotesBuilds + 1
                return function(state, previous)
                    local coord = next(state.data, previous)
                    if coord then return coord, nil, state.icons[coord] end
                end, { data = externalNodes, icons = externalIcons }, nil
            end,
        },
    },
}
SMK.HandyNotesProvider:RebuildCache(100, true)
local handyNotesEntries = SMK.HandyNotesProvider:GetByMap(100)
assert(SMK.HandyNotesProvider:RebuildCache(100) == handyNotesEntries
    and handyNotesBuilds == 1,
    "HandyNotes rebuilt an unchanged current-map cache")
local trainerEntry, portalEntry
for _, entry in ipairs(handyNotesEntries) do
    if entry.x == 12.34 then trainerEntry = entry end
    if entry.x == 22.33 then portalEntry = entry end
end
assert(#handyNotesEntries == 2 and trainerEntry
    and trainerEntry.mapID == 100 and trainerEntry.y == 56.78
    and trainerEntry.name == "绷带训练师"
    and trainerEntry.externalSource == "HandyNotes_MapNotes"
    and trainerEntry.normalizedSearchable:find("绷带", 1, true)
    and trainerEntry.iconTexture == externalIcons[12345678],
    "HandyNotes did not cache the player's map while WorldMapFrame was unopened")
local bandageMatches = SMK.Search:Find({}, "绷带", false, 100, handyNotesEntries)
assert(#bandageMatches == 1 and bandageMatches[1].entry == trainerEntry,
    "localized HandyNotes NPC title was not searchable")
local portalMatches = SMK.Search:Find({}, "传送", false, 100, handyNotesEntries)
assert(portalEntry and portalEntry.name == "传送门：奥格瑞玛"
    and #portalMatches == 1 and portalMatches[1].entry == portalEntry,
    "localized HandyNotes portal type was not searchable")
assert(#SMK.Search:Find({}, "English", false, 100, handyNotesEntries) == 0
    and #SMK.Search:Find({}, "9876", false, 100, handyNotesEntries) == 0,
    "non-Chinese HandyNotes fields were searchable in a Chinese locale")
SMK.HandyNotesProvider:RebuildCache(85)
assert(#SMK.Search:Find({}, "绷带", false, 100,
    SMK.HandyNotesProvider:GetByMap(85)) == 0,
    "current-map search included a stale HandyNotes map cache")
SMK.HandyNotesProvider:RebuildCache(100)
handyNotesEntries = SMK.HandyNotesProvider:GetByMap(100)
assert(#SMK.Search:Find({}, "绷带", false, 100, handyNotesEntries) == 1,
    "HandyNotes cache did not return to the player's current map")
SMK.MapContext:Refresh(100)
assert(SMK.MapContext:GetMapID() == 100
    and SMK.MapContext:GetExternalEntries() == handyNotesEntries
    and SMK.MapContext:GetEntries() == SMK.Store:GetByMap(100),
    "map context did not expose one current-map snapshot for all consumers")
local fakeIcon = {
    SetTexture = function(self, value) self.texture = value end,
    SetTexCoord = function(self, ...) self.texCoord = { ... } end,
    SetAtlas = function(self, value) self.atlas = value end,
}
SMK.Widgets:SetLocationIcon(fakeIcon, trainerEntry)
assert(fakeIcon.texture == externalIcons[12345678],
    "HandyNotes search result did not use its source icon")
fakeIcon.texture = nil
fakeIcon.atlas = nil
SMK.Widgets:SetLocationIcon(fakeIcon, { isExternal = true })
assert(fakeIcon.atlas == SMK.Config.categoryByKey.other.atlas,
    "HandyNotes search result did not use the other-category fallback icon")
fakeIcon.atlas = nil
SMK.Widgets:SetLocationIcon(fakeIcon, { isMapPortal = true })
assert(fakeIcon.atlas == "poi-islands-table",
    "map portal search result did not use its contained icon atlas")
HandyNotes = nil

local shareEntry = assert(SMK.LocationModel:Normalize({
    mapID = first.mapID,
    x = first.x,
    y = first.y,
    name = first.name,
    categoryKey = first.categoryKey,
    showPinName = 1,
    showPinTexture = 1,
    pinTextureID = first.pinTextureID,
    pinColor = { r = 0.2, g = 0.4, b = 0.6 },
}))
local encoded = SMK.ShareCodec:Encode({ shareEntry })
assert(encoded:sub(1, 4) == "SMK|" and encoded:sub(1, 6) ~= "SMK|2|",
    "current share format does not use the unified SMK prefix")
assert(SMK.ShareCodec:FindShareText("chat " .. encoded) == encoded,
    "share text was not found in chat")
local decoded, decodeError, invalid = SMK.ShareCodec:Decode(encoded)
assert(not decodeError and invalid == 0 and #decoded == 1, "current share round trip failed")
assert(decoded[1].categoryKey == "delves" and decoded[1].pinTextureID == 5
    and math.abs(decoded[1].pinColor.r - 0.2) < 0.005
    and math.abs(decoded[1].pinColor.g - 0.4) < 0.005
    and math.abs(decoded[1].pinColor.b - 0.6) < 0.005,
    "share fields or per-location pin color were not preserved")
local noColorDecoded, noColorError, noColorInvalid = SMK.ShareCodec:Decode(
    SMK.ShareCodec:Encode({ assert(SMK.LocationModel:Normalize({
        mapID = 100, x = 1, y = 2, name = "无颜色", categoryKey = "other",
    })) }))
assert(not noColorError and noColorInvalid == 0 and #noColorDecoded == 1
    and noColorDecoded[1].pinColor == nil,
    "share records without a per-location color did not round trip")
local importResult = assert(SMK.Import:ImportText(encoded))
assert(importResult.imported == 0 and importResult.duplicates == 1,
    "shared import service did not filter duplicates")
local invalidImport = assert(SMK.Import:ImportEntries({ {} }))
assert(invalidImport.invalid == 1 and invalidImport.imported == 0,
    "shared import service did not validate entries")

for _, sample in ipairs({ "SMK3|x", "SMK2|x", "MLL2|x", "MLL1|x" }) do
    local entries = SMK.ShareCodec:Decode(sample)
    assert(not entries, "legacy share prefix was accepted: " .. sample)
end
local oldEntries, _, oldInvalid = SMK.ShareCodec:Decode(
    "SMK|100,100,200,8,old,0,1,0,0")
assert(oldEntries and #oldEntries == 0 and oldInvalid == 1,
    "obsolete field-count share records were accepted")

local duplicateA = { mapID = 100, x = 1.234, y = 5.678, name = " Test Name " }
local duplicateB = { mapID = 100, x = 1.2341, y = 5.6781, name = "testname" }
assert(SMK.LocationModel:GetDuplicateKey(duplicateA) == SMK.LocationModel:GetDuplicateKey(duplicateB),
    "duplicate normalization failed")

local ranges501 = SMK.ShareDialog:GetExportRanges(501)
local ranges1000 = SMK.ShareDialog:GetExportRanges(1000)
assert(#ranges501 == 3 and ranges501[3].first == 401 and ranges501[3].last == 501,
    "501-entry export pagination failed")
assert(#ranges1000 == 5 and ranges1000[5].first == 801 and ranges1000[5].last == 1000,
    "1000-entry export pagination failed")
assert(SMK.Settings:Set("exportBatchSize", 50))
local ranges120 = SMK.ShareDialog:GetExportRanges(120)
assert(#ranges120 == 3 and ranges120[2].first == 51 and ranges120[2].last == 100
    and ranges120[3].first == 101 and ranges120[3].last == 120,
    "selected export batch size did not control pagination")
assert(not SMK.Settings:Set("exportBatchSize", 75)
    and SMK.Settings:Get("exportBatchSize") == 50,
    "unsupported export batch size was accepted")
local originalExport = SMK.ShareDialog.Export
local exportRefreshes = 0
SMK.ShareDialog.exportEntries = {}
SMK.ShareDialog.Export = function() exportRefreshes = exportRefreshes + 1 end
SMK.ShareDialog:SetBatchSize(100)
SMK.ShareDialog.Export = originalExport
SMK.ShareDialog.exportEntries = nil
assert(exportRefreshes == 1,
    "changing export batch size did not refresh the filtered export entries")

mapInfo[946] = { name = "Cosmic", mapType = Enum.UIMapType.Cosmic }
mapChildren[946] = {}
assert(not SMK.MapIndex:Rebuild(true), "empty map index was marked ready")
for index = 1, 8 do
    local mapID = 1000 + index
    mapInfo[mapID] = { name = "Map " .. index, mapType = Enum.UIMapType.Zone }
    mapChildren[946][#mapChildren[946] + 1] = { mapID = mapID }
end
mapInfo[947] = { name = "Duplicate Root", mapType = Enum.UIMapType.Cosmic }
mapChildren[947] = { { mapID = 1001 } }
assert(SMK.MapIndex:Rebuild(true), "map index build failed")
local mapMatches = SMK.MapIndex:Search("Map")
assert(#mapMatches == 5, "map result limit failed")
local seenMapIDs = {}
for _, match in ipairs(mapMatches) do
    assert(not seenMapIDs[match.entry.mapID], "map index contains duplicates")
    seenMapIDs[match.entry.mapID] = true
end

waypoint = UiMapPoint.CreateFromCoordinates(200, 0.2, 0.3)
superTracked = true
assert(SMK.Map:BeginTemporaryWaypoint({ mapID = 100, x = 40, y = 50 }), "temporary waypoint failed")
assert(waypoint.uiMapID == 100, "temporary waypoint was not set")
SMK.Map:ClearTemporaryWaypoint()
assert(waypoint.uiMapID == 200 and waypoint.position.x == 0.2 and superTracked,
    "previous waypoint was not restored")

function Mixin(target, ...)
    for index = 1, select("#", ...) do
        for key, value in pairs(select(index, ...)) do target[key] = value end
    end
    return target
end
function CreateFromMixins(...) return Mixin({}, ...) end
MapCanvasDataProviderMixin = { GetMap = function(self) return self.map end }
MapCanvasPinMixin = {
    UseFrameLevelType = function(self, value) self.frameLevelType = value end,
    SetScalingLimits = function() end,
    SetPosition = function(self, x, y) self.x, self.y = x, y end,
}
function CreateUnsecuredRegionPoolInstance() return {} end
local function NewTexture()
    return {
        SetAllPoints = function() end,
        SetAtlas = function(self, atlas) self.atlas = atlas end,
        SetPoint = function() end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        SetTexture = function(self, texture) self.texture = texture end,
        SetBlendMode = function(self, blendMode) self.blendMode = blendMode end,
        SetVertexColor = function(self, r, g, b) self.color = { r = r, g = g, b = b } end,
        CreateAnimationGroup = function(self)
            local group = {
                CreateAnimation = function()
                    return {
                        SetFromAlpha = function() end,
                        SetToAlpha = function() end,
                        SetDuration = function() end,
                        SetOrder = function() end,
                    }
                end,
                SetLooping = function() end,
                Play = function(groupSelf) groupSelf.playing = true end,
                Stop = function(groupSelf) groupSelf.playing = false end,
            }
            self.animationGroup = group
            return group
        end,
        Show = function(self) self.shown = true end,
        SetShown = function(self, value) self.shown = value end,
        Hide = function(self) self.shown = false end,
    }
end
local function NewFontString()
    return {
        ClearAllPoints = function() end,
        SetPoint = function() end,
        SetTextColor = function(self, r, g, b) self.color = { r = r, g = g, b = b } end,
        SetScale = function(self, value) self.scale = value end,
        SetText = function(self, value) self.text = value end,
        SetShown = function(self, value) self.shown = value end,
        Hide = function(self) self.shown = false end,
    }
end
function CreateFrame()
    return {
        EnableMouse = function() end,
        SetScript = function(self, event, callback)
            self.scripts = self.scripts or {}
            self.scripts[event] = callback
        end,
        CreateTexture = function() return NewTexture() end,
        CreateFontString = function() return NewFontString() end,
        SetSize = function() end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        ClearAllPoints = function() end,
        GetLeft = function() return 10 end,
        GetRight = function() return 30 end,
        GetBottom = function() return 20 end,
        GetTop = function() return 40 end,
    }
end
GameTooltip = {
    SetOwner = function() end,
    SetText = function(self, value) self.title = value end,
    AddLine = function(self, value)
        self.lines = self.lines or {}
        self.lines[#self.lines + 1] = value
    end,
    Show = function(self) self.shown = true end,
}
function GameTooltip_Hide() end

mapInfo[100] = { name = "测试地图", mapType = Enum.UIMapType.Zone }
local fakeMap = { pinPools = {}, pins = {}, mapID = 100 }
function fakeMap:GetCanvas() return self end
function fakeMap:GetMapID() return self.mapID end
function fakeMap:IsShown() return true end
function fakeMap:AddDataProvider(provider) provider.map = self end
function fakeMap:AcquirePin(template, ...)
    local pin = self.pinPools[template].createFunc()
    pin.pinTemplate = template
    pin:OnAcquired(...)
    self.pins[#self.pins + 1] = pin
    return pin
end
function fakeMap:RemoveAllPinsByTemplate(template)
    local retained = {}
    for _, pin in ipairs(self.pins) do
        if pin.pinTemplate == template then
            self.pinPools[template].resetFunc(nil, pin)
        else
            retained[#retained + 1] = pin
        end
    end
    self.pins = retained
end
local editedPinEntry
assert(SMK.MapPins:Initialize(fakeMap, {
    onEdit = function(entry) editedPinEntry = entry end,
}), "map pin provider initialization failed")
SMK.MapPins:Refresh()
assert(#fakeMap.pins == 1, "enabled map pin was not acquired")
assert(fakeMap.pins[1].frameLevelType == "PIN_FRAME_LEVEL_AREA_POI",
    "persistent map pin frame level changed")
assert(fakeMap.pins[1].icon.atlas == SMK.PinTextureByID[5].atlas, "selected pin texture was ignored")
assert(fakeMap.pins[1].label.text == "旧地点" and fakeMap.pins[1].label.shown,
    "enabled map pin name was not rendered")
assert(fakeMap.pins[1].label.color.r == 0.2 and fakeMap.pins[1].label.color.g == 0.4
    and fakeMap.pins[1].label.color.b == 0.6 and fakeMap.pins[1].label.scale == 1.4,
    "pin text appearance settings were not rendered")
local highlightTimers = {}
C_Timer = {
    After = function(_, callback) highlightTimers[#highlightTimers + 1] = callback end,
}
assert(SMK.MapPins:ShowTargetHighlight({ mapID = 100, x = 25, y = 75 })
    and #fakeMap.pins == 2,
    "target highlight pin was not acquired")
local highlightPin = fakeMap.pins[2]
assert(highlightPin.pinTemplate == "SearchMakerTargetHighlightPinTemplate"
    and highlightPin.frameLevelType == "PIN_FRAME_LEVEL_TOPMOST"
    and highlightPin.x == 0.25 and highlightPin.y == 0.75
    and highlightPin.icon.atlas == "MonsterEnemy"
    and highlightPin.ring.texture == "Interface\\Cooldown\\starburst"
    and highlightPin.ring.width == 80
    and highlightPin.ring.color.r == 1
    and highlightPin.ring.color.g == 1
    and highlightPin.ring.color.b == 1
    and highlightPin.icon.shown
    and highlightPin.ring.animationGroup.playing,
    "target highlight was not positioned or animated")
assert(SMK.MapPins:ShowTargetHighlight({ mapID = 100, x = 40, y = 60 })
    and #fakeMap.pins == 2 and fakeMap.pins[2].x == 0.4,
    "a newer target highlight did not replace the previous one")
highlightTimers[1]()
assert(#fakeMap.pins == 2, "an older timer removed the current target highlight")
highlightTimers[2]()
assert(#fakeMap.pins == 1, "target highlight was not released after its duration")
assert(SMK.MapPins:ShowHoverHighlight({ mapID = 100, x = 30, y = 70 })
    and #fakeMap.pins == 2 and fakeMap.pins[2].x == 0.3,
    "hover highlight pin was not acquired")
assert(not fakeMap.pins[2].icon.shown
    and fakeMap.pins[2].ring.shown
    and fakeMap.pins[2].ring.animationGroup.playing,
    "hover highlight did not hide the marker while keeping the animation")
assert(SMK.MapPins:ShowHoverHighlight({ mapID = 100, x = 45, y = 55 })
    and #fakeMap.pins == 2 and fakeMap.pins[2].x == 0.45,
    "a newer hover highlight did not replace the previous one")
SMK.MapPins:ClearHoverHighlight()
assert(#fakeMap.pins == 1, "hover highlight was not cleared")
assert(SMK.MapPins:ShowTargetHighlight({ mapID = 100, x = 20, y = 80 })
    and not SMK.MapPins:ShowHoverHighlight({ mapID = 100, x = 90, y = 10 })
    and #fakeMap.pins == 2 and fakeMap.pins[2].x == 0.2,
    "hover highlight replaced an active target highlight")
SMK.MapPins:ClearHoverHighlight()
assert(#fakeMap.pins == 2, "clearing hover removed an active target highlight")
highlightTimers[3]()
assert(#fakeMap.pins == 1, "protected target highlight was not released by its timer")
assert(SMK.MapPins:ContainsMouseFocus({ fakeMap.pins[1] }),
    "map pin focus was not identified")
assert(not fakeMap.pins[1].scripts or (not fakeMap.pins[1].scripts.OnEnter
    and not fakeMap.pins[1].scripts.OnLeave),
    "map pin installed inherited motion scripts before AcquirePin")
fakeMap.pins[1]:OnMouseEnter()
assert(GameTooltip.title == "旧地点"
    and GameTooltip.lines[1]:find("测试地图", 1, true)
    and GameTooltip.lines[1]:find("100", 1, true)
    and GameTooltip.lines[2]:find("12.34", 1, true)
    and GameTooltip.lines[2]:find("56.78", 1, true),
    "map pin tooltip did not separate its map name and coordinates")
fakeMap.pins[1]:OnClick("LeftButton")
assert(editedPinEntry and editedPinEntry.name == "旧地点", "map pin click did not open its editor callback")
SearchMakerDB.settings.showMapPinNames = false
SMK.MapPins:Refresh()
assert(#fakeMap.pins == 1 and fakeMap.pins[1].label.shown == false,
    "disabled map pin name was still rendered")
SearchMakerDB.settings.showPinTextures = false
SMK.MapPins:Refresh()
assert(#fakeMap.pins == 0,
    "fully hidden map pins still retained an interactive frame")

local layoutButton = {
    showIcon = false,
    SetSize = function(self, width, height) self.width, self.height = width, height end,
    GetWidth = function(self) return self.width end,
    SetWidth = function(self, width) self.width = width end,
    SetClipsChildren = function(self, value) self.clipsChildren = value end,
    iconBox = {
        ClearAllPoints = function() end,
        SetPoint = function() end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        SetShown = function(self, shown) self.shown = shown end,
    },
    background = {
        ClearAllPoints = function() end,
        SetPoint = function() end,
        SetAtlas = function() end,
        Show = function() end,
    },
    hitArea = { ClearAllPoints = function() end, SetAllPoints = function() end },
    label = {
        text = "short",
        width = 50,
        GetText = function(self) return self.text end,
        GetUnboundedStringWidth = function(self) return self.width end,
        ClearAllPoints = function() end,
        SetPoint = function(self, point, _, _, x, y)
            if point == "LEFT" then self.leftOffset, self.yOffset = x, y end
        end,
    },
}
SMK.Widgets:UpdateLocationGeometry(layoutButton)
assert(layoutButton.height == 38 and layoutButton.width == 179
    and layoutButton.iconBox.width == 0 and not layoutButton.iconBox.shown
    and layoutButton.label.leftOffset == 8 and layoutButton.label.yOffset == 1,
    "main panel location sign geometry is incorrect")
layoutButton.showIcon = true
SMK.Widgets:UpdateLocationGeometry(layoutButton)
assert(layoutButton.width == 217 and layoutButton.iconBox.width == 38
    and layoutButton.iconBox.shown,
    "search result location icon geometry is incorrect")
layoutButton.label.text, layoutButton.label.width = "long", 220
SMK.Widgets:UpdateLocationGeometry(layoutButton)
assert(layoutButton.width == 274,
    "search result location sign did not expand for long text")
SMK.Widgets:StretchSearchResult(layoutButton, 232)
assert(layoutButton.width == 232 and not layoutButton.clipsChildren,
    "search result width was not constrained")

local appliedBarAlpha, appliedBoxAlpha, appliedHintAlpha
local originalSearchBar, originalSearchBox = SMK.SearchBar.bar, SMK.SearchBar.box
SMK.SearchBar.bar = { SetAlpha = function(_, value) appliedBarAlpha = value end }
SMK.SearchBar.box = {
    SetAlpha = function(_, value) appliedBoxAlpha = value end,
    moveHint = { SetAlpha = function(_, value) appliedHintAlpha = value end },
}
SMK.SearchBar:ApplyOpacity()
SMK.SearchBar.bar, SMK.SearchBar.box = originalSearchBar, originalSearchBox
assert(appliedBarAlpha == 1 and appliedBoxAlpha == SMK.Settings:Get("searchBarOpacity")
    and appliedHintAlpha == appliedBoxAlpha,
    "search results inherited search-box opacity")

local playerContextRequests = 0
local originalCallbacks = SMK.SearchBar.callbacks
SMK.SearchBar.callbacks = {
    onPlayerContextRequested = function() playerContextRequests = playerContextRequests + 1 end,
}
assert(SMK.Settings:Set("searchAllMaps", false))
SMK.SearchBar:RefreshPlayerContext()
SMK.SearchBar.callbacks = originalCallbacks
assert(playerContextRequests == 1,
    "floating search did not request a fresh player-map context")

local favoriteOptions = SMK.SearchResults:GetFavoriteOptions()
assert(#favoriteOptions == #SMK.Config.categories
    and favoriteOptions[1].key == SMK.Config.categories[1].key
    and favoriteOptions[#favoriteOptions].atlas == SMK.Config.categories[#SMK.Config.categories].atlas,
    "HandyNotes favorite options do not follow the dynamic category configuration")
assert(SMK.HelpDialog and SMK.HelpDialog.Create and SMK.HelpDialog.Open
    and SMK.L.HELP_TEXT ~= "",
    "localized help dialog is unavailable")
assert(SMK.Config.panel.layout.scrollbarOffsetX == -6,
    "main panel scrollbar offset changed")

local panelExpanded, resultsUpdated, outsideRegistered = false, 0, false
local controllerSearchBar = {
    suppressPanelHidden = false,
    searchResults = {
        IsShown = function() return false end,
        IsContextMenuOpen = function() return false end,
    },
    outsideListener = {
        RegisterEvent = function() outsideRegistered = true end,
        UnregisterEvent = function() outsideRegistered = false end,
    },
    box = { ClearFocus = function() end },
    UpdateResults = function() resultsUpdated = resultsUpdated + 1 end,
    HideResults = function() end,
    CancelPendingSearch = function() end,
    SetQuery = function() end,
}
local managedPanel = {
    SetExpanded = function(_, value) panelExpanded = value end,
    IsExpanded = function() return panelExpanded end,
}
local panelController = SMK.PanelController:New(controllerSearchBar)
panelController:AttachPanel(managedPanel)
panelController:Open()
assert(panelExpanded and resultsUpdated == 1 and outsideRegistered,
    "panel controller did not own panel opening and listener registration")
panelController:Close()
assert(not panelExpanded and not outsideRegistered,
    "panel controller did not close the panel and release its listener")

print("SearchMaker service tests passed")
