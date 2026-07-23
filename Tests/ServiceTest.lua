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
C_Map = {
    GetMapInfo = function(mapID) return mapInfo[mapID] end,
    GetMapChildrenInfo = function(mapID) return mapChildren[mapID] or {} end,
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
    "Core/PinTextures.lua", "Core/LocationModel.lua", "Core/Database.lua", "Core/SettingsService.lua",
    "Core/LocationStore.lua", "Core/MapService.lua",
    "Core/SearchService.lua", "Core/MapIndex.lua", "Core/ShareCodec.lua", "Core/ImportService.lua", "Core/MapPinProvider.lua",
    "Core/RefreshCoordinator.lua", "UI/ShareDialog.lua", "UI/ModalManager.lua", "UI/BulkDeleteDialog.lua",
    "UI/Widgets.lua",
}) do
    loadModule(SMK, path)
end

assert(#SMK.PinTextures == 20, "pin texture atlas list is incomplete")
local panelLayout = SMK.Config.GetPanelLayout()
local panelConfig = SMK.Config.panel.layout
local columnsWidth = SMK.Config.location.baseWidth * panelConfig.targetColumns
    + SMK.Config.location.horizontalGap * (panelConfig.targetColumns - 1)
assert(panelConfig.targetColumns == 5 and SMK.Config.panel.width == panelLayout.panelWidth
    and panelLayout.sidePadding + columnsWidth <= panelLayout.contentWidth - panelLayout.sidePadding
    and math.abs(panelLayout.sidePadding
        - (panelLayout.contentWidth - panelLayout.sidePadding - columnsWidth)) <= 1,
    "main panel five-column margins are not symmetric")
assert(SMK.Config.art.searchIcon == "Interface\\ICONS\\VAS_NameChange"
    and SMK.Config.art.searchAllMapsIcon == "Interface\\ICONS\\VAS_CharacterTransfer"
    and SMK.Config.art.searchResultIconFrame == "Interface\\SPELLBOOK\\RotationIconFrame"
    and SMK.Config.art.searchResultIconFrameExpand == 4,
    "search scope icon art is not configured")
local locationSign = SMK.Config.art.locationSign
assert(locationSign.leftAtlas == "housing-dashboard-woodsign-left"
    and locationSign.centerAtlas == "housing-dashboard-woodsign-center"
    and locationSign.rightAtlas == "housing-dashboard-woodsign-right"
    and locationSign.leftWidth + locationSign.centerWidth + locationSign.rightWidth == 136
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
assert(not SMK.Settings:Set("showMapPins", true), "future database setting write was accepted")
assert(futureDatabase.settings == nil, "future database settings were written through runtime data")
assert(not SMK.Store:Add({ mapID = 100, x = 1, y = 2, name = "blocked", categoryKey = "other" }),
    "future database accepted a write")

SearchMakerDB = {
    schemaVersion = SMK.Config.databaseSchemaVersion,
    settings = { showMapPins = true, showFullPanel = false, locationScale = 1.2 },
    locations = {
        { id = "user:4", mapID = "100", x = "12.34", y = "56.78", name = "旧地点", categoryKey = "delves", showPin = true, pinTextureID = "5", futureExtension = "keep" },
        { id = "user:4", mapID = 100, x = 20, y = 30, name = "重复ID", categoryKey = "npc" },
    },
    usageCounts = {},
}
SMK.DB:Initialize()
assert(SearchMakerDB.schemaVersion == SMK.Config.databaseSchemaVersion, "database schema was not initialized")
assert(SearchMakerDB.locations[1].categoryKey == "delves", "category normalization failed")
assert(SearchMakerDB.locations[1].pinTextureID == 5, "pin texture normalization failed")
assert(SearchMakerDB.locations[2].id ~= "user:4", "duplicate ID was not repaired")
assert(SMK.Settings:Get("showMapPins") and SMK.Settings:Get("locationScale") == 1.2,
    "nested settings were not initialized")
assert(SearchMakerDB.settings.showFullPanel == nil, "removed panel setting was retained")
assert(SMK.Settings:Get("showMapPinNames") == false, "pin name setting default was not initialized")
local defaultTextColor = SMK.Settings:Get("mapPinTextColor")
assert(defaultTextColor.r == 1 and defaultTextColor.g == 0.82 and defaultTextColor.b == 0
    and SMK.Settings:Get("mapPinTextScale") == 1,
    "pin text appearance defaults were not initialized")
assert(SearchMakerDB.locationScale == nil and SearchMakerDB.showMapPins == nil,
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

local encoded = SMK.ShareCodec:Encode({ SMK.Store:GetAll()[1] })
assert(encoded:sub(1, 6) == "SMK|2|", "current share format is not explicitly versioned")
assert(SMK.ShareCodec:FindShareText("chat " .. encoded) == encoded,
    "versioned share text was not found in chat")
local decoded, decodeError, invalid = SMK.ShareCodec:Decode(encoded)
assert(not decodeError and invalid == 0 and #decoded == 1, "current share round trip failed")
assert(decoded[1].categoryKey == "delves" and decoded[1].pinTextureID == 5, "share fields were not preserved")
local oldEntries, oldError = SMK.ShareCodec:Decode("SMK|100,1234,5678,1,x,1,5")
assert(not oldEntries and oldError == SMK.L.IMPORT_INVALID_FORMAT,
    "unversioned SMK share text was accepted")
local futureEntries, futureError = SMK.ShareCodec:Decode("SMK|99|100,1,2,1,x")
assert(not futureEntries and futureError == string.format(SMK.L.IMPORT_NEWER_FORMAT, 99),
    "future share format was not rejected explicitly")
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

local duplicateA = { mapID = 100, x = 1.234, y = 5.678, name = " Test Name " }
local duplicateB = { mapID = 100, x = 1.2341, y = 5.6781, name = "testname" }
assert(SMK.LocationModel:GetDuplicateKey(duplicateA) == SMK.LocationModel:GetDuplicateKey(duplicateB),
    "duplicate normalization failed")

local ranges501 = SMK.ShareDialog:GetExportRanges(501)
local ranges1000 = SMK.ShareDialog:GetExportRanges(1000)
assert(#ranges501 == 2 and ranges501[2].first == 501 and ranges501[2].last == 501,
    "501-entry export pagination failed")
assert(#ranges1000 == 2 and ranges1000[2].first == 501 and ranges1000[2].last == 1000,
    "1000-entry export pagination failed")

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
    UseFrameLevelType = function() end,
    SetScalingLimits = function() end,
    SetPosition = function(self, x, y) self.x, self.y = x, y end,
}
function CreateUnsecuredRegionPoolInstance() return {} end
local function NewTexture()
    return {
        SetAllPoints = function() end,
        SetAtlas = function(self, atlas) self.atlas = atlas end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
end
local function NewFontString()
    return {
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
function fakeMap:AddDataProvider(provider) provider.map = self end
function fakeMap:AcquirePin(template, entry)
    local pin = self.pinPools[template].createFunc()
    pin:OnAcquired(entry)
    self.pins[#self.pins + 1] = pin
end
function fakeMap:RemoveAllPinsByTemplate(template)
    for _, pin in ipairs(self.pins) do self.pinPools[template].resetFunc(nil, pin) end
    self.pins = {}
end
local editedPinEntry
assert(SMK.MapPins:Initialize(fakeMap, {
    onEdit = function(entry) editedPinEntry = entry end,
}), "map pin provider initialization failed")
SearchMakerDB.settings.showMapPins = true
SMK.MapPins:Refresh()
assert(#fakeMap.pins == 1, "enabled map pin was not acquired")
assert(fakeMap.pins[1].icon.atlas == SMK.PinTextureByID[5].atlas, "selected pin texture was ignored")
assert(fakeMap.pins[1].label.text == "旧地点" and fakeMap.pins[1].label.shown,
    "enabled map pin name was not rendered")
assert(fakeMap.pins[1].label.color.r == 0.2 and fakeMap.pins[1].label.color.g == 0.4
    and fakeMap.pins[1].label.color.b == 0.6 and fakeMap.pins[1].label.scale == 1.4,
    "pin text appearance settings were not rendered")
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
SearchMakerDB.settings.showMapPins = false
SMK.MapPins:Refresh()
assert(#fakeMap.pins == 0, "disabled map pins were not cleared")

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
        left = { SetWidth = function(self, width) self.width = width end },
        right = { SetWidth = function(self, width) self.width = width end },
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
local leftWidth, rightWidth = layoutButton.background.left.width, layoutButton.background.right.width
layoutButton.showIcon = true
SMK.Widgets:UpdateLocationGeometry(layoutButton)
assert(layoutButton.width == 217 and layoutButton.iconBox.width == 38
    and layoutButton.iconBox.shown,
    "search result location icon geometry is incorrect")
layoutButton.label.text, layoutButton.label.width = "long", 220
SMK.Widgets:UpdateLocationGeometry(layoutButton)
assert(layoutButton.width == 274 and layoutButton.background.left.width == leftWidth
    and layoutButton.background.right.width == rightWidth,
    "search result location sign did not stretch only its center segment")
SMK.Widgets:StretchSearchResult(layoutButton, 340)
assert(layoutButton.width == 340 and not layoutButton.clipsChildren
    and layoutButton.background.left.width == leftWidth
    and layoutButton.background.right.width == rightWidth,
    "search result center segment did not fill the result width")

print("SearchMaker service tests passed")
