local root = assert(arg[1], "usage: lua Tests/ServiceTest.lua <addon-root>")

local activeLocale = "enUS"
function GetLocale() return activeLocale end
function strlenutf8(text)
    local _, count = tostring(text):gsub("[^\128-\193]", "")
    return count
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

local function loadLocales(locale)
    activeLocale = locale
    local namespace = {}
    loadModule(namespace, "Core/Namespace.lua")
    loadModule(namespace, "Config.lua")
    loadModule(namespace, "Locales/init.lua")
    loadModule(namespace, "Locales/enUS.lua")
    loadModule(namespace, "Locales/zhCN.lua")
    return namespace
end

local english = loadLocales("enUS")
local chinese = loadLocales("zhCN")
for key in pairs(english.L) do assert(chinese.L[key], "zhCN missing locale key: " .. key) end
for key in pairs(chinese.L) do assert(english.L[key], "enUS missing locale key: " .. key) end
assert(english.L.ADD == "Add" and chinese.L.ADD == "新增", "locale selection failed")
assert(english.Config.GetCategoryKey("地下堡") == "Delves", "legacy category alias failed")

activeLocale = "zhCN"
local SMK = {}
for _, path in ipairs({
    "Core/Namespace.lua", "Config.lua", "Locales/init.lua", "Locales/enUS.lua", "Locales/zhCN.lua",
    "Core/PinTextures.lua", "Core/Database.lua", "Core/LocationStore.lua", "Core/MapService.lua",
    "Core/SearchService.lua", "Core/MapIndex.lua", "Core/ShareCodec.lua", "Core/MapPinProvider.lua",
    "Core/RefreshCoordinator.lua", "UI/ShareDialog.lua",
}) do
    loadModule(SMK, path)
end

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
    locations = { { id = "future:1", mapID = 100, x = 1, y = 2, name = "future", categoryKey = "Other" } },
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
SMK.DB:Get().showMapPins = true
assert(futureDatabase.showMapPins == nil, "future database settings were written through runtime data")
assert(not SMK.Store:Add({ mapID = 100, x = 1, y = 2, name = "blocked", categoryKey = "Other" }),
    "future database accepted a write")

SearchMakerDB = {
    locations = {
        { id = "user:4", mapID = "100", x = "12.34", y = "56.78", name = "旧地点", category = "地下堡", showPin = true, pinTexture = "5", futureExtension = "keep" },
        { id = "user:4", mapID = 100, x = 20, y = 30, name = "重复ID", category = "NPC" },
    },
    usageCounts = {},
    locationEdits = { obsolete = true },
    locationDeletions = { obsolete = true },
}
SMK.DB:Initialize()
assert(SearchMakerDB.schemaVersion == SMK.Config.databaseSchemaVersion, "database schema was not migrated")
assert(SearchMakerDB.locations[1].categoryKey == "Delves" and not SearchMakerDB.locations[1].category,
    "category migration failed")
assert(SearchMakerDB.locations[1].pinTextureID == 5 and not SearchMakerDB.locations[1].pinTexture,
    "pin texture migration failed")
assert(SearchMakerDB.locations[2].id ~= "user:4", "duplicate ID was not repaired")
assert(not SearchMakerDB.locationEdits and not SearchMakerDB.locationDeletions, "dead static data was not removed")

local first = SMK.Store:GetAll()[1]
assert(first.categoryKey == "Delves" and first.categoryLabel == "地下堡", "display projection is not localized")
assert(SMK.Store:Update(first, {
    mapID = first.mapID, x = first.x, y = first.y, name = first.name,
    categoryKey = first.categoryKey, showPin = first.showPin, pinTextureID = first.pinTextureID,
}), "location update failed")
assert(SearchMakerDB.locations[1].categoryKey == "Delves", "editing changed the canonical category")
assert(SearchMakerDB.locations[1].futureExtension == "keep", "editing discarded an unknown extension field")

for index = 1, 25 do
    assert(SMK.Store:Add({ mapID = 100, x = index, y = index, name = "精确甲" .. index, categoryKey = "Other" }))
end
assert(SMK.Store:Add({ mapID = 100, x = 90, y = 90, name = "精确", categoryKey = "Other" }))
local matches = SMK.Search:Find(SMK.Store:GetAll(), "精确", true)
assert(#matches == SMK.Config.search.maxResults, "search result limit failed")
assert(matches[1].entry.name == "精确" and matches[1].score == 0, "late exact match was not ranked first")

local encoded = SMK.ShareCodec:Encode({ SMK.Store:GetAll()[1] })
assert(encoded:sub(1, 6) == "SMK|2|", "current share format is not explicitly versioned")
assert(SMK.ShareCodec:FindShareText("chat " .. encoded) == encoded,
    "versioned share text was not found in chat")
local decoded, decodeError, invalid = SMK.ShareCodec:Decode(encoded)
assert(not decodeError and invalid == 0 and #decoded == 1, "current share round trip failed")
assert(decoded[1].categoryKey == "Delves" and decoded[1].pinTextureID == 5, "share fields were not preserved")
local oldCurrent = "SMK|100,1234,5678,1,%E6%97%A7%E7%82%B9,1,5"
local oldEntries, oldError = SMK.ShareCodec:Decode(oldCurrent)
assert(not oldError and #oldEntries == 1 and oldEntries[1].x == 12.34,
    "unversioned SMK share text is no longer compatible")
local futureEntries, futureError = SMK.ShareCodec:Decode("SMK|99|100,1,2,1,x")
assert(not futureEntries and futureError == string.format(SMK.L.IMPORT_NEWER_FORMAT, 99),
    "future share format was not rejected explicitly")

local legacySamples = {
    "SMK3|100,1234,5678,1,%E6%97%A7%E7%82%B9,1,5",
    "SMK2|100,12.34,56.78,Delves,%E6%97%A7%E7%82%B9",
    "MLL2|100,12.34,56.78,%E5%9C%B0%E4%B8%8B%E5%A0%A1,%E6%97%A7%E7%82%B9",
    "MLL1|100,12.34,56.78,ignored,%E6%97%A7%E7%82%B9",
}
for _, sample in ipairs(legacySamples) do
    local entries, errorMessage, bad = SMK.ShareCodec:Decode(sample)
    assert(not errorMessage and bad == 0 and #entries == 1, "legacy decode failed: " .. sample)
end
assert(SMK.ShareCodec:FindShareText("prefix MLL2|100,1,2,Other,x"), "legacy chat scan failed")

local duplicateA = { mapID = 100, x = 1.234, y = 5.678, name = " Test Name " }
local duplicateB = { mapID = 100, x = 1.2341, y = 5.6781, name = "testname" }
assert(SMK.Store:GetDuplicateKey(duplicateA) == SMK.Store:GetDuplicateKey(duplicateB),
    "duplicate normalization failed")

local ranges501 = SMK.ShareDialog:GetExportRanges(501)
local ranges1000 = SMK.ShareDialog:GetExportRanges(1000)
assert(#ranges501 == 2 and ranges501[2].first == 501 and ranges501[2].last == 501,
    "501-entry export pagination failed")
assert(#ranges1000 == 2 and ranges1000[2].first == 501 and ranges1000[2].last == 1000,
    "1000-entry export pagination failed")

mapInfo[946] = { name = "Cosmic", mapType = Enum.UIMapType.Cosmic }
mapChildren[946] = {}
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
function CreateFrame()
    return {
        EnableMouse = function() end,
        SetScript = function(self, event, callback)
            self.scripts = self.scripts or {}
            self.scripts[event] = callback
        end,
        CreateTexture = function() return NewTexture() end,
        SetSize = function() end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        ClearAllPoints = function() end,
    }
end
GameTooltip = {
    SetOwner = function() end, SetText = function() end, AddLine = function() end, Show = function() end,
}
function GameTooltip_Hide() end

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
assert(SMK.MapPins:Initialize(fakeMap), "map pin provider initialization failed")
SearchMakerDB.showMapPins = true
SMK.MapPins:Refresh()
assert(#fakeMap.pins == 1, "enabled map pin was not acquired")
assert(fakeMap.pins[1].icon.atlas == SMK.PinTextureByID[5].atlas, "selected pin texture was ignored")
SearchMakerDB.showMapPins = false
SMK.MapPins:Refresh()
assert(#fakeMap.pins == 0, "disabled map pins were not cleared")

print("SearchMaker service tests passed")
