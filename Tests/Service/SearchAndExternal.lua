local context = assert(...)
local SMK = context.SMK
local mapInfo = context.mapInfo

assert(SMK.Store:Add({ mapID = 100, x = 90, y = 90, name = "精确", categoryKey = "other" }))
local matches = SMK.Search:Find(SMK.Store:GetAll(), "精确", true)
assert(#matches == SMK.Config.search.maxResults, "search result limit failed")
assert(matches[1].entry.name == "精确" and matches[1].score == 0, "late exact match was not ranked first")
local originalGetMapName = SMK.Map.GetMapName
local mapNameLookups = 0
SMK.Map.GetMapName = function(self, mapID)
    mapNameLookups = mapNameLookups + 1
    return originalGetMapName(self, mapID)
end
local lazyMapEntries = {}
for index = 1, 100 do
    local name = string.format("lazy%03d", index)
    lazyMapEntries[index] = {
        mapID = 2000 + index,
        x = index % 100,
        y = index % 100,
        name = name,
        normalizedName = name,
        normalizedSearchable = name,
    }
end
local lazyMapMatches = SMK.Search:Find(lazyMapEntries, "lazy", true)
mapNameLookups = 0
local reverseLazyEntries = {}
for index = #lazyMapEntries, 1, -1 do
    reverseLazyEntries[#reverseLazyEntries + 1] = lazyMapEntries[index]
end
local reverseLazyMatches = SMK.Search:Find(reverseLazyEntries, "lazy", true)
SMK.Map.GetMapName = originalGetMapName
assert(#lazyMapMatches == SMK.Config.search.maxResults
    and #reverseLazyMatches == SMK.Config.search.maxResults
    and reverseLazyMatches[1].entry.name == "lazy001"
    and mapNameLookups == SMK.Config.search.maxResults,
    "all-map search resolved map names for rejected candidates")

local searchTimers = {}
C_Timer = {
    NewTimer = function(_, callback)
        local timer = { callback = callback, cancelled = false }
        function timer:Cancel() self.cancelled = true end
        searchTimers[#searchTimers + 1] = timer
        return timer
    end,
}
local originalUpdateResults = SMK.SearchBar.UpdateResults
local debouncedUpdates = 0
SMK.SearchBar.UpdateResults = function() debouncedUpdates = debouncedUpdates + 1 end
SMK.SearchBar.searchToken, SMK.SearchBar.searchTimer = nil, nil
SMK.SearchBar:ScheduleResults()
SMK.SearchBar:ScheduleResults()
assert(#searchTimers == 2 and searchTimers[1].cancelled and not searchTimers[2].cancelled,
    "search debounce did not cancel the superseded timer")
for _, timer in ipairs(searchTimers) do
    if not timer.cancelled then timer.callback() end
end
assert(debouncedUpdates == 1 and SMK.SearchBar.searchTimer == nil,
    "search debounce ran a stale update")
SMK.SearchBar.UpdateResults = originalUpdateResults
SMK.SearchBar.searchToken, SMK.SearchBar.searchTimer = nil, nil
C_Timer = nil

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
assert(SMK.Route:Add(coordinateResult.entry)
    and SMK.Route:GetItems()[1].mapID == 100
    and SMK.Route:GetItems()[1].x == 12.3
    and not SMK.Route:Add(coordinateResult.entry),
    "recognized coordinates could not be added to the route or were not deduplicated")
SMK.Route:Clear()
assert(not SMK.Store:RecordUsage(coordinateResult.entry),
    "temporary coordinate result was written to usage storage")
assert(SMK.Map:SetWaypoint(coordinateResult.entry)
    and context.waypoint.uiMapID == 100
    and math.abs(context.waypoint.position.x - 0.123) < 0.000001
    and math.abs(context.waypoint.position.y - 0.4567) < 0.000001,
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

context.playerMapID = 100
WorldMapFrame = {
    IsShown = function() return false end,
    GetMapID = function() return nil end,
}
assert(SMK.Map:GetPlayerMapID() == 100 and SMK.Map:GetContextMapID() == 100,
    "hidden world map did not use the player's current map")
assert(SMK.LocationEditor:CanReadPlayerCoordinates(100)
    and not SMK.LocationEditor:CanReadPlayerCoordinates(200)
    and not SMK.LocationEditor:CanReadPlayerCoordinates(nil),
    "location editor coordinate button did not follow the player map ID")
mapInfo[85] = { mapID = 85, name = "奥格瑞玛" }
local externalNodes = {
    [12345678] = {
        name = "English Internal Name",
        npcID = 9876,
        info = string.rep("冗", 200),
        internalDeveloperNote = "不应搜索的内部关键字",
    },
    [22334455] = { name = "", type = "Portal", mnID = 85 },
    [32345678] = { name = "English Missing NPC", npcID = 9999 },
    [42345678] = { name = "", npcID = 7777 },
}
local externalIcons = {
    [12345678] = "Interface\\AddOns\\HandyNotes_MapNotes\\Images\\FirstAid",
}
HandyNotes_MapNotesRetailNpcCacheDB = {
    names = {
        zhCN = {
            [9876] = "卡娜莉亚\031<绷带训练师>",
            [7777] = "测试商人\031",
        },
    },
}
local handyNotesBuilds = 0
local fakeNow = 100
local npcTooltipLookups = 0
function GetTime() return fakeNow end
C_TooltipInfo = {
    GetHyperlink = function()
        npcTooltipLookups = npcTooltipLookups + 1
        return nil
    end,
}
function hooksecurefunc(target, method, callback)
    local original = target[method]
    target[method] = function(...)
        original(...)
        callback(...)
    end
end
HandyNotes = {
    SendMessage = function() end,
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
local handyNotesUpdates = 0
local unhookedSendMessage = HandyNotes.SendMessage
SMK.HandyNotesProvider:SetChangeHandler(function()
    handyNotesUpdates = handyNotesUpdates + 1
end)
assert(not SMK.HandyNotesProvider:IsEnabled()
    and HandyNotes.SendMessage == unhookedSendMessage,
    "disabled third-party search installed a HandyNotes update hook")
SMK.HandyNotesProvider:SetEnabled(true)
assert(SMK.HandyNotesProvider:IsEnabled()
    and HandyNotes.SendMessage ~= unhookedSendMessage,
    "enabling third-party search did not initialize the HandyNotes provider")
SMK.HandyNotesProvider:RebuildCache(100, true)
local handyNotesEntries = SMK.HandyNotesProvider:GetByMap(100)
assert(SMK.HandyNotesProvider:RebuildCache(100) == handyNotesEntries
    and handyNotesBuilds == 1,
    "HandyNotes rebuilt an unchanged current-map cache")
assert(npcTooltipLookups == 2,
    "missing or partial HandyNotes NPC data was not queried once")
SMK.HandyNotesProvider:RebuildCache(100, true)
assert(handyNotesBuilds == 2 and npcTooltipLookups == 2,
    "HandyNotes NPC cache did not suppress an immediate retry")
fakeNow = fakeNow + SMK.Config.handyNotes.npcRetrySeconds + 1
SMK.HandyNotesProvider:RebuildCache(100, true)
assert(handyNotesBuilds == 3 and npcTooltipLookups == 4,
    "expired missing or partial NPC data was not retried")
HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "Other")
assert(handyNotesUpdates == 0,
    "an unrelated HandyNotes update invalidated the MapNotes cache")
HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "MapNotes")
assert(handyNotesUpdates == 1
    and #SMK.HandyNotesProvider:GetByMap(100) == 0,
    "MapNotes update did not invalidate and announce its cache")
SMK.HandyNotesProvider:RebuildCache(100)
assert(handyNotesBuilds == 4 and npcTooltipLookups == 6,
    "MapNotes update did not retry incomplete NPC data")
handyNotesEntries = SMK.HandyNotesProvider:GetByMap(100)
local trainerEntry, portalEntry
for _, entry in ipairs(handyNotesEntries) do
    if entry.x == 12.34 then trainerEntry = entry end
    if entry.x == 22.33 then portalEntry = entry end
end
assert(#handyNotesEntries == 3 and trainerEntry
    and trainerEntry.mapID == 100 and trainerEntry.y == 56.78
    and trainerEntry.name == "绷带训练师"
    and trainerEntry.externalSource == "HandyNotes_MapNotes"
    and trainerEntry.normalizedSearchable:find("绷带", 1, true)
    and trainerEntry.iconTexture == externalIcons[12345678],
    "HandyNotes did not cache the player's map while WorldMapFrame was unopened")
assert(#trainerEntry.normalizedSearchable <= SMK.Config.handyNotes.maxSearchTextBytes
    and #SMK.Search:Find({}, "内部关键字", false, 100, handyNotesEntries) == 0,
    "HandyNotes search text exceeded its budget or included an internal field")
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
assert(#SMK.Search:Find({}, "绷带", true, 100, handyNotesEntries) == 0,
    "all-map search included a current-map-only HandyNotes cache")
SMK.HandyNotesProvider:RebuildCache(85)
assert(#SMK.Search:Find({}, "绷带", false, 100,
    SMK.HandyNotesProvider:GetByMap(85)) == 0,
    "current-map search included a stale HandyNotes map cache")
SMK.HandyNotesProvider:RebuildCache(100)
handyNotesEntries = SMK.HandyNotesProvider:GetByMap(100)
assert(#SMK.Search:Find({}, "绷带", false, 100, handyNotesEntries) == 1,
    "HandyNotes cache did not return to the player's current map")
local asyncCallbacks = {}
C_Timer = {
    After = function(delay, callback)
        asyncCallbacks[#asyncCallbacks + 1] = {
            delay = delay,
            callback = callback,
        }
    end,
}
local profileTime = 0
debugprofilestop = function()
    profileTime = profileTime + 3
    return profileTime
end
SMK.HandyNotesProvider:Invalidate()
local updatesBeforeAsyncBuild = handyNotesUpdates
assert(#SMK.HandyNotesProvider:RebuildCache(100) == 0 and #asyncCallbacks == 1,
    "HandyNotes cache build was not deferred")
local deferredBatches = 0
while true do
    local callbackIndex
    for index, scheduled in ipairs(asyncCallbacks) do
        if scheduled.delay == 0 then
            callbackIndex = index
            break
        end
    end
    if not callbackIndex then break end
    local scheduled = table.remove(asyncCallbacks, callbackIndex)
    deferredBatches = deferredBatches + 1
    scheduled.callback()
end
assert(#SMK.HandyNotesProvider:GetByMap(100) == 3
    and handyNotesUpdates == updatesBeforeAsyncBuild + 1
    and deferredBatches > 1,
    "time-budgeted HandyNotes cache was not published after multiple batches")
C_Timer = nil
debugprofilestop = nil
handyNotesEntries = SMK.HandyNotesProvider:GetByMap(100)
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
assert(fakeIcon.atlas == SMK.Config.art.mapPortalAtlas,
    "map portal search result did not use its contained icon atlas")
fakeIcon.texture = nil
fakeIcon.atlas = nil
SMK.Widgets:SetLocationIcon(fakeIcon, { categoryKey = "other", customIconID = -3 })
assert(fakeIcon.texture == "Interface\\ICONS\\UI_Profession_Cooking",
    "saved location did not use its custom path icon")
fakeIcon.texture = nil
fakeIcon.atlas = nil
SMK.Widgets:SetLocationIcon(fakeIcon, { categoryKey = "other", customIconID = 18 })
assert(fakeIcon.atlas == "Professions-Crafting-Orders-Icon",
    "saved location did not use its custom Atlas icon")
assert(SMK.SearchHistory:RecordResult(trainerEntry),
    "external result was not recorded in recent search results")
SMK.Settings:Set("thirdPartySearchEnabled", false)
for _, recentEntry in ipairs(SMK.SearchHistory:GetRecentResults()) do
    assert(not recentEntry.isExternal,
        "disabled third-party search exposed a cached recent external result")
end
SMK.Settings:Set("thirdPartySearchEnabled", true)
assert(SMK.SearchHistory:GetRecentResults()[1].isExternal,
    "reenabled third-party search did not restore its recent external result")
local buildsBeforeDisable = handyNotesBuilds
local updatesBeforeDisable = handyNotesUpdates
SMK.HandyNotesProvider:SetEnabled(false)
SMK.HandyNotesProvider:RebuildCache(100, true)
HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "MapNotes")
assert(not SMK.HandyNotesProvider:IsEnabled()
    and #SMK.HandyNotesProvider:GetByMap(100) == 0
    and handyNotesBuilds == buildsBeforeDisable
    and handyNotesUpdates == updatesBeforeDisable,
    "disabled third-party search retained, rebuilt, or invalidated HandyNotes data")
SMK.MapContext:Refresh(100)
assert(#SMK.MapContext:GetExternalEntries() == 0,
    "disabled third-party search remained in the map context")
SMK.HandyNotesProvider:SetEnabled(true)
HandyNotes = nil

context.coordinateResult = coordinateResult
