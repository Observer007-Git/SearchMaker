local context = assert(...)
local SMK = context.SMK

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
assert(not SMK.Settings:Set("locationScale", 1.1), "future database setting write was accepted")
assert(futureDatabase.settings == nil, "future database settings were written through runtime data")
assert(not SMK.Store:Add({ mapID = 100, x = 1, y = 2, name = "blocked", categoryKey = "other" }),
    "future database accepted a write")

SearchMakerDB = {
    schemaVersion = 7,
    settings = {
        showMapPinNames = true,
        showPinTextures = false,
        mapPinTextColor = { r = 0.2, g = 0.4, b = 0.6 },
        mapPinNameOffsetY = 2,
    },
    locations = {
        { id = 1, mapID = 100, x = 1, y = 2, name = "旧18", categoryKey = "other", customIconID = 18 },
        { id = 2, mapID = 100, x = 3, y = 4, name = "旧30", categoryKey = "other", customIconID = 30 },
        { id = 3, mapID = 100, x = 5, y = 6, name = "旧32", categoryKey = "other", customIconID = 32 },
        { id = 4, mapID = 100, x = 7, y = 8, name = "旧33", categoryKey = "other", customIconID = 33 },
        { id = 5, mapID = 100, x = 9, y = 10, name = "路径", categoryKey = "other", customIconID = -3 },
        { id = 6, mapID = 100, x = 11, y = 12, name = "已删除图标", categoryKey = "other", customIconID = 24 },
        { id = 7, mapID = 100, x = 13, y = 14, name = "后移图标", categoryKey = "other", customIconID = 25 },
        { id = 8, mapID = 100, x = 15, y = 16, name = "末尾图标", categoryKey = "other", customIconID = 42 },
    },
}
SMK.DB:Initialize()
assert(SearchMakerDB.schemaVersion == SMK.Config.databaseSchemaVersion
    and SearchMakerDB.locations[1].customIconID == 28
    and SearchMakerDB.locations[2].customIconID == 28
    and SearchMakerDB.locations[3].customIconID == 16
    and SearchMakerDB.locations[4].customIconID == 17
    and SearchMakerDB.locations[5].customIconID == -3
    and SearchMakerDB.locations[6].customIconID == nil
    and SearchMakerDB.locations[7].customIconID == 23
    and SearchMakerDB.locations[8].customIconID == 38
    and SearchMakerDB.settings.mapPinNameOffsetY == 0
    and SearchMakerDB.settings.showMapPinNames == nil
    and SearchMakerDB.settings.showPinTextures == nil
    and SearchMakerDB.settings.mapPinTextColor == nil,
    "database migrations did not preserve icons or remove obsolete global pin settings")

SearchMakerDB = {
    schemaVersion = 10,
    locations = {
        { id = 1, mapID = 100, x = 1, y = 2, name = "删除23", categoryKey = "other", customIconID = 23 },
        { id = 2, mapID = 100, x = 3, y = 4, name = "移动24", categoryKey = "other", customIconID = 24 },
        { id = 3, mapID = 100, x = 5, y = 6, name = "移动39", categoryKey = "other", customIconID = 39 },
        { id = 4, mapID = 100, x = 7, y = 8, name = "保留路径", categoryKey = "other", customIconID = -3 },
    },
}
SMK.DB:Initialize()
assert(SearchMakerDB.schemaVersion == SMK.Config.databaseSchemaVersion
    and SearchMakerDB.locations[1].customIconID == nil
    and SearchMakerDB.locations[2].customIconID == 23
    and SearchMakerDB.locations[3].customIconID == 38
    and SearchMakerDB.locations[4].customIconID == -3,
    "schema 11 did not shift Atlas IDs above 23 down by one")

SearchMakerDB = {
    schemaVersion = SMK.Config.databaseSchemaVersion,
    settings = {
        showPinTextures = true,
        showFullPanel = false,
        locationScale = 1.2,
        searchBarScale = 1.4,
        searchBarOpacity = 0.6,
        searchBarStyle = 2,
        searchBarMapOnly = true,
        thirdPartySearchEnabled = false,
        exportBatchSize = 75,
        pinTextureScale = 9,
        mapPinNameOffsetX = -80,
        mapPinNameOffsetY = 80,
    },
    locations = {
        { id = 4, mapID = "100", x = "12.34", y = "56.78", name = "旧地点", note = "绿色备注", categoryKey = "delves", showPinName = 1, showPinTexture = 1, pinTexture = "VignetteEvent-SuperTracked", customIconID = "-3", futureExtension = "drop" },
        { id = 4, mapID = 100, x = 20, y = 30, name = "重复ID", categoryKey = "npc" },
        { id = "invalid", mapID = 0, x = 1, y = 2, name = "损坏地点", categoryKey = "other" },
    },
    usageCounts = { [4] = 2, [999] = 9 },
}
SMK.DB:Initialize()
assert(SearchMakerDB.schemaVersion == SMK.Config.databaseSchemaVersion, "database schema was not initialized")
assert(SearchMakerDB.locations[1].categoryKey == "delves", "category normalization failed")
assert(SearchMakerDB.locations[1].pinTextureID == 5
    and SearchMakerDB.locations[1].pinTexture == nil,
    "pin texture ID normalization failed")
assert(SearchMakerDB.locations[1].customIconID == -3, "custom icon normalization failed")
assert(SearchMakerDB.locations[2].id ~= 4, "duplicate ID was not repaired")
assert(#SearchMakerDB.locations == 2 and SearchMakerDB.usageCounts[999] == nil
    and SearchMakerDB.usageCounts[4] == 2,
    "invalid locations or orphan usage counts were not pruned")
assert(type(SearchMakerDB.locations[1].id) == "number"
    and type(SearchMakerDB.nextLocationID) == "number",
    "location IDs were not stored compactly as numbers")
assert(SMK.Settings:Get("locationScale") == 1.2
    and SearchMakerDB.settings.showPinTextures == nil,
    "nested settings were not initialized")
assert(SMK.Settings:Get("searchBarScale") == 1.4
    and SMK.Settings:Get("searchBarOpacity") == 0.6
    and SMK.Settings:Get("searchBarStyle")
        == SMK.Config.search.appearance.styles.noPortrait
    and SMK.Settings:Get("searchBarMapOnly") == true
    and SMK.Settings:Get("thirdPartySearchEnabled") == false,
    "search bar appearance settings were not persisted")
assert(SMK.Settings:Get("exportBatchSize") == SMK.Config.export.defaultBatchSize,
    "export batch size default was not initialized")
assert(SMK.Settings:Get("pinTextureScale") == SMK.Config.mapPins.maxTextureScale
    and SMK.Settings:Get("mapPinNameOffsetX") == SMK.Config.mapPins.nameOffsetXMin
    and SMK.Settings:Get("mapPinNameOffsetY") == SMK.Config.mapPins.nameOffsetYMax,
    "map pin appearance settings were not clamped")
assert(SearchMakerDB.locations[1].showPin == nil
    and SearchMakerDB.locations[1].showPinName == 1
    and SearchMakerDB.locations[1].showPinTexture == 1,
    "canonical map pin visibility fields were not retained")
assert(SearchMakerDB.settings.showFullPanel == nil, "removed panel setting was retained")
assert(SMK.Settings:Get("showMapPinNames") == nil
    and SMK.Settings:Get("mapPinTextColor") == nil
    and SMK.Settings:Get("mapPinTextScale") == 1,
    "pin text appearance defaults were not initialized")
assert(SearchMakerDB.locationScale == nil and SearchMakerDB.showPinTextures == nil,
    "obsolete root settings were not removed")
local changedSetting
SMK.Settings:SetChangeHandler(function(key) changedSetting = key end)
assert(SMK.Settings:Set("locationScale", 1.3) and changedSetting == "locationScale",
    "setting change was not normalized and announced")
assert(SMK.Settings:Set("mapPinTextScale", 1.4) and changedSetting == "mapPinTextScale",
    "pin text scale was not persisted and announced")
assert(SMK.Settings:Set("searchBarStyle",
        SMK.Config.search.appearance.styles.blizzard)
    and SMK.Settings:Get("searchBarStyle")
        == SMK.Config.search.appearance.styles.blizzard,
    "Blizzard-native search bar UI style was not accepted")
assert(not SMK.Settings:Set("searchBarStyle", 4),
    "invalid search bar UI style was accepted")
assert(SMK.Settings:Set("searchBarMapOnly", false)
    and SMK.Settings:Get("searchBarMapOnly") == false,
    "world-map-only search bar visibility was not persisted")
assert(SMK.Settings:Set("thirdPartySearchEnabled", true)
    and SMK.Settings:Get("thirdPartySearchEnabled") == true,
    "third-party coordinate search setting was not persisted")
assert(SMK.Settings:Get("mapPinCreateShortcut") == false
    and SMK.Settings:Set("mapPinCreateShortcut", {
        key = "F", ctrl = true,
    })
    and SMK.Settings:Get("mapPinCreateShortcut").key == "F"
    and SMK.Settings:Get("mapPinCreateShortcut").ctrl == true
    and not SMK.Settings:Set("mapPinCreateShortcut", { key = "" })
    and SMK.Settings:Set("mapPinCreateShortcut", false),
    "map pin creation shortcut was not validated or persisted")
assert(SMK.Settings:Set("shortcutSearchBarPosition", { x = 10, y = 20 })
    and SMK.Settings:Set("shortcutSearchBarPosition", { x = 30, y = 40 })
    and SMK.Settings:Get("shortcutSearchBarPosition").x == 30,
    "table comparison interfered with position settings")
assert(not SMK.Settings:Set("showMapPinNames", true)
    and not SMK.Settings:Set("showPinTextures", true)
    and not SMK.Settings:Set("mapPinTextColor", { r = 1, g = 1, b = 1 }),
    "removed global pin settings were still accepted")

local first = SMK.Store:GetAll()[1]
assert(first.categoryKey == "delves" and first.categoryLabel == "地下堡", "display projection is not localized")
assert(SMK.Store:Update(first, {
    mapID = first.mapID, x = first.x, y = first.y, name = first.name,
    categoryKey = first.categoryKey, showPinName = first.showPinName,
    showPinTexture = first.showPinTexture, pinTextureID = first.pinTextureID,
    customIconID = first.customIconID, pinColor = first.pinColor, note = first.note,
}), "location update failed")
assert(SearchMakerDB.locations[1].categoryKey == "delves", "editing changed the canonical category")
assert(SearchMakerDB.locations[1].note == "绿色备注", "editing discarded the location note")
assert(SearchMakerDB.locations[1].futureExtension == nil,
    "unknown location fields were retained in the canonical store")
local sameNameDifferentPosition = {
    mapID = first.mapID, x = first.x + 1, y = first.y, name = first.name,
    categoryKey = first.categoryKey,
}
assert(not SMK.Store:FindDuplicate(sameNameDifferentPosition),
    "duplicate detection ignored coordinates")
assert(SMK.Store:FindDuplicate(first), "duplicate detection missed the same location")
local duplicateAdd, duplicateAddMessage = SMK.Store:Add(first)
assert(not duplicateAdd
    and duplicateAddMessage == string.format(SMK.L.DUPLICATE_NAME, first.name),
    "Store:Add bypassed the duplicate invariant")
local allCacheBeforeIncremental = SMK.Store:GetAll()
local mapCacheBeforeIncremental = SMK.Store:GetByMap(first.mapID)
local retainedDisplayBeforeIncremental = SMK.Store:GetByID(first.id)
local incrementalEntry = assert(SMK.Store:Add({
    mapID = first.mapID, x = 70, y = 71, name = "增量缓存", categoryKey = "other",
}))
assert(SMK.Store:GetAll() == allCacheBeforeIncremental
    and SMK.Store:GetByMap(first.mapID) == mapCacheBeforeIncremental
    and SMK.Store:GetByID(first.id) == retainedDisplayBeforeIncremental,
    "adding a location rebuilt unaffected store caches")
assert(SMK.Store:Update(incrementalEntry, {
    mapID = 201, x = 72, y = 73, name = "增量缓存更新", categoryKey = "other",
}))
assert(SMK.Store:GetAll() == allCacheBeforeIncremental
    and SMK.Store:GetByMap(first.mapID) == mapCacheBeforeIncremental
    and SMK.Store:GetByID(first.id) == retainedDisplayBeforeIncremental
    and SMK.Store:GetByMap(201)[1].name == "增量缓存更新",
    "updating a location rebuilt unaffected store caches")
assert(SMK.Store:Delete(SMK.Store:GetByMap(201)[1]) == 1,
    "incremental cache test location could not be removed")

local externalFavorite = {
    isExternal = true,
    externalSource = "HandyNotes_MapNotes",
    mapID = 100,
    x = 42.25,
    y = 63.5,
    name = "绷带训练师",
}
local favorite = assert(SMK.Store:AddExternal(externalFavorite, "profession"))
assert(favorite.source == "saved" and favorite.categoryKey == "profession"
    and favorite.showPinName == 0 and favorite.showPinTexture == 0,
    "external favorite was not saved to its selected category")
local duplicateFavorite, duplicateFavoriteError = SMK.Store:AddExternal(externalFavorite)
assert(not duplicateFavorite
    and duplicateFavoriteError == string.format(SMK.L.DUPLICATE_NAME, externalFavorite.name),
    "duplicate external favorite was accepted")
assert(SMK.Store:Delete(favorite) == 1, "external favorite could not be deleted")
local defaultExternalFavorite = SMK.Util.CopyTable(externalFavorite)
defaultExternalFavorite.x, defaultExternalFavorite.name = 43.25, "默认外部分组"
local defaultFavorite = assert(SMK.Store:AddExternal(defaultExternalFavorite))
assert(defaultFavorite.categoryKey == SMK.Config.handyNotes.categoryKey,
    "external favorite did not default to the HandyNotes_MapNotes category")
assert(SMK.Store:Delete(defaultFavorite) == 1,
    "default external favorite fixture could not be deleted")
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
local batchNotifications = 0
SMK.Store:SetChangeHandler(function(reason)
    if reason == "locations" then batchNotifications = batchNotifications + 1 end
end)
local batchResult = assert(SMK.Store:AddMany({
    { mapID = 300, x = 1, y = 1, name = "批次甲", categoryKey = "other" },
    { mapID = 300, x = 2, y = 2, name = "批次乙", categoryKey = "other" },
    { mapID = 300, x = 1, y = 1, name = "批次甲", categoryKey = "other" },
}))
assert(batchResult.imported == 2 and batchResult.duplicates == 1
    and batchNotifications == 1,
    "batch import did not enforce duplicates with one refresh")
SMK.Store:SetChangeHandler(nil)
SMK.Route:Clear()

context.first = first
context.externalFavorite = externalFavorite
local routeActivated
SMK.Route:SetActivateHandler(function(entry) routeActivated = entry; return true end)
assert(SMK.Route:Add(first) and SMK.Route:Add(externalFavorite)
    and not SMK.Route:Add(first)
    and #SMK.Route:GetItems() == 2,
    "route did not add saved/external locations or reject duplicates")
assert(SMK.Route:Move(2, -1)
    and SMK.Route:GetItems()[1].name == externalFavorite.name
    and SMK.Route:Activate(1)
    and routeActivated.name == externalFavorite.name,
    "route reordering or activation failed")
assert(SMK.Route:CompleteCurrent() and #SMK.Route:GetItems() == 1
    and SMK.Route:GetCurrentIndex() == 1
    and routeActivated.id == first.id,
    "route completion did not activate the next location")
local routeTemporary = assert(SMK.Store:Add({
    mapID = 100, x = 88, y = 88, name = "路线删除测试", categoryKey = "other",
}))
assert(SMK.Route:Add(routeTemporary), "saved route fixture could not be added")
assert(SMK.Store:Delete(routeTemporary) == 1, "saved route fixture could not be deleted")
SMK.Route:RefreshSavedEntries()
for _, item in ipairs(SMK.Route:GetItems()) do
    assert(item.id ~= routeTemporary.id, "deleted saved location remained in the route")
end
SMK.Route:Clear()
